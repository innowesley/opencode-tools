# doc-it — Deep reference

## What it installs

| Component | Location | Purpose |
|-----------|----------|---------|
| `doc-drift-checker` | `.opencode/tools/` | Detects stale/missing docs from changed source |
| `changelog-generator` | `.opencode/tools/` | Creates changelog entries in docs/changelogs/ |
| `traceability-generator` | `.opencode/tools/` | Builds feature→files→routes→tables→tests→docs map |
| `ai-context-generator` | `.opencode/tools/` | Regenerates current-system-state.md + project-summary.md |
| `rule-violation-checker` | `.opencode/tools/` | Detects direct DB writes, undocumented routes, contract violations |
| docs/ | project root | Full docs tree (ai-context, architecture, features, database, api, contracts, future, etc.) |
| .ai/ | project root | Agent rules: execute pipeline, doc-rules, architecture-rules, testing-rules, completion-checklist |

## Execute pipeline

Every build task follows:

**LOAD CONTEXT** → **ANALYZE** → **CHECK DOCS** → **IMPLEMENT** → **UPDATE DOCS** → **CHANGELOG** → **TRACEABILITY** → **AI CONTEXT** → **CHECK VIOLATIONS** → **COMPLETE**

Tasks **FAIL** if any doc step is skipped.

## Getting started

1. Run `install ./my-project` — creates the docs tree and `.ai/` rules
2. AGENTS.md in your project is updated to include the doc-it pipeline
3. Every time Build mode completes a task, docs update automatically

## Commands

| Command | What it does |
|---------|-------------|
| `curl ... \| bash` | Global install (tools only) |
| `curl ... \| bash -s -- install ./my-project` | Initialize project with docs tree and pipeline |
| `curl ... \| bash -s -- uninstall` | Remove doc-it tools |
| `curl ... \| bash -s -- status` | Check installed files |

> **Note:** doc-it is opt-in. Global install just puts the tools in place. You must run `install ./my-project` to activate the pipeline.
