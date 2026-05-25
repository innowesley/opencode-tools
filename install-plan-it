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
  # Note: .opencode/plans/ is per-project, created by the agent at write time
  # (via the write permission rule in opencode.json). No global mkdir needed.

  cat > "$CONFIG_DIR/opencode.json" << 'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    "plan": {
      "permission": {
        "write": {
          ".opencode/plans/**/*.md": "allow",
          ".agents/plans/**/*.md": "allow"
        }
      },
      "prompt": "You are in Plan mode. Follow the Plan-First Protocol in AGENTS.md.\n\nNOTE: The Plan Mode system reminder says the `write` tool is forbidden. This is OVERRIDDEN ONLY for plan files. You MAY use the native `write` tool to create/update files matching `.opencode/plans/**/*.md` or `.agents/plans/**/*.md`. Permission rules are configured to allow this at runtime. All other write/edit restrictions remain.\n\nIMPORTANT: Use `mv` (not `cp`) when moving plan files between directories. `cp` would leave stale copies.\n\nUse the `write` tool (not bash heredocs) for plan files. Never execute until the user approves."
    }
  }
}
EOF

  cat > "$CONFIG_DIR/AGENTS.md" << 'EOF'
## 📋 Plan-First Protocol

On ANY task:
1. Create plan → `.opencode/plans/<task>.md`
2. Return plan to user
3. STOP – do NOT execute

Execute ONLY after: "execute", "proceed", "continue", or explicit approval.

---

## ✅ Execution Rules

After user approves:
1. `mv .opencode/plans/<task>.md .agents/plans/pending/<task>.md` (NEVER use `cp`)
2. Execute the plan, updating `.agents/plans/pending/<task>.md` continuously
3. Mark steps [x] as completed
4. Append progress logs

On completion:
1. Status → completed
2. `mv .agents/plans/pending/<task>.md .agents/plans/completed/<task>.md` (NEVER use `cp`)
3. Return: result + next-step plan
EOF

  cat > "$CONFIG_DIR/tools/list-plans.ts" << 'EOF'
import { readdir } from "node:fs/promises"
import { tool } from "@opencode-ai/plugin"

const STATUS_DIRS: Record<string, string> = {
  drafts: ".opencode/plans",
  pending: ".agents/plans/pending",
  completed: ".agents/plans/completed",
}

export default tool({
  description: "List plan files by status",
  args: {
    status: tool.schema.enum(["drafts", "pending", "completed"]).default("pending").describe("drafts = .opencode/plans/, pending = .agents/plans/pending/, completed = .agents/plans/completed/"),
  },
  async execute(args, context) {
    const base = (context.worktree && context.worktree !== '/') ? context.worktree : context.directory
    const subdir = STATUS_DIRS[args.status]
    if (!subdir) {
      return JSON.stringify({ count: 0, plans: [], error: `Unknown status: ${args.status}` })
    }
    const dir = `${base}/${subdir}`

    let files: string[]
    try {
      files = await readdir(dir)
    } catch {
      return JSON.stringify({ count: 0, plans: [] })
    }

    const plans = files
      .filter(f => f.endsWith(".md"))
      .map(f => f.replace(/\.md$/, ""))

    return JSON.stringify({ count: plans.length, plans, status: args.status, dir: subdir })
  },
})
EOF

  cat > "$CONFIG_DIR/tools/related-plans.ts" << 'EOF'
import { readdir, readFile, stat } from "node:fs/promises"
import { tool } from "@opencode-ai/plugin"

const STOP_WORDS = new Set([
  "the", "and", "for", "with", "this", "that", "from", "into", "onto",
  "upon", "plan", "task", "item", "add", "update", "remove", "fix",
  "implement", "make", "set", "get", "put", "use", "using", "allow",
])

