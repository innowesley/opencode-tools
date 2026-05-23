# opencode-tools

AI workflow tools for OpenCode.

**plan-it** — plan-first development.
**doc-it** — self-maintaining docs.

```bash
curl -fsSL https://raw.githubusercontent.com/innowesley/opencode-tools/main/install-plan-it.sh | bash
curl -fsSL https://raw.githubusercontent.com/innowesley/opencode-tools/main/install-doc-it.sh | bash
```

---

## Why?

AI coding tools lose context over time. Plans disappear. Docs drift. Architecture gets forgotten.

opencode-tools fixes this:
- **plan-it** forces planning before execution, tracks tasks, recovers stale plans
- **doc-it** keeps project documentation synchronized automatically

---

## Choose your workflow

### plan-it
Use for plan-first development with task tracking and pending plan recovery.

```
Tell the agent:

  Install this https://raw.githubusercontent.com/innowesley/opencode-tools/main/install-plan-it.sh

Or run:

  curl -fsSL https://raw.githubusercontent.com/innowesley/opencode-tools/main/install-plan-it.sh | bash
```

Into a specific project:

```
  curl -fsSL ...install-plan-it.sh | bash -s -- install ./my-project
```

### doc-it
Use for self-maintaining docs, AI project memory, and automatic changelogs.

```
Tell the agent:

  Install this https://raw.githubusercontent.com/innowesley/opencode-tools/main/install-doc-it.sh

Or run:

  curl -fsSL https://raw.githubusercontent.com/innowesley/opencode-tools/main/install-doc-it.sh | bash
```

Initialize a project with the full pipeline:

```
  curl -fsSL ...install-doc-it.sh | bash -s -- install ./my-project
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

---

## After install

**plan-it:**
- OpenCode starts checking for pending plans automatically
- Plan mode saves tasks and recovers stale ones

**doc-it:**
- `docs/` tree is created in your project
- Build mode updates docs and changelogs automatically

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

- [docs/plan-it.md](docs/plan-it.md) — components, workflow, commands, why bash heredoc
- [docs/doc-it.md](docs/doc-it.md) — components, pipeline, getting started

---

## Development

```bash
git clone git@github.com:innowesley/opencode-tools.git
```

Edit the install scripts or docs, then push. Users install from `main`.
