# opencode-tools — AI workflow tools for OpenCode

A collection of tools that make OpenCode smarter about planning and documentation.

- **planit** — Plan-first workflow: analyze, plan, implement, archive
- **doc-it** — AI-native documentation enforcement: auto-update docs on every change

---

## Quick start

### 1. Install planit (plan-first workflow)

Tell the agent:

```
Install this https://raw.githubusercontent.com/innowesley/opencode-tools/main/install-planit.sh
```

Or run it yourself:

```bash
curl -fsSL https://raw.githubusercontent.com/innowesley/opencode-tools/main/install-planit.sh | bash
```

### 2. (Optional) Add doc-it for documentation enforcement

Tell the agent:

```
Install this https://raw.githubusercontent.com/innowesley/opencode-tools/main/install-doc-it.sh
```

Or run it yourself:

```bash
curl -fsSL https://raw.githubusercontent.com/innowesley/opencode-tools/main/install-doc-it.sh | bash
```

---

## planit — Plan-first workflow

Plan once, use in every OpenCode project. Forces OpenCode to plan before building.

### Install into a specific project

```bash
curl -fsSL https://raw.githubusercontent.com/innowesley/opencode-tools/main/install-planit.sh | bash -s -- install ./my-project
```

Or tell the agent: *"Install planit into this project from the URL."*

### Minimal install (no extras)

```bash
curl -fsSL https://raw.githubusercontent.com/innowesley/opencode-tools/main/install-planit.sh | bash -s -- minimal
```

Skips optional extras: `list-plans`, `stale-plans` tools and `/pending` command.

### Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/innowesley/opencode-tools/main/install-planit.sh | bash -s -- uninstall
```

### Check status

```bash
curl -fsSL https://raw.githubusercontent.com/innowesley/opencode-tools/main/install-planit.sh | bash -s -- status
```

### What it installs

| Component | Location | What it does |
|-----------|----------|-------------|
| `write-plan` tool | `~/.config/opencode/tools/` | Saves plans to `.agents/plans/pending/`, archives to `completed/` with timestamp |
| `list-plans` tool | `~/.config/opencode/tools/` | Agent can list pending/completed plans programmatically |
| `stale-plans` tool | `~/.config/opencode/tools/` | Detects old, abandoned, or context-shifted plans |
| `/pending` command | `~/.config/opencode/commands/` | Type `/pending` to see, continue, or archive plans |
| `plan-flow` skill | `~/.config/opencode/skills/` | Instructions for plan format and workflow |
| Plan prompt | `~/.config/opencode/opencode.json` | Tells Plan mode to use `write-plan` + `question` tool |
| Instructions | `~/.config/opencode/AGENTS.md` | Global fallback instructions with startup check |

### Workflow

1. OpenCode starts — if you have pending plans, it greets you with a count and checks for stale/abandoned plans
2. Stale plans are flagged: old, context shifted, or may be done. Continue, archive, or review with `/pending`
3. Type `/pending` anytime to see what's waiting — pick a number to continue, or `archive <number>` to move an outdated plan to `completed/`
4. Give OpenCode a task
5. Plan mode analyzes, asks clarifying questions, writes plan to `.agents/plans/pending/`
6. Plan mode asks: **Implement?** (press Tab for Build) / **Edit?** / **Cancel?**
7. Build mode implements, archives plan to `.agents/plans/completed/`

---

## doc-it — AI-native documentation enforcement

Prevents AI doc rot and drift. Every execute task auto-updates docs.

> **Note:** doc-it is opt-in. Global install just puts the tools in place. You must run `install ./my-project` to activate the documentation pipeline in a project.

### Initialize a project

```bash
curl -fsSL https://raw.githubusercontent.com/innowesley/opencode-tools/main/install-doc-it.sh | bash -s -- install ./my-project
```

Or tell the agent: *"Install doc-it into this project from the URL."*

### Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/innowesley/opencode-tools/main/install-doc-it.sh | bash -s -- uninstall
```

### Check status

```bash
curl -fsSL https://raw.githubusercontent.com/innowesley/opencode-tools/main/install-doc-it.sh | bash -s -- status
```

### What it installs

| Component | Location | What it does |
|-----------|----------|-------------|
| `doc-drift-checker` | `.opencode/tools/` | Detects stale/missing docs from changed source |
| `changelog-generator` | `.opencode/tools/` | Creates changelog entries in docs/changelogs/ |
| `traceability-generator` | `.opencode/tools/` | Builds feature→files→routes→tables→tests→docs map |
| `ai-context-generator` | `.opencode/tools/` | Regenerates current-system-state.md + project-summary.md |
| `rule-violation-checker` | `.opencode/tools/` | Detects direct DB writes, undocumented routes, contract violations |
| docs/ | project root | Full docs tree (ai-context, architecture, features, database, api, contracts, future, etc.) |
| .ai/ | project root | Agent rules: execute pipeline, doc-rules, architecture-rules, testing-rules, completion-checklist |

### Execute pipeline

Every build task follows: **LOAD CONTEXT** → **ANALYZE** → **CHECK DOCS** → **IMPLEMENT** → **UPDATE DOCS** → **CHANGELOG** → **TRACEABILITY** → **AI CONTEXT** → **CHECK VIOLATIONS** → **COMPLETE**.

Tasks **FAIL** if any doc step is skipped.

---

## Combined workflow

```
                    ┌──────────────┐
                    │  OpenCode    │
                    │   starts     │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │ Check for    │
                    │ pending/stale│ ←── planit
                    │ plans        │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │ User gives   │
                    │ a task       │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │ Plan mode:   │
                    │ analyze, ask,│ ←── planit
                    │ write plan   │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │ Build mode:  │
                    │ implement,   │
                    │ update docs, │ ←── planit + doc-it
                    │ changelog,   │
                    │ archive plan │
                    └──────────────┘
```

## Development

The repo lives at `github.com/innowesley/opencode-tools`. Clone it:

```bash
git clone git@github.com:innowesley/opencode-tools.git
```

Edit the install scripts or this README, then push. Users always install from the `main` branch via raw.githubusercontent.com.
