# doc-it — Deep reference

## What it installs

### Opencode variant (`doc-it install opencode`)

| Component | Location | Purpose |
|-----------|----------|---------|
| `doc-drift-checker` | `~/.config/opencode/tools/` | Detects stale/missing docs from changed source |
| `changelog-generator` | `~/.config/opencode/tools/` | Creates changelog entries in docs/changelogs/ |
| `traceability-generator` | `~/.config/opencode/tools/` | Builds feature→files→routes→tables→tests→docs map |
| `ai-context-generator` | `~/.config/opencode/tools/` | Regenerates current-system-state.md + project-summary.md |
| `rule-violation-checker` | `~/.config/opencode/tools/` | Detects direct DB writes, undocumented routes, contract violations |

### Kilo variant (`doc-it install kilo`)

| Component | Location | Purpose |
|-----------|----------|---------|
| `doc-drift-checker` | `@opencode-tools/kilo-plugin` (Kilo plugin) | Same tools, registered as a Kilo plugin |
| `changelog-generator` | `@opencode-tools/kilo-plugin` | Creates changelog entries |
| `traceability-generator` | `@opencode-tools/kilo-plugin` | Builds traceability map |
| `ai-context-generator` | `@opencode-tools/kilo-plugin` | Regenerates AI context docs |
| `rule-violation-checker` | `@opencode-tools/kilo-plugin` | Detects rule violations |

### Project-level (both variants)

| Component | Location | Purpose |
|-----------|----------|---------|
| docs/ | project root | Full docs tree (ai-context, architecture, features, database, api, contracts, future, etc.) |
| .ai/ | project root | Agent rules: execute pipeline, doc-rules, architecture-rules, testing-rules, completion-checklist |

## Execute pipeline

Every build task follows:

**LOAD CONTEXT** → **ANALYZE** → **CHECK DOCS** → **IMPLEMENT** → **UPDATE DOCS** → **CHANGELOG** → **TRACEABILITY** → **AI CONTEXT** → **CHECK VIOLATIONS** → **COMPLETE**

Tasks **FAIL** if any doc step is skipped.

## Getting started

1. `doc-it install opencode` — install tools globally
2. `doc-it install opencode ./my-project` — install + create docs tree and pipeline
3. AGENTS.md in your project is updated to include the doc-it pipeline
4. Every time Build mode completes a task, docs update automatically

## Commands

```
doc-it install <cli>                Install doc-it tools (kilo|opencode)
doc-it install <cli> <project>      Install + initialize project
doc-it uninstall <cli>              Remove doc-it tools (kilo|opencode)
doc-it status [<cli>]               Show installed components (kilo|opencode|all)
doc-it help                         Show usage
```

Aliases: `add` = `install`, `rm` = `uninstall`

> **Note:** doc-it is opt-in. Global install just puts the tools in place. You must run `install <cli> ./my-project` to activate the pipeline.