function extractTopics(name: string, content: string): string[] {
  const words = new Set<string>()

  name.split(/[-_\s]+/).forEach(w => {
    const lower = w.toLowerCase().replace(/[^a-z0-9]/g, "")
    if (lower.length >= 3 && !STOP_WORDS.has(lower)) words.add(lower)
  })

  const headingMatch = content.match(/^#+\s+(.+)/m)
  if (headingMatch) {
    headingMatch[1].split(/[-_\s]+/).forEach(w => {
      const lower = w.toLowerCase().replace(/[^a-z0-9]/g, "")
      if (lower.length >= 3 && !STOP_WORDS.has(lower)) words.add(lower)
    })
  }

  return [...words]
}

function scoreMatch(targetTopics: string[], candidateName: string, candidateContent: string): number {
  const candidateTopics = extractTopics(candidateName, candidateContent)
  let score = 0
  for (const t of targetTopics) {
    if (candidateTopics.includes(t)) score += 1
  }
  return score
}

export default tool({
  description: "Find plans related by topic keywords (filename + first heading overlap)",
  args: {
    planName: tool.schema.string().describe("Plan filename (without .md) to analyze for related plans"),
  },
  async execute(args, context) {
    const base = (context.worktree && context.worktree !== '/') ? context.worktree : context.directory
    const draftsDir = `${base}/.opencode/plans`
    const pendingDir = `${base}/.agents/plans/pending`
    const completedDir = `${base}/.agents/plans/completed`

    let planContent: string
    let planSource: string
    for (const [dir, label] of [[draftsDir, "drafts"], [pendingDir, "pending"] as const]) {
      try {
        planContent = await readFile(`${dir}/${args.planName}.md`, "utf-8")
        planSource = label
        break
      } catch {
        continue
      }
    }
    if (!planContent) {
      return JSON.stringify({ error: `Plan '${args.planName}' not found in drafts/ or pending/` })
    }

    const topics = extractTopics(args.planName, planContent)

    async function scanDir(dir: string): Promise<{ name: string; matchScore: number }[]> {
      let files: string[]
      try {
        files = await readdir(dir)
      } catch {
        return []
      }

      const results: { name: string; matchScore: number; mtimeMs?: number }[] = []

      for (const file of files) {
        if (!file.endsWith(".md")) continue
        const name = file.replace(/\.md$/, "")
        if (name === args.planName) continue

        const fullPath = `${dir}/${file}`
        let content: string
        let mtimeMs: number
        try {
          content = await readFile(fullPath, "utf-8")
          const s = await stat(fullPath)
          mtimeMs = s.mtimeMs
        } catch {
          continue
        }

        const score = scoreMatch(topics, name, content)
        if (score > 0) {
          results.push({ name, matchScore: score, mtimeMs })
        }
      }

      results.sort((a, b) => {
        if (b.matchScore !== a.matchScore) return b.matchScore - a.matchScore
        return (b.mtimeMs ?? 0) - (a.mtimeMs ?? 0)
      })

      return results.map(r => ({ name: r.name, matchScore: r.matchScore }))
    }

    const [relatedDrafts, relatedPending, allRelatedCompleted] = await Promise.all([
      scanDir(draftsDir),
      scanDir(pendingDir),
      scanDir(completedDir),
    ])

    const relatedCompleted = allRelatedCompleted.slice(0, 3)

    return JSON.stringify({
      analyzedPlan: args.planName,
      planSource,
      topics,
      relatedDrafts,
      relatedPending,
      relatedCompleted,
    })
  },
})
EOF

  cat > "$CONFIG_DIR/tools/stale-plans.ts" << 'EOF'
import { readdir, readFile, stat } from "node:fs/promises"
import { tool } from "@opencode-ai/plugin"

const DAY_MS = 86400000

async function checkDirStaleness(dir: string, label: string, maxAgeDays: number): Promise<{ stale: any[]; healthy: string[]; count: number }> {
  const stale: any[] = []
  const healthy: string[] = []

  let files: string[]
  try {
    files = await readdir(dir)
  } catch {
    return { count: 0, stale: [], healthy: [] }
  }

  const planFiles = files.filter(f => f.endsWith(".md"))
  if (planFiles.length === 0) {
    return { count: 0, stale: [], healthy: [] }
  }

  const now = Date.now()

  for (const file of planFiles) {
    const fullPath = `${dir}/${file}`
    const reasons: string[] = []

    let mtimeMs: number
    try {
      const s = await stat(fullPath)
      mtimeMs = s.mtimeMs
    } catch {
      continue
    }

    const ageDays = (now - mtimeMs) / DAY_MS
    if (ageDays > maxAgeDays) {
      reasons.push(`Plan is ${Math.round(ageDays)} days old (max: ${maxAgeDays})`)
    }

    const name = file.replace(/\.md$/, "")
    if (reasons.length > 0) {
      stale.push({ name, ageDays: Math.round(ageDays), dir: label, reasons })
    } else {
      healthy.push(`${label}/${name}`)
    }
  }

  return { count: planFiles.length, stale, healthy }
}

export default tool({
  description: "Check pending plans for staleness",
  args: {
    maxAgeDays: tool.schema.number().default(7).describe("Max age in days before stale"),
  },
  async execute(args, context) {
    const base = (context.worktree && context.worktree !== '/') ? context.worktree : context.directory
    const [draftsResult, pendingResult] = await Promise.all([
      checkDirStaleness(`${base}/.opencode/plans`, "drafts", args.maxAgeDays),
      checkDirStaleness(`${base}/.agents/plans/pending`, "pending", args.maxAgeDays),
    ])

    return JSON.stringify({
      count: draftsResult.count + pendingResult.count,
      stale: [...draftsResult.stale, ...pendingResult.stale],
      healthy: [...draftsResult.healthy, ...pendingResult.healthy],
    })
  },
})
EOF

  cat > "$CONFIG_DIR/commands/pending.md" << 'EOF'
---
description: List all drafts and pending plans
---

1. List all `.md` files in:
   - **Drafts** (not yet approved): `.opencode/plans/`
   - **In progress** (approved, executing): `.agents/plans/pending/`
   Show filename and first heading for each. Present numbered.

2. If both are empty, say "No plans found." and stop.

3. Display format:
   ```
   📄 Drafts (.opencode/plans/):
     1. <name> — <heading>
     ...

   🚀 In Progress (.agents/plans/pending/):
     4. <name> — <heading>
     ...
   ```

4. If only one section has items, just show that section.

5. Ask:
   - "Type the **number** to continue that plan"
   - "Type **info <number>** to see related plans and context"
   - "Type **archive <number>** to archive in-progress plan as outdated/superseded"

6. If user picks `info <number>`:
   - Read the plan content
   - Call the `related-plans` tool with `planName` set to the chosen plan name
   - Display the result clearly:
     ```
     📋 Plan: <plan-name>
     🏷️  Topics: <topic1>, <topic2>, ...

     📌 Related Draft Plans (<count>):
       - <name> (matches: <score>)
       ...

     📁 Related In-Progress Plans (<count>):
       - <name> (matches: <score>)
       ...

     📁 Related Completed Plans (most recent 3):
       - <name> (matches: <score>)
       ...
     ```
   - Ask: "Continue this plan? Type the **number** or **n** to go back"

7. If user picks a number (directly or after info):
   - If it's a draft: ask "Approve this plan? (y/n)". If yes, run `mv .opencode/plans/<name>.md .agents/plans/pending/<name>.md` then proceed with execution.
   - If it's in progress: proceed with that plan

8. If `archive <number>`:
   1. Read full content of that plan `.md`
   2. Use `edit` to prepend `**Archived as outdated/superseded**`
   3. Run `mv .agents/plans/pending/<name>.md .agents/plans/completed/<name>.md` (NEVER `cp`)
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
    "$CONFIG_DIR/tools/stale-plans.ts" "$CONFIG_DIR/tools/related-plans.ts" \
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

  for f in "tools/list-plans.ts" "tools/stale-plans.ts" "tools/related-plans.ts"; do
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
