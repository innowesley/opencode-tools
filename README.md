# planit — Plan-first workflow for OpenCode

Install once, use in every OpenCode project.

## Copy-paste into OpenCode

```
Install this https://raw.githubusercontent.com/innowesley/planit/main/install-planit.sh
```

The agent will curl and run it automatically. No manual steps.

**Or run it yourself:**

```bash
curl -fsSL https://raw.githubusercontent.com/innowesley/planit/main/install-planit.sh | bash
```

## Install into a project too

```bash
curl -fsSL https://raw.githubusercontent.com/innowesley/planit/main/install-planit.sh | bash -s -- install ./my-project
```

Or tell the agent: *"Install planit into this project from the URL."*

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/innowesley/planit/main/install-planit.sh | bash -s -- uninstall
```

## Minimal install (without extras)

```bash
curl -fsSL https://raw.githubusercontent.com/innowesley/planit/main/install-planit.sh | bash -s -- minimal
```

Skips the optional `list-plans` tool and `/pending` command.

## Check status

```bash
curl -fsSL https://raw.githubusercontent.com/innowesley/planit/main/install-planit.sh | bash -s -- status
```

## How it works

| Component | Location | What it does |
|-----------|----------|-------------|
| `write-plan` tool | `~/.config/opencode/tools/` | Saves plans to `.agents/plans/pending/`, archives to `completed/` with timestamp |
| `list-plans` tool | `~/.config/opencode/tools/` | Agent can list pending/completed plans programmatically |
| `/pending` command | `~/.config/opencode/commands/` | Type `/pending` to see, continue, or archive plans |
| `plan-flow` skill | `~/.config/opencode/skills/` | Instructions for plan format and workflow |
| Plan prompt | `~/.config/opencode/opencode.json` | Tells Plan mode to use `write-plan` + `question` tool |
| Instructions | `~/.config/opencode/AGENTS.md` | Global fallback instructions with startup check |

## Workflow

1. OpenCode starts — if you have pending plans, it greets you with a count
2. Type `/pending` anytime to see what's waiting — pick a number to continue, or `archive <number>` to move an outdated plan to `completed/`
3. Give OpenCode a task
4. Plan mode analyzes, asks clarifying questions, writes plan to `.agents/plans/pending/`
5. Plan mode asks: **Implement?** (press Tab for Build) / **Edit?** / **Cancel?**
6. Build mode implements, archives plan to `.agents/plans/completed/`
