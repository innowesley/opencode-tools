# opencode-tools

AI workflow tools for OpenCode **and** Kilo CLI.

**plan-it** — plan-first development.
**doc-it** — self-maintaining docs.
**restrict-it** — bash command guardrails.

```bash
curl -fsSL https://raw.githubusercontent.com/innowesley/opencode-tools/main/plan-it | bash -s install kilo
curl -fsSL https://raw.githubusercontent.com/innowesley/opencode-tools/main/doc-it | bash -s install opencode
```

---

## Why?

AI coding tools lose context over time. Plans disappear. Docs drift. Architecture gets forgotten.

opencode-tools fixes this:
- **plan-it** forces planning before execution, tracks tasks, recovers stale plans
- **doc-it** keeps project documentation synchronized automatically
- **restrict-it** prevents dangerous commands from running unchecked

---

## Choose your workflow

### plan-it
Use for plan-first development with task tracking and pending plan recovery.

Tell the agent:
```
Install this https://raw.githubusercontent.com/innowesley/opencode-tools/main/plan-it
```

Or run:
```
curl -fsSL https://raw.githubusercontent.com/innowesley/opencode-tools/main/plan-it | bash -s install kilo
curl -fsSL https://raw.githubusercontent.com/innowesley/opencode-tools/main/plan-it | bash -s install opencode
```

### doc-it
Use for self-maintaining docs, AI project memory, and automatic changelogs.

```
curl -fsSL https://raw.githubusercontent.com/innowesley/opencode-tools/main/doc-it | bash -s install kilo
curl -fsSL https://raw.githubusercontent.com/innowesley/opencode-tools/main/doc-it | bash -s install opencode ./my-project
```

### restrict-it
Use to require approval for dangerous commands (rm -rf, git push, sudo, etc.).

```
curl -fsSL https://raw.githubusercontent.com/innowesley/opencode-tools/main/restrict-it | bash -s enable kilo
curl -fsSL https://raw.githubusercontent.com/innowesley/opencode-tools/main/restrict-it | bash -s enable opencode
```

### Both (recommended for larger AI-native projects)
Install plan-it globally, then run doc-it's project init in your working directory. Both tools work together — plan-it manages the task lifecycle, doc-it keeps docs fresh.

---

## Example

**User:** "Add Stripe refunds"

**plan-it:**
- analyzes the task
- writes an implementation plan
- asks for confirmation

**doc-it:**
- updates payment docs
- creates a changelog
- refreshes AI project memory
- updates the traceability map

**restrict-it:**
- requires approval before `git push` or `npm publish`

---

## After install

**plan-it:**
- Agent starts checking for pending plans automatically
- Plan mode saves tasks and recovers stale ones

**doc-it:**
- `docs/` tree is created in your project
- Build mode updates docs and changelogs automatically

**restrict-it:**
- Dangerous commands require approval before execution

---

## Combined workflow

```
Task
 ↓
Plan (plan-it)
 ↓
Implement
 ↓
Docs update automatically (doc-it)
 ↓
Project memory stays current
```

---

## Deep reference

- [docs/plan-it.md](docs/plan-it.md) — components, workflow, commands
- [docs/doc-it.md](docs/doc-it.md) — components, pipeline, getting started

---

## Development

```bash
git clone git@github.com:innowesley/opencode-tools.git
```

Edit the scripts or docs, then push. Users install from `main`.
