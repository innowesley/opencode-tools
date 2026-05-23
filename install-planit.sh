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

  msg "Global install complete → $CONFIG_DIR"
}

install_project() {
  local dir="$1"
  mkdir -p "$dir"

  msg "Installing planit into project: $dir"

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

  msg "Project install complete → $dir"
}

uninstall_all() {
  warn "Uninstalling planit..."

  for f in "$CONFIG_DIR/opencode.json" "$CONFIG_DIR/AGENTS.md" "$CONFIG_DIR/tools/write-plan.ts" "$CONFIG_DIR/skills/plan-flow/SKILL.md"; do
    if [ -f "$f" ]; then
      rm "$f"
      info "  Removed: $f"
    fi
  done

  rmdir "$CONFIG_DIR/tools" 2>/dev/null || true
  rmdir "$CONFIG_DIR/skills/plan-flow" 2>/dev/null || true
  rmdir "$CONFIG_DIR/skills" 2>/dev/null || true

  msg "Global uninstall complete"
}

show_status() {
  echo ""
  info "=== planit status ==="
  echo ""

  local all_ok=true

  for f in "opencode.json" "AGENTS.md" "tools/write-plan.ts" "skills/plan-flow/SKILL.md"; do
    if [ -f "$CONFIG_DIR/$f" ]; then
      msg "  ✅ $f"
    else
      err "  ❌ $f"
      all_ok=false
    fi
  done

  echo ""
  if $all_ok; then
    msg "planit is fully installed"
  else
    err "planit is incomplete — run 'install' to fix"
  fi
  echo ""
}

usage() {
  echo "Usage: $0 <command> [project-dir]"
  echo ""
  echo "Commands:"
  echo "  install               Install planit globally"
  echo "  install <project>     Install globally + into project directory"
  echo "  uninstall             Remove planit from global config"
  echo "  status                Show installed files"
  echo ""
  echo "Examples:"
  echo "  $0 install"
  echo "  $0 install ./my-project"
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
