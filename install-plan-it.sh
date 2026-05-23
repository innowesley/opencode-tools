#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

CONFIG_DIR="$HOME/.config/opencode"

msg()  { printf "${GREEN}%s${NC}\n" "$1"; }
info() { printf "${CYAN}%s${NC}\n" "$1"; }
warn() { printf "${YELLOW}%s${NC}\n" "$1"; }
err()  { printf "${RED}%s${NC}\n" "$1"; }

install_global() {
  msg "Installing plan-it globally..."

  mkdir -p "$CONFIG_DIR/tools" "$CONFIG_DIR/skills/plan-flow" "$CONFIG_DIR/commands"

  cat > "$CONFIG_DIR/opencode.json" << 'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    "plan": {
      "prompt": "You are in Plan mode. If the request is unclear about the TASK, use the `question` tool to ask clarifying questions about what to build (never about file paths or plan storage — those are fixed). Load the `plan-flow` skill for plan format instructions. Use the `write-plan` tool to save plans. After writing the plan, use the `question` tool to ask: implement now (tell them to press Tab for Build), edit the plan, or cancel."
    }
  }
}
EOF

  cat > "$CONFIG_DIR/AGENTS.md" << 'EOF'
# CRITICAL RULE: Always use the `question` tool
Whenever you need to ask the user a question or present options, you MUST call the `question` tool. Do NOT ask questions or list options in your own response text.

---

# CRITICAL STARTUP RULE
On EVERY new session, BEFORE responding to the user's first message:
1. Check `.agents/plans/pending/` — if files exist, use the `question` tool to tell user "You have X pending plans." and ask what to do
2. Run the `stale-plans` tool to check for abandoned/outdated plans
3. If stale plans exist: use `question` tool to ask: continue a plan, archive a stale one, or review with `/pending`
4. If all look current: say "All look current. Type /pending to review."
5. Only THEN proceed with the user's request. When showing a plan to the user, do NOT use `read` on the `.md` file (shows ugly line numbers). Instead, output the plan as formatted markdown in your chat response — OpenCode renders it with colors natively (bold, headings, code blocks).

---

## Plan-First Workflow

CRITICAL: Always plan before implementing.

### Plan mode
- Use the `write-plan` tool to save plans to `.agents/plans/pending/`
- Load the `plan-flow` skill for plan format guidance

### Build mode
- After completing implementation, archive the plan:
  1. Use `edit` to prepend `**✅ Completed:** *date/time*` to the plan file
  2. Use `bash mv` to move it from `.agents/plans/pending/` to `.agents/plans/completed/`
EOF

  cat > "$CONFIG_DIR/tools/write-plan.ts" << 'EOF'
import { mkdir, unlink } from "node:fs/promises"
import { tool } from "@opencode-ai/plugin"

export default tool({
  description: "Save or archive a plan file in .agents/plans/",
  args: {
    name: tool.schema.string().describe("Plan name used as filename (no .md)"),
    content: tool.schema.string().describe("Full plan content in markdown"),
    status: tool.schema.enum(["pending", "completed"]).default("pending").describe("pending = active plan, completed = archived"),
  },
  async execute(args, context) {
    const base = (context.worktree && context.worktree !== '/') ? context.worktree : context.directory
    const pending = `${base}/.agents/plans/pending/${args.name}.md`
    const completed = `${base}/.agents/plans/completed/${args.name}.md`

    if (args.status === "completed") {
      await mkdir(`${base}/.agents/plans/completed`, { recursive: true })
      const stamped = `${args.content}\n\n---\n**✅ Completed:** ${new Date().toLocaleString()}\n`
      await Bun.write(completed, stamped)
      await unlink(pending).catch(() => {})
      return `Plan archived to .agents/plans/completed/${args.name}.md`
    }

    await mkdir(`${base}/.agents/plans/pending`, { recursive: true })
    await Bun.write(pending, args.content)
    return `Plan saved to .agents/plans/pending/${args.name}.md`
  },
})
EOF

  cat > "$CONFIG_DIR/tools/list-plans.ts" << 'EOF'
import { readdir } from "node:fs/promises"
import { tool } from "@opencode-ai/plugin"

