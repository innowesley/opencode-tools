# plan-it — Deep reference

## What it installs

| Component | Location | Purpose |
|-----------|----------|---------|
| `bash cat <<'EOF' > file` (new plans) | Plan mode workflow | Saves plans via heredoc — avoids tool-argument display in the main messages panel |
| `write-plan` tool | `~/.config/opencode/tools/` | Archives completed plans with timestamp. Not used for new plans. |
| `list-plans` tool | `~/.config/opencode/tools/` | Agent lists pending/completed plans programmatically |
| `stale-plans` tool | `~/.config/opencode/tools/` | Detects old, abandoned, or context-shifted plans |
| `/pending` command | `~/.config/opencode/commands/` | Type `/pending` to see, continue, or archive plans |
| `plan-flow` skill | `~/.config/opencode/skills/` | Instructions for plan format and workflow |
| Plan prompt | `~/.config/opencode/opencode.json` | Tells Plan mode to use bash heredoc + `question` tool |
| Instructions | `~/.config/opencode/AGENTS.md` | Global fallback instructions with startup check |

## Why bash heredoc? (not write-plan for new plans)

OpenCode's TUI displays tool arguments inline. Passing the full plan content as a `write-plan` tool argument cluttered the main messages panel with raw structured text. Using `bash cat << 'EOF' > file` keeps the plan cleanly in the chat as formatted markdown while the file write happens silently via shell heredoc.

`write-plan` is retained only for archiving completed plans (backwards compatibility).

## Workflow

1. OpenCode starts — checks for pending plans, greets with a count, checks for stale/abandoned plans
2. Stale plans are flagged: old, context shifted, or may be done. Continue, archive, or review with `/pending`
3. Type `/pending` anytime to see what's waiting — pick a number to continue, or `archive <number>` to move an outdated plan to `completed/`
4. Give OpenCode a task
5. Plan mode analyzes, asks clarifying questions, outputs the plan as formatted markdown in the main messages panel, then saves it via `bash cat << 'EOF' > .agents/plans/pending/name.md`
6. Plan mode asks: **Implement?** (press Tab for Build) / **Edit?** / **Cancel?**
7. Build mode implements, archives plan to `.agents/plans/completed/`

## Commands

| Command | What it does |
|---------|-------------|
| `curl ... \| bash` | Global install (all projects) |
| `curl ... \| bash -s -- install ./my-project` | Install into a specific project |
| `curl ... \| bash -s -- minimal` | Install without list-plans, stale-plans tools, or /pending command |
| `curl ... \| bash -s -- uninstall` | Remove plan-it |
| `curl ... \| bash -s -- status` | Check installed files |
