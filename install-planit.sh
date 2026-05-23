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
  msg "Installing planit globally..."

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
## Plan-First Workflow

CRITICAL: Always plan before implementing.

### On startup
- Check `.agents/plans/pending/` — if files exist, tell the user: "You have X pending plans. Type /pending to see them."

### Plan mode
- Use the `write-plan` tool to save plans to `.agents/plans/pending/`
- Load the `plan-flow` skill for plan format guidance

### Build mode
- After completing implementation, use `write-plan` with `status: "completed"` to archive the plan to `.agents/plans/completed/`
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

If the user picks a number, proceed with that plan.

If the user says `archive <number>`:
1. Read the full content of that plan's `.md` file
2. Prepend `**Archived as outdated/superseded**` to the content
3. Call `write-plan` with `name` (filename without .md), `content` (modified content), and `status: "completed"`
4. Confirm the plan was archived
EOF

  cat > "$CONFIG_DIR/skills/plan-flow/SKILL.md" << 'EOF'
---
name: plan-flow
description: Plan-first workflow — create plans using write-plan tool, auto-archive on completion
---

## Plan-First Workflow

Always create a written plan before making code changes.

### How to use
1. **Clarify task** — If the request is vague about WHAT to build, use the `question` tool to ask task-specific questions. NEVER ask about file paths, storage locations, or plan format — those are always fixed
2. **Analyze** — Explore the codebase to understand the current state
3. **Write plan** — Call `write-plan` with:
   - `name` — short kebab-case name (e.g., `add-auth-flow`)
   - `content` — full plan in markdown
   - `status: "pending"` — for active plans
4. **Ask next** — Use the `question` tool to ask the user: implement now (tell them to press Tab for Build), edit the plan, or cancel
5. When implementation is done, call `write-plan` with `status: "completed"` to archive

### Plan format
Each plan must include:
- **Goal**: What we're trying to achieve
- **Approach**: High-level strategy
- **Files to modify**: Full paths and what changes each needs
- **Risks**: Potential issues or edge cases
- **Implementation steps**: Ordered list of concrete steps
EOF

  msg "Global install complete → $CONFIG_DIR"
}

install_project() {
  local dir="$1"
  mkdir -p "$dir"

  msg "Installing planit into project: $dir"

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
## Plan-First Workflow

CRITICAL: Always plan before implementing.

### On startup
- Check `.agents/plans/pending/` — if files exist, tell the user: "You have X pending plans. Type /pending to see them."

### Plan mode
- Use the `write-plan` tool to save plans to `.agents/plans/pending/`
- Load the `plan-flow` skill for plan format guidance

### Build mode
- After completing implementation, use `write-plan` with `status: "completed"` to archive the plan to `.agents/plans/completed/`
EOF

  cp "$CONFIG_DIR/tools/write-plan.ts" "$dir/.opencode/tools/write-plan.ts"
  cp "$CONFIG_DIR/tools/list-plans.ts" "$dir/.opencode/tools/list-plans.ts"
  cp "$CONFIG_DIR/commands/pending.md" "$dir/.opencode/commands/pending.md"
  cp "$CONFIG_DIR/skills/plan-flow/SKILL.md" "$dir/.opencode/skills/plan-flow/SKILL.md"

  msg "Project install complete → $dir"
}

uninstall_all() {
  warn "Uninstalling planit..."

  for f in "$CONFIG_DIR/opencode.json" "$CONFIG_DIR/AGENTS.md" "$CONFIG_DIR/tools/write-plan.ts" "$CONFIG_DIR/tools/list-plans.ts" "$CONFIG_DIR/commands/pending.md" "$CONFIG_DIR/skills/plan-flow/SKILL.md"; do
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
  info "=== planit status ==="
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

  if [ -f "$CONFIG_DIR/tools/list-plans.ts" ]; then
    msg "  ✅ tools/list-plans.ts"
    has_list_plans=true
  else
    warn "  ⬜ tools/list-plans.ts (optional — not installed)"
  fi

  if [ -f "$CONFIG_DIR/commands/pending.md" ]; then
    msg "  ✅ commands/pending.md"
    has_pending_cmd=true
  else
    warn "  ⬜ commands/pending.md (optional — not installed)"
  fi

  echo ""
  if $all_ok; then
    if $has_list_plans || $has_pending_cmd; then
      msg "planit is fully installed (with extras)"
    else
      msg "planit is installed (minimal)"
    fi
  else
    err "planit is incomplete — run 'install' to fix"
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
  msg "Installing planit (minimal) globally..."

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
## Plan-First Workflow

CRITICAL: Always plan before implementing.

### Plan mode
- Use the `write-plan` tool to save plans to `.agents/plans/pending/`
- Load the `plan-flow` skill for plan format guidance

### Build mode
- After completing implementation, use `write-plan` with `status: "completed"` to archive the plan to `.agents/plans/completed/`
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
description: Plan-first workflow — create plans using write-plan tool, auto-archive on completion
---

## Plan-First Workflow

Always create a written plan before making code changes.

### How to use
1. **Clarify task** — If the request is vague about WHAT to build, use the `question` tool to ask task-specific questions. NEVER ask about file paths, storage locations, or plan format — those are always fixed
2. **Analyze** — Explore the codebase to understand the current state
3. **Write plan** — Call `write-plan` with:
   - `name` — short kebab-case name (e.g., `add-auth-flow`)
   - `content` — full plan in markdown
   - `status: "pending"` — for active plans
4. **Ask next** — Use the `question` tool to ask the user: implement now (tell them to press Tab for Build), edit the plan, or cancel
5. When implementation is done, call `write-plan` with `status: "completed"` to archive

### Plan format
Each plan must include:
- **Goal**: What we're trying to achieve
- **Approach**: High-level strategy
- **Files to modify**: Full paths and what changes each needs
- **Risks**: Potential issues or edge cases
- **Implementation steps**: Ordered list of concrete steps
EOF

  msg "Global minimal install complete → $CONFIG_DIR"
}

install_project_minimal() {
  local dir="$1"
  mkdir -p "$dir"

  msg "Installing planit (minimal) into project: $dir"

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
## Plan-First Workflow

CRITICAL: Always plan before implementing.

### Plan mode
- Use the `write-plan` tool to save plans to `.agents/plans/pending/`
- Load the `plan-flow` skill for plan format guidance

### Build mode
- After completing implementation, use `write-plan` with `status: "completed"` to archive the plan to `.agents/plans/completed/`
EOF

  cp "$CONFIG_DIR/tools/write-plan.ts" "$dir/.opencode/tools/write-plan.ts"
  cp "$CONFIG_DIR/skills/plan-flow/SKILL.md" "$dir/.opencode/skills/plan-flow/SKILL.md"

  msg "Project minimal install complete → $dir"
}

usage() {
  echo "Usage: $0 <command> [project-dir]"
  echo ""
  echo "Commands:"
  echo "  install               Install planit globally (full)"
  echo "  install <project>     Install globally + into project directory (full)"
  echo "  minimal               Install planit globally (without list-plans tool / pending command)"
  echo "  minimal <project>     Install globally + into project directory (minimal)"
  echo "  uninstall             Remove planit from global config"
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