export default tool({
  description: "List plan files in .agents/plans/",
  args: {
    status: tool.schema.enum(["pending", "completed"]).default("pending").describe("pending = active plans, completed = archived plans"),
  },
  async execute(args, context) {
    const base = (context.worktree && context.worktree !== '/') ? context.worktree : context.directory
    const dir = `${base}/.agents/plans/${args.status}`

    let files: string[]
    try {
      files = await readdir(dir)
    } catch {
      return JSON.stringify({ count: 0, plans: [] })
    }

    const plans = files
      .filter(f => f.endsWith(".md"))
      .map(f => f.replace(/\.md$/, ""))

    return JSON.stringify({ count: plans.length, plans })
  },
})
EOF

  cat > "$CONFIG_DIR/commands/pending.md" << 'EOF'
---
description: List all pending plans in .agents/plans/pending/
---

List all `.md` files in `.agents/plans/pending/`. For each file, show the filename and the first heading (the `# Title` line). Present them numbered.

If there are no pending plans, say "No pending plans." and stop.

If there are any, ask:
- "Type the **number** to continue working on a plan"
- "Or type `archive <number>` to move that plan to `.agents/plans/completed/` as outdated/superseded"

If the user picks a number, proceed with that plan. Do NOT read the plan file content — the user already sees it in OpenCode's own plan viewer.

If the user says `archive <number>`:
1. Read the full content of that plan's `.md` file
2. Use `edit` to prepend `**Archived as outdated/superseded**` to the content
3. Use `bash mv` to move it: `mv .agents/plans/pending/name.md .agents/plans/completed/name.md`
4. Confirm the plan was archived
EOF

  cat > "$CONFIG_DIR/tools/stale-plans.ts" << 'EOF'
import { readdir, readFile, stat } from "node:fs/promises"
import { tool } from "@opencode-ai/plugin"

const DAY_MS = 86400000

