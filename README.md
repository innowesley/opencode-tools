# opencode-tools — AI workflow tools for OpenCode

A collection of tools that make OpenCode smarter about planning and documentation.

- **plan-it** — Plan-first workflow: analyze, plan, implement, archive
- **doc-it** — AI-native documentation enforcement: auto-update docs on every change

---

## Quick start

### 1. Install plan-it (plan-first workflow)

Tell the agent:

```
Install this https://raw.githubusercontent.com/innowesley/opencode-tools/main/install-plan-it.sh
```

Or run it yourself:

```bash
curl -fsSL https://raw.githubusercontent.com/innowesley/opencode-tools/main/install-plan-it.sh | bash
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

## plan-it — Plan-first workflow

Plan once, use in every OpenCode project. Forces OpenCode to plan before building.

### Install into a specific project

Tell the agent:

```
Install plan-it into this project from the URL.
```

Or run it yourself:

```bash
curl -fsSL https://raw.githubusercontent.com/innowesley/opencode-tools/main/install-plan-it.sh | bash -s -- install ./my-project
```

### Minimal install (no extras)

```bash
curl -fsSL https://raw.githubusercontent.com/innowesley/opencode-tools/main/install-plan-it.sh | bash -s -- minimal
```

Skips optional extras: `list-plans`, `stale-plans` tools and `/pending` command.

### Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/innowesley/opencode-tools/main/install-plan-it.sh | bash -s -- uninstall
```

### Check status

```bash
curl -fsSL https://raw.githubusercontent.com/innowesley/opencode-tools/main/install-plan-it.sh | bash -s -- status
```

### What it installs

| Component | Location | What it does |
|-----------|----------|-------------|
| `bash cat <<'EOF' > file` (new plans) | Plan mode workflow | Saves plans via heredoc — avoids tool-argument display in the main messages panel |
| `write-plan` tool | `~/.config/opencode/tools/` | Archives completed plans with timestamp. Not used for new plans (see above). |
| `list-plans` tool | `~/.config/opencode/tools/` | Agent can list pending/completed plans programmatically |
| `stale-plans` tool | `~/.config/opencode/tools/` | Detects old, abandoned, or context-shifted plans |
| `/pending` command | `~/.config/opencode/commands/` | Type `/pending` to see, continue, or archive plans |
| `plan-flow` skill | `~/.config/opencode/skills/` | Instructions for plan format and workflow |
| Plan prompt | `~/.config/opencode/opencode.json` | Tells Plan mode to use bash heredoc to save plans + `question` tool for clarifications |
| Instructions | `~/.config/opencode/AGENTS.md` | Global fallback instructions with startup check |

> **Why bash heredoc?** OpenCode's TUI displays tool arguments inline. Passing the full plan content as a `write-plan` tool argument cluttered the main messages panel with raw structured text. Using `bash cat << 'EOF' > file` keeps the plan cleanly in the chat as formatted markdown while the file write happens silently via shell heredoc.

### Workflow

1. OpenCode starts — if you have pending plans, it greets you with a count and checks for stale/abandoned plans
2. Stale plans are flagged: old, context shifted, or may be done. Continue, archive, or review with `/pending`
3. Type `/pending` anytime to see what's waiting — pick a number to continue, or `archive <number>` to move an outdated plan to `completed/`
4. Give OpenCode a task
5. Plan mode analyzes, asks clarifying questions, outputs the plan as formatted markdown in the main messages panel, then saves it via `bash cat << 'EOF' > .agents/plans/pending/name.md`
6. Plan mode asks: **Implement?** (press Tab for Build) / **Edit?** / **Cancel?**
7. Build mode implements, archives plan to `.agents/plans/completed/`

---

## doc-it — AI-native documentation enforcement

Prevents AI doc rot and drift. Every execute task auto-updates docs.

> **Note:** doc-it is opt-in. Global install just puts the tools in place. You must run `install ./my-project` to activate the documentation pipeline in a project.

### Initialize a project

Tell the agent:

```
Install doc-it into this project from the URL.
```

Or run it yourself:

```bash
curl -fsSL https://raw.githubusercontent.com/innowesley/opencode-tools/main/install-doc-it.sh | bash -s -- install ./my-project
```

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
                    │ pending/stale│ ←── plan-it
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
                    │ analyze, ask,│ ←── plan-it
                    │ write plan   │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │ Build mode:  │
                    │ implement,   │
                    │ update docs, │ ←── plan-it + doc-it
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
