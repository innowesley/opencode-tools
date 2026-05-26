# plan-it — Deep reference

## What it installs

### Opencode variant (`plan-it install opencode`)

| Component | Location | Purpose |
|-----------|----------|---------|
| `list-plans` tool | `~/.config/opencode/tools/` | Agent lists pending/completed plans programmatically |
| `related-plans` tool | `~/.config/opencode/tools/` | Finds plans by topic overlap |
| `stale-plans` tool | `~/.config/opencode/tools/` | Detects old, abandoned, or context-shifted plans |
| `/pending` command | `~/.config/opencode/commands/` | Type `/pending` to see, continue, or archive plans |
| Plan prompt | `~/.config/opencode/opencode.json` | Tells Plan mode to use bash heredoc + `question` tool |
| Instructions | `~/.config/opencode/AGENTS.md` | Global fallback instructions with startup check |

### Kilo variant (`plan-it install kilo`)

| Component | Location | Purpose |
|-----------|----------|---------|
| `list-plans` tool | `@opencode-tools/kilo-plugin` (Kilo plugin) | Agent lists pending/completed plans |
| `related-plans` tool | `@opencode-tools/kilo-plugin` | Finds plans by topic overlap |
| `stale-plans` tool | `@opencode-tools/kilo-plugin` | Detects old/abandoned plans |
| Instructions | `~/.config/kilo/AGENTS.md` | Kilo plan-first protocol |

## Plan directories (unified across Kilo and OpenCode)

| Status | Path |
|--------|------|
| Drafts (not yet approved) | `.kilo/plans/` (Kilo) or `.opencode/plans/` (Opencode) |
| In progress (approved, executing) | `.agents/plans/pending/` |
| Completed (archived) | `.agents/plans/completed/` |

## Workflow

1. Agent starts — checks for pending plans, greets with a count, checks for stale/abandoned plans
2. Stale plans are flagged: old, context shifted, or may be done
3. Give agent a task
4. Plan mode analyzes, asks clarifying questions, outputs the plan as formatted markdown, then saves it via `bash cat <<'EOF' > .kilo/plans/<task>.md` or `> .opencode/plans/<task>.md`
5. Plan mode asks: **Implement?** (press Tab for Build) / **Edit?** / **Cancel?**
6. On approval: `mv <draft>.md .agents/plans/pending/<task>.md`
7. Build mode implements
8. On completion: `mv .agents/plans/pending/<task>.md .agents/plans/completed/<task>.md`

## Commands

```
plan-it install kilo           Install plan-it for Kilo CLI
plan-it install opencode       Install plan-it for OpenCode
plan-it uninstall kilo         Remove plan-it (Kilo)
plan-it uninstall opencode     Remove plan-it (OpenCode)
plan-it status                 Show all installed components
plan-it status kilo            Show Kilo components only
plan-it list                   List active plans
plan-it help                   Show usage
```

Aliases: `add` = `install`, `rm` = `uninstall`