export default tool({
  description: "Check pending plans for staleness — age, context drift, completion clues, missing references",
  args: {
    maxAgeDays: tool.schema.number().default(7).describe("Max age in days before a plan is flagged as stale"),
  },
  async execute(args, context) {
    const base = (context.worktree && context.worktree !== '/') ? context.worktree : context.directory
    const pendingDir = `${base}/.agents/plans/pending`
    const stale: any[] = []
    const healthy: string[] = []

    let files: string[]
    try {
      files = await readdir(pendingDir)
    } catch {
      return JSON.stringify({ count: 0, stale: [], healthy: [] })
    }

    const planFiles = files.filter(f => f.endsWith(".md"))
    if (planFiles.length === 0) {
      return JSON.stringify({ count: 0, stale: [], healthy: [] })
    }

    const now = Date.now()

    for (const file of planFiles) {
      const fullPath = `${pendingDir}/${file}`
      const reasons: string[] = []

      let mtimeMs: number
      let content: string
      try {
        const s = await stat(fullPath)
        mtimeMs = s.mtimeMs

        content = await readFile(fullPath, "utf-8")
      } catch {
        continue
      }

      const ageDays = (now - mtimeMs) / DAY_MS

      if (ageDays > args.maxAgeDays) {
        reasons.push(`Plan is ${Math.round(ageDays)} days old (max: ${args.maxAgeDays})`)
      }

      if (content.match(/\b(done|completed|finished|all steps? are?\s+(done|complete))\b/i)) {
        reasons.push("Plan text suggests it may already be complete")
      }

      const contextFiles = ["AGENTS.md", "docs"]
      for (const ctxFile of contextFiles) {
        try {
          const ctxStat = await stat(`${base}/${ctxFile}`)
          if (ctxStat.mtimeMs > mtimeMs) {
            reasons.push(`${ctxFile} was modified after this plan was created (context may have shifted)`)
          }
        } catch {
          // context file doesn't exist, skip
        }
      }

      const pathRefs = content.match(/(?:`)?[\w./-]+\.\w{1,4}(?:`)?/g) || []
      for (const ref of pathRefs) {
        const clean = ref.replace(/`/g, "")
        if (clean.startsWith(".") || clean.startsWith("/") || clean.includes("/")) {
          try {
            await stat(`${base}/${clean}`)
          } catch {
            reasons.push(`Referenced file ${clean} no longer exists`)
            break
          }
        }
      }

      const name = file.replace(/\.md$/, "")
      if (reasons.length > 0) {
        stale.push({ name, ageDays: Math.round(ageDays), reasons })
      } else {
        healthy.push(name)
      }
    }

    return JSON.stringify({ count: planFiles.length, stale, healthy })
  },
})
EOF

  cat > "$CONFIG_DIR/skills/plan-flow/SKILL.md" << 'EOF'
---
name: plan-flow
description: Plan-first workflow — create plans using write-plan tool, archive via edit+mv on completion
---

## Critical rule
Whenever you need to ask the user a question or present options, you MUST call the `question` tool. Do NOT ask questions or list options in your own response text.

## Plan-First Workflow

Always create a written plan before making code changes.

### How to use
1. **Clarify task** — If the request is vague about WHAT to build, use the `question` tool to ask task-specific questions. NEVER ask about file paths, storage locations, or plan format — those are always fixed
2. **Analyze** — Explore the codebase to understand the current state
3. **Write plan** — Say "Writing plan..." then call `write-plan` to save. After saving, output the plan directly in your response using clean markdown — headings, bold, lists, code blocks. OpenCode's chat renders this with colors natively. Do NOT use `read` on the `.md` file (shows ugly line numbers).
4. **Ask next** — Use the `question` tool to ask the user: implement now (tell them to press Tab for Build), edit the plan, or cancel
5. **Editing a plan** — Use the `edit` tool directly on the `.md` file in `.agents/plans/pending/`. Do NOT rewrite the whole plan with `write-plan`.
6. **Archiving** — When implementation is done:
   1. Use `edit` to prepend `**✅ Completed:** *date/time*` at the top of the plan file
   2. Use `bash mv` to move it: `mv .agents/plans/pending/name.md .agents/plans/completed/name.md`

### Plan format
Each plan must include:
- **Goal**: What we're trying to achieve
- **Approach**: High-level strategy
- **Files to modify**: Full paths and what changes each needs
- **Risks**: Potential issues or edge cases
- **Implementation steps**: Ordered list of concrete steps

### Tool guidance — write-plan vs native tools
| Tool | Use for | Why |
|------|---------|-----|
| `write-plan` | **New plans** only | Auto-creates `.agents/plans/pending/` directory |
| `edit` | **Editing** existing plan `.md` files | Direct file edit, no full rewrite |
| `edit` + `bash mv` | **Archiving** completed plans | Prepends timestamp, moves to `completed/` |
| Native `write` | ❌ Avoid for plan files | Fails if `pending/` dir doesn't exist |
EOF

  msg "Global install complete → $CONFIG_DIR"
}

install_project() {
  local dir="$1"
  mkdir -p "$dir"

  msg "Installing plan-it into project: $dir"

  mkdir -p "$dir/.opencode/tools" "$dir/.opencode/skills/plan-flow" "$dir/.opencode/commands" "$dir/.agents/plans/pending" "$dir/.agents/plans/completed"

  cat > "$dir/opencode.json" << 'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    "plan": {
      "prompt": "You are in Plan mode. If the request is unclear about the TASK, use the `question` tool to ask clarifying questions about what to build (never about file paths or plan storage — those are fixed). Load the `plan-flow` skill for plan format instructions. Use the `write-plan` tool to save plans. After writing the plan, use the `question` tool to ask: implement now (tell them to press Tab for Build), edit the plan, or cancel."
    }
  }
}
EOF

  cat > "$dir/AGENTS.md" << 'EOF'
# CRITICAL RULE: Always use the `question` tool
Whenever you need to ask the user a question or present options, you MUST call the `question` tool. Do NOT ask questions or list options in your own response text.

---

# CRITICAL STARTUP RULE
On EVERY new session, BEFORE responding to the user's first message:
1. Check `.agents/plans/pending/` — if files exist, use the `question` tool to tell user "You have X pending plans." and ask what to do
2. Run the `stale-plans` tool to check for abandoned/outdated plans
3. If stale plans exist: use `question` tool to ask: continue a plan, archive a stale one, or review with `/pending`
4. If all look current: say "All look current. Type /pending to review."
5. Only THEN proceed with the user's request. When showing a plan to the user, do NOT use `read` on the `.md` file (shows ugly line numbers). Instead, output the plan as formatted markdown in your chat response — OpenCode renders it with colors natively (bold, headings, code blocks).

---

## Plan-First Workflow

CRITICAL: Always plan before implementing.

### Plan mode
- Use the `write-plan` tool to save plans to `.agents/plans/pending/`
- Load the `plan-flow` skill for plan format guidance

### Build mode
- After completing implementation, archive the plan:
  1. Use `edit` to prepend `**✅ Completed:** *date/time*` to the plan file
  2. Use `bash mv` to move it from `.agents/plans/pending/` to `.agents/plans/completed/`
EOF

  cp "$CONFIG_DIR/tools/write-plan.ts" "$dir/.opencode/tools/write-plan.ts"
  cp "$CONFIG_DIR/tools/list-plans.ts" "$dir/.opencode/tools/list-plans.ts"
  cp "$CONFIG_DIR/tools/stale-plans.ts" "$dir/.opencode/tools/stale-plans.ts"
  cp "$CONFIG_DIR/commands/pending.md" "$dir/.opencode/commands/pending.md"
  cp "$CONFIG_DIR/skills/plan-flow/SKILL.md" "$dir/.opencode/skills/plan-flow/SKILL.md"

  msg "Project install complete → $dir"
}

uninstall_all() {
  warn "Uninstalling plan-it..."

  for f in "$CONFIG_DIR/opencode.json" "$CONFIG_DIR/AGENTS.md" "$CONFIG_DIR/tools/write-plan.ts" "$CONFIG_DIR/tools/list-plans.ts" "$CONFIG_DIR/tools/stale-plans.ts" "$CONFIG_DIR/commands/pending.md" "$CONFIG_DIR/skills/plan-flow/SKILL.md"; do
    if [ -f "$f" ]; then
      rm "$f"
      info "  Removed: $f"
    fi
  done

  rmdir "$CONFIG_DIR/tools" 2>/dev/null || true
  rmdir "$CONFIG_DIR/commands" 2>/dev/null || true
  rmdir "$CONFIG_DIR/skills/plan-flow" 2>/dev/null || true
  rmdir "$CONFIG_DIR/skills" 2>/dev/null || true

  msg "Global uninstall complete"
}

show_status() {
  echo ""
  info "=== plan-it status ==="
  echo ""

  local all_ok=true
  local has_list_plans=false
  local has_pending_cmd=false

  for f in "opencode.json" "AGENTS.md" "tools/write-plan.ts" "skills/plan-flow/SKILL.md"; do
    if [ -f "$CONFIG_DIR/$f" ]; then
      msg "  ✅ $f"
    else
      err "  ❌ $f"
      all_ok=false
    fi
  done

  local has_stale_plans=false

  if [ -f "$CONFIG_DIR/tools/list-plans.ts" ]; then
    msg "  ✅ tools/list-plans.ts"
    has_list_plans=true
  else
    warn "  ⬜ tools/list-plans.ts (optional — not installed)"
  fi

  if [ -f "$CONFIG_DIR/tools/stale-plans.ts" ]; then
    msg "  ✅ tools/stale-plans.ts"
    has_stale_plans=true
  else
    warn "  ⬜ tools/stale-plans.ts (optional — not installed)"
  fi

  if [ -f "$CONFIG_DIR/commands/pending.md" ]; then
    msg "  ✅ commands/pending.md"
    has_pending_cmd=true
  else
    warn "  ⬜ commands/pending.md (optional — not installed)"
  fi

  echo ""
  if $all_ok; then
    if $has_list_plans || $has_pending_cmd || $has_stale_plans; then
      msg "plan-it is fully installed (with extras)"
    else
      msg "plan-it is installed (minimal)"
    fi
  else
    err "plan-it is incomplete — run 'install' to fix"
  fi
  echo ""
}

install_minimal() {
  install_global_minimal
  if [ -n "${2:-}" ]; then
    install_project_minimal "$2"
  fi
}

install_global_minimal() {
  msg "Installing plan-it (minimal) globally..."

  mkdir -p "$CONFIG_DIR/tools" "$CONFIG_DIR/skills/plan-flow"

  cat > "$CONFIG_DIR/opencode.json" << 'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    "plan": {
      "prompt": "You are in Plan mode. If the request is unclear about the TASK, use the `question` tool to ask clarifying questions about what to build (never about file paths or plan storage — those are fixed). Load the `plan-flow` skill for plan format instructions. Use the `write-plan` tool to save plans. After writing the plan, use the `question` tool to ask: implement now (tell them to press Tab for Build), edit the plan, or cancel."
    }
  }
}
EOF

  cat > "$CONFIG_DIR/AGENTS.md" << 'EOF'
# CRITICAL RULE: Always use the `question` tool
Whenever you need to ask the user a question or present options, you MUST call the `question` tool. Do NOT ask questions or list options in your own response text.

---

# CRITICAL STARTUP RULE
On EVERY new session, BEFORE responding to the user's first message:
1. Check `.agents/plans/pending/` — if files exist, use the `question` tool to tell user "You have X pending plans." and ask what to do
2. Run the `stale-plans` tool to check for abandoned/outdated plans
3. If stale plans exist: use `question` tool to ask: continue a plan, archive a stale one, or review with `/pending`
4. If all look current: say "All look current. Type /pending to review."
5. Only THEN proceed with the user's request. When showing a plan to the user, do NOT use `read` on the `.md` file (shows ugly line numbers). Instead, output the plan as formatted markdown in your chat response — OpenCode renders it with colors natively (bold, headings, code blocks).

---

## Plan-First Workflow

CRITICAL: Always plan before implementing.

### Plan mode
- Use the `write-plan` tool to save plans to `.agents/plans/pending/`
- Load the `plan-flow` skill for plan format guidance

### Build mode
- After completing implementation, archive the plan:
  1. Use `edit` to prepend `**✅ Completed:** *date/time*` to the plan file
  2. Use `bash mv` to move it from `.agents/plans/pending/` to `.agents/plans/completed/`
EOF

  cat > "$CONFIG_DIR/tools/write-plan.ts" << 'EOF'
import { mkdir, unlink } from "node:fs/promises"
import { tool } from "@opencode-ai/plugin"

export default tool({
  description: "Save or archive a plan file in .agents/plans/",
  args: {
    name: tool.schema.string().describe("Plan name used as filename (no .md)"),
    content: tool.schema.string().describe("Full plan content in markdown"),
    status: tool.schema.enum(["pending", "completed"]).default("pending").describe("pending = active plan, completed = archived"),
  },
  async execute(args, context) {
    const base = (context.worktree && context.worktree !== '/') ? context.worktree : context.directory
    const pending = `${base}/.agents/plans/pending/${args.name}.md`
    const completed = `${base}/.agents/plans/completed/${args.name}.md`

    if (args.status === "completed") {
      await mkdir(`${base}/.agents/plans/completed`, { recursive: true })
      const stamped = `${args.content}\n\n---\n**✅ Completed:** ${new Date().toLocaleString()}\n`
      await Bun.write(completed, stamped)
      await unlink(pending).catch(() => {})
      return `Plan archived to .agents/plans/completed/${args.name}.md`
    }

    await mkdir(`${base}/.agents/plans/pending`, { recursive: true })
    await Bun.write(pending, args.content)
    return `Plan saved to .agents/plans/pending/${args.name}.md`
  },
})
EOF

  cat > "$CONFIG_DIR/skills/plan-flow/SKILL.md" << 'EOF'
---
name: plan-flow
description: Plan-first workflow — create plans using write-plan tool, archive via edit+mv on completion
---

## Critical rule
Whenever you need to ask the user a question or present options, you MUST call the `question` tool. Do NOT ask questions or list options in your own response text.

## Plan-First Workflow

Always create a written plan before making code changes.

### How to use
1. **Clarify task** — If the request is vague about WHAT to build, use the `question` tool to ask task-specific questions. NEVER ask about file paths, storage locations, or plan format — those are always fixed
2. **Analyze** — Explore the codebase to understand the current state
3. **Write plan** — Say "Writing plan..." then call `write-plan` to save. After saving, output the plan directly in your response using clean markdown — headings, bold, lists, code blocks. OpenCode's chat renders this with colors natively. Do NOT use `read` on the `.md` file (shows ugly line numbers).
4. **Ask next** — Use the `question` tool to ask the user: implement now (tell them to press Tab for Build), edit the plan, or cancel
5. **Editing a plan** — Use the `edit` tool directly on the `.md` file in `.agents/plans/pending/`. Do NOT rewrite the whole plan with `write-plan`.
6. **Archiving** — When implementation is done:
   1. Use `edit` to prepend `**✅ Completed:** *date/time*` at the top of the plan file
   2. Use `bash mv` to move it: `mv .agents/plans/pending/name.md .agents/plans/completed/name.md`

### Plan format
Each plan must include:
- **Goal**: What we're trying to achieve
- **Approach**: High-level strategy
- **Files to modify**: Full paths and what changes each needs
- **Risks**: Potential issues or edge cases
- **Implementation steps**: Ordered list of concrete steps

### Tool guidance — write-plan vs native tools
| Tool | Use for | Why |
|------|---------|-----|
| `write-plan` | **New plans** only | Auto-creates `.agents/plans/pending/` directory |
| `edit` | **Editing** existing plan `.md` files | Direct file edit, no full rewrite |
| `edit` + `bash mv` | **Archiving** completed plans | Prepends timestamp, moves to `completed/` |
| Native `write` | ❌ Avoid for plan files | Fails if `pending/` dir doesn't exist |
EOF

  msg "Global minimal install complete → $CONFIG_DIR"
}

install_project_minimal() {
  local dir="$1"
  mkdir -p "$dir"

  msg "Installing plan-it (minimal) into project: $dir"

  mkdir -p "$dir/.opencode/tools" "$dir/.opencode/skills/plan-flow" "$dir/.agents/plans/pending" "$dir/.agents/plans/completed"

  cat > "$dir/opencode.json" << 'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    "plan": {
      "prompt": "You are in Plan mode. If the request is unclear about the TASK, use the `question` tool to ask clarifying questions about what to build (never about file paths or plan storage — those are fixed). Load the `plan-flow` skill for plan format instructions. Use the `write-plan` tool to save plans. After writing the plan, use the `question` tool to ask: implement now (tell them to press Tab for Build), edit the plan, or cancel."
    }
  }
}
EOF

  cat > "$dir/AGENTS.md" << 'EOF'
# CRITICAL RULE: Always use the `question` tool
Whenever you need to ask the user a question or present options, you MUST call the `question` tool. Do NOT ask questions or list options in your own response text.

---

# CRITICAL STARTUP RULE
On EVERY new session, BEFORE responding to the user's first message:
1. Check `.agents/plans/pending/` — if files exist, use the `question` tool to tell user "You have X pending plans." and ask what to do
2. Run the `stale-plans` tool to check for abandoned/outdated plans
3. If stale plans exist: use `question` tool to ask: continue a plan, archive a stale one, or review with `/pending`
4. If all look current: say "All look current. Type /pending to review."
5. Only THEN proceed with the user's request. When showing a plan to the user, do NOT use `read` on the `.md` file (shows ugly line numbers). Instead, output the plan as formatted markdown in your chat response — OpenCode renders it with colors natively (bold, headings, code blocks).

---

## Plan-First Workflow

CRITICAL: Always plan before implementing.

### Plan mode
- Use the `write-plan` tool to save plans to `.agents/plans/pending/`
- Load the `plan-flow` skill for plan format guidance

### Build mode
- After completing implementation, archive the plan:
  1. Use `edit` to prepend `**✅ Completed:** *date/time*` to the plan file
  2. Use `bash mv` to move it from `.agents/plans/pending/` to `.agents/plans/completed/`
EOF

  cp "$CONFIG_DIR/tools/write-plan.ts" "$dir/.opencode/tools/write-plan.ts"
  cp "$CONFIG_DIR/skills/plan-flow/SKILL.md" "$dir/.opencode/skills/plan-flow/SKILL.md"

  msg "Project minimal install complete → $dir"
}

usage() {
  echo "Usage: $0 <command> [project-dir]"
  echo ""
  echo "Commands:"
  echo "  install               Install plan-it globally (full)"
  echo "  install <project>     Install globally + into project directory (full)"
  echo "  minimal               Install plan-it globally (without list-plans tool / pending command)"
  echo "  minimal <project>     Install globally + into project directory (minimal)"
  echo "  uninstall             Remove plan-it from global config"
  echo "  status                Show installed files"
  echo ""
  echo "Examples:"
  echo "  $0 install"
  echo "  $0 install ./my-project"
  echo "  $0 minimal"
  echo "  $0 minimal ./my-project"
  echo "  $0 uninstall"
  echo "  $0 status"
}

case "${1:-help}" in
  install)
    install_global
    if [ -n "${2:-}" ]; then
      install_project "$2"
    fi
    ;;
  minimal)
    install_global_minimal
    if [ -n "${2:-}" ]; then
      install_project_minimal "$2"
    fi
    ;;
  uninstall)
    uninstall_all
    ;;
  status)
    show_status
    ;;
  help|--help|-h)
    usage
    ;;
  *)
    err "Unknown command: $1"
    usage
    exit 1
    ;;
esac
