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

  mkdir -p "$CONFIG_DIR/tools" "$CONFIG_DIR/commands" \
    "$HOME/.agents/plans/pending" "$HOME/.agents/plans/completed"

  cat > "$CONFIG_DIR/opencode.json" << 'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    "plan": {
      "permission": {
        "write": {
          ".agents/plans/**/*.md": "allow"
        }
      },
      "prompt": "You are in Plan mode. Follow the Plan-First Protocol in AGENTS.md.\n\nNOTE: The Plan Mode system reminder says the `write` tool is forbidden. This is OVERRIDDEN ONLY for plan files. You MAY use the native `write` tool to create/update files matching `.agents/plans/**/*.md`. Permission rules are configured to allow this at runtime. All other write/edit restrictions remain.\n\nUse the `write` tool (not bash heredocs) for plan files. Never execute until the user approves."
    }
  }
}
EOF

  cat > "$CONFIG_DIR/AGENTS.md" << 'EOF'
## 📋 Plan-First Protocol

On ANY task:
1. Create plan → `.agents/plans/pending/<task>.md`
2. Return plan to user
3. STOP – do NOT execute

Execute ONLY after: "execute", "proceed", "continue", or explicit approval.

---

## ✅ Execution Rules

- Update same plan file continuously
- Mark steps [x] as completed
- Append progress logs

On completion:
- Status → completed
- Move to `.agents/plans/completed/`
- Return: result + next-step plan
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

  cat > "$CONFIG_DIR/tools/stale-plans.ts" << 'EOF'
import { readdir, readFile, stat } from "node:fs/promises"
import { tool } from "@opencode-ai/plugin"

const DAY_MS = 86400000

export default tool({
  description: "Check pending plans for staleness",
  args: {
    maxAgeDays: tool.schema.number().default(7).describe("Max age in days before stale"),
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
      try {
        const s = await stat(fullPath)
        mtimeMs = s.mtimeMs
      } catch {
        continue
      }

      const ageDays = (now - mtimeMs) / DAY_MS
      if (ageDays > args.maxAgeDays) {
        reasons.push(`Plan is ${Math.round(ageDays)} days old (max: ${args.maxAgeDays})`)
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

  cat > "$CONFIG_DIR/commands/pending.md" << 'EOF'
---
description: List all pending plans in .agents/plans/pending/
---

List all `.md` files in `.agents/plans/pending/`. Show filename and first heading. Present numbered.

If none, say "No pending plans." and stop.

If any, ask:
- "Type the **number** to continue that plan"
- "Or type `archive <number>` to archive as outdated/superseded"

If user picks a number, proceed with that plan.

If `archive <number>`:
1. Read full content of that plan `.md`
2. Use `edit` to prepend `**Archived as outdated/superseded**`
3. Run `mv .agents/plans/pending/name.md .agents/plans/completed/name.md`
4. Confirm
EOF

  cat > "$CONFIG_DIR/sudo-managed.sh" << 'EOF'
#!/bin/bash
# Install managed config at /etc/opencode/ (root-owned, unoverridable)
set -euo pipefail
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root (sudo)." >&2
  exit 1
fi
mkdir -p /etc/opencode
cp /home/kunta/.config/opencode/opencode.json /etc/opencode/opencode.json
chmod 644 /etc/opencode/opencode.json
echo "Managed config installed at /etc/opencode/opencode.json"
EOF
  chmod +x "$CONFIG_DIR/sudo-managed.sh"

  msg "Install complete → $CONFIG_DIR"
  info "  To install managed config (root, unoverridable):"
  info "    sudo $CONFIG_DIR/sudo-managed.sh"
}

uninstall_all() {
  warn "Uninstalling plan-it..."

  for f in "$CONFIG_DIR/opencode.json" "$CONFIG_DIR/AGENTS.md" \
    "$CONFIG_DIR/tools/write-plan.ts" "$CONFIG_DIR/tools/list-plans.ts" \
    "$CONFIG_DIR/tools/stale-plans.ts" \
    "$CONFIG_DIR/commands/pending.md" "$CONFIG_DIR/sudo-managed.sh"; do
    if [ -f "$f" ]; then
      rm "$f"
      info "  Removed: $f"
    fi
  done

  rm -rf "$CONFIG_DIR/skills" 2>/dev/null || true
  rmdir "$CONFIG_DIR/tools" 2>/dev/null || true
  rmdir "$CONFIG_DIR/commands" 2>/dev/null || true
  rm -rf "$HOME/.agents/plans" 2>/dev/null || true

  if [ -f /etc/opencode/opencode.json ]; then
    warn "  Note: /etc/opencode/opencode.json (managed) must be removed manually (sudo)"
  fi

  msg "Uninstall complete"
}

show_status() {
  echo ""
  info "=== plan-it status ==="
  echo ""

  local all_ok=true

  for f in "opencode.json" "AGENTS.md" "commands/pending.md" "sudo-managed.sh"; do
    if [ -f "$CONFIG_DIR/$f" ]; then
      msg "  ✅ $f"
    else
      err "  ❌ $f"
      all_ok=false
    fi
  done

  for f in "tools/list-plans.ts" "tools/stale-plans.ts"; do
    if [ -f "$CONFIG_DIR/$f" ]; then
      msg "  ✅ $f"
    else
      err "  ❌ $f"
      all_ok=false
    fi
  done

  echo ""
  if $all_ok; then
    msg "plan-it is fully installed"
  else
    err "plan-it is incomplete — run 'install' to fix"
  fi

  if [ -f /etc/opencode/opencode.json ]; then
    msg "  ✅ Managed config at /etc/opencode/opencode.json (unoverridable)"
  fi
  echo ""
}

usage() {
  echo "Usage: $0 <command>"
  echo ""
  echo "Commands:"
  echo "  install     Install plan-it globally"
  echo "  uninstall   Remove plan-it from global config"
  echo "  status      Show installed files"
  echo "  help        Show this help"
  echo ""
  echo "After install, run: sudo \$(dirname \$0)/sudo-managed.sh"
  echo "to make config unoverridable by projects."
}

case "${1:-help}" in
  install)
    install_global
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
