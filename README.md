# planit — Plan-first workflow for OpenCode

Install once, use in every OpenCode project.

## Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USER/planit/main/install-planit.sh | bash
```

## Install into a project too

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USER/planit/main/install-planit.sh | bash -s -- install ./my-project
```

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USER/planit/main/install-planit.sh | bash -s -- uninstall
```

## Check status

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USER/planit/main/install-planit.sh | bash -s -- status
```

## How it works

| Component | Location | What it does |
|-----------|----------|-------------|
| `write-plan` tool | `~/.config/opencode/tools/` | Saves plans to `.agents/plans/pending/`, archives to `completed/` with timestamp |
| `plan-flow` skill | `~/.config/opencode/skills/` | Instructions for plan format and workflow |
| Plan prompt | `~/.config/opencode/opencode.json` | Tells Plan mode to use `write-plan` + `question` tool |
| Instructions | `~/.config/opencode/AGENTS.md` | Global fallback instructions |

## Workflow

1. Give OpenCode a task
2. Plan mode analyzes, asks clarifying questions, writes plan to `.agents/plans/pending/`
3. Plan mode asks: **Implement?** (press Tab for Build) / **Edit?** / **Cancel?**
4. Build mode implements, archives plan to `.agents/plans/completed/`
