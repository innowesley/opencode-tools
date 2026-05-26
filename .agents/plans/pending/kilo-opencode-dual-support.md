# Plan: Unified install scripts for Kilo + Opencode

## Goal
A single set of install scripts (`install-plan-it`, `install-doc-it`, `install-restrictions`) that detect whether the user has **Kilo** or **Opencode** CLI and installs the appropriate version — including protocol, permissions, AND plugin tools — for **all three tools**.

---

## Step 1: Detection Logic (shared by all 3 scripts)

```bash
detect_cli() {
  if command -v kilo &>/dev/null; then
    echo "kilo"
  elif command -v opencode &>/dev/null; then
    echo "opencode"
  else
    echo "none"
  fi
}
CLI_MODE=$(detect_cli)
```

Priority: Kilo first (if both exist, Kilo wins — it's the newer fork).

---

## Step 2: Opencode Path (existing, unchanged for all 3)

```
CLI_MODE=opencode
  ├─ install-plan-it
  │   ├─ .ts tools → ~/.config/opencode/tools/ (list-plans, related-plans, stale-plans)
  │   ├─ config → ~/.config/opencode/opencode.json (agent.plan.permission.*)
  │   ├─ AGENTS.md → Plan-First Protocol with .agents/plans/ paths
  │   └─ commands/ → ~/.config/opencode/commands/pending.md
  │
  ├─ install-doc-it
  │   ├─ .ts tools → ~/.config/opencode/tools/ (doc-drift-checker, changelog-generator, etc.)
  │   ├─ docs/ tree → project
  │   └─ AGENTS.md → appended with doc pipeline
  │
  └─ install-restrictions
      └─ modify opencode.json → agent.plan.permission.bash
```

No changes to current behavior.

---

## Step 3: Version Resolution for Kilo Plugins

### Key finding
The installed `@kilocode/plugin` at `~/.config/kilo/node_modules/@kilocode/plugin/` is **v7.1.13** (same across all Kilo configs). The Kilo binary itself is v7.2.40 — the binary and plugin version are **independent**.

### How the script handles it

When the script creates the Kilo plugin at `~/.config/kilo/node_modules/@opencode-tools/kilo-plugin/`, the `package.json` depends on `@kilocode/plugin`. Since the parent `node_modules/` already has `@kilocode/plugin@7.1.13` installed, npm's module resolution will find and use it automatically.

The script will **read the installed version** for display, but **doesn't need to pin it**:

```bash
# Read the installed @kilocode/plugin version (for info/logging)
KILO_PLUGIN_VERSION=$(cat ~/.config/kilo/node_modules/@kilocode/plugin/package.json \
  | grep '"version"' | head -1 | sed 's/.*: "*\([^"]*\)".*/\1/')
msg "Detected @kilocode/plugin v${KILO_PLUGIN_VERSION}"
```

The plugin's `package.json` uses a **broad version range** so npm resolves to whatever is already installed:

```json
{
  "dependencies": {
    "@kilocode/plugin": ">=7.1.0"
  }
}
```

Resolution order when `npm install` runs inside the plugin directory:
1. Check `~/.config/kilo/node_modules/@kilocode/plugin/` → found v7.1.13 → **use it**
2. (No need to download anything)

---

## Step 4: Kilo Path — Creating the Plugin Module

### 4a. Location: `~/.config/kilo/node_modules/@opencode-tools/kilo-plugin/`

Directly in the existing `node_modules` tree so dependencies resolve automatically.

### 4b. `package.json`

```json
{
  "name": "@opencode-tools/kilo-plugin",
  "version": "1.0.0",
  "type": "module",
  "exports": {
    "./plan-it": "./dist/plan-it.js",
    "./doc-it": "./dist/doc-it.js"
  },
  "dependencies": {
    "@kilocode/plugin": ">=7.1.0"
  }
}
```

### 4c. Plugin file: `dist/plan-it.js`

Uses the **verified** Kilo plugin API (from `@kilocode/plugin/dist/example.js`):

```javascript
import { tool } from "@kilocode/plugin";

export const PlanItPlugin = async (ctx) => {
  return {
    tool: {
      "list-plans": tool({
        description: "List plan files by status (drafts, pending, active, completed)",
        args: {
          status: tool.schema.enum(["drafts", "pending", "active", "completed"])
            .default("active"),
        },
        async execute(args, context) {
          const base = (context.worktree && context.worktree !== '/')
            ? context.worktree : context.directory;
          // Check .kilo/plans/ directories instead of .agents/plans/
          const STATUS_DIRS = {
            drafts: [".kilo/plans"],
            pending: [".kilo/plans/pending"],
            active: [".kilo/plans", ".kilo/plans/pending"],
            completed: [".kilo/plans/completed"],
          };
          const dirs = STATUS_DIRS[args.status];
          const plans = await Promise.all(dirs.map(d => readPlans(base, d)));
          const unique = [...new Set(plans.flat())];
          return JSON.stringify({ count: unique.length, plans: unique, status: args.status });
        },
      }),
      "related-plans": tool({
        description: "Find plans related by topic keywords (filename + first heading overlap)",
        args: {
          planName: tool.schema.string().describe("Plan filename (without .md)"),
        },
        async execute(args, context) {
          const base = (context.worktree && context.worktree !== '/')
            ? context.worktree : context.directory;
          // Same logic as opencode related-plans.ts but .kilo/plans/ paths
          // ...
        },
      }),
      "stale-plans": tool({
        description: "Check pending plans for staleness",
        args: {
          maxAgeDays: tool.schema.number().default(7),
        },
        async execute(args, context) {
          // Same logic as opencode stale-plans.ts but .kilo/plans/ paths
          // ...
        },
      }),
    }
  };
};
```

### 4d. Plugin file: `dist/doc-it.js`

```javascript
import { tool } from "@kilocode/plugin";

export const DocItPlugin = async (ctx) => {
  return {
    tool: {
      "doc-drift-checker": tool({
        description: "Check for stale/missing docs by scanning source + cross-referencing docs/",
        args: { changedFiles: tool.schema.string().optional() },
        async execute(args, context) {
          const base = (context.worktree && context.worktree !== '/')
            ? context.worktree : context.directory;
          // Same logic as opencode doc-drift-checker.ts
          // Uses context.directory / context.worktree
        },
      }),
      "changelog-generator": tool({
        description: "Create a changelog entry in docs/changelogs/",
        args: {
          title: tool.schema.string(),
          changes: tool.schema.string(),
          breaking: tool.schema.string().optional(),
          features: tool.schema.string().optional(),
        },
        async execute(args, context) {
          // Same logic as opencode changelog-generator.ts
        },
      }),
      "traceability-generator": tool({
        description: "Build feature→files→routes→tests→docs traceability map",
        args: {},
        async execute(args, context) {
          // Same logic as opencode traceability-generator.ts
        },
      }),
      "ai-context-generator": tool({
        description: "Regenerate ai-context docs from project docs tree",
        args: {},
        async execute(args, context) {
          // Same logic as opencode ai-context-generator.ts
        },
      }),
      "rule-violation-checker": tool({
        description: "Detect rule violations in source code",
        args: { sourceDirs: tool.schema.string().default("src,app") },
        async execute(args, context) {
          // Same logic as opencode rule-violation-checker.ts
        },
      }),
    }
  };
};
```

---

## Step 5: Kilo install-plan-it

```bash
# Detect CLI
CLI_MODE=$(detect_cli)

if [ "$CLI_MODE" = "kilo" ]; then
  # Read installed plugin version for logging
  KILO_PLUGIN_VER=$(cat ~/.config/kilo/node_modules/@kilocode/plugin/package.json \
    | grep '"version"' | head -1 | sed 's/.*: "*\([^"]*\)".*/\1/')
  msg "Detected Kilo (binary v$(kilo --version)) with @kilocode/plugin v${KILO_PLUGIN_VER}"

  # Create plugin directory
  PLUGIN_DIR="$HOME/.config/kilo/node_modules/@opencode-tools/kilo-plugin"
  mkdir -p "$PLUGIN_DIR/dist"

  # Write package.json
  cat > "$PLUGIN_DIR/package.json" << 'PKGEOF'
  {
    "name": "@opencode-tools/kilo-plugin",
    "version": "1.0.0",
    "type": "module",
    "exports": {
      "./plan-it": "./dist/plan-it.js"
    },
    "dependencies": {
      "@kilocode/plugin": ">=7.1.0"
    }
  }
PKGEOF

  # Write plan-it.js
  cat > "$PLUGIN_DIR/dist/plan-it.js" << 'TOOLEOF'
  // ... (plugin code from Step 4c)
TOOLEOF

  # npm install (resolves @kilocode/plugin from parent node_modules)
  cd "$PLUGIN_DIR" && npm install --no-audit --no-fund --loglevel=error && cd ~

  # Register plugin in kilo.jsonc
  # (Backup original, inject plugin array)
  cp "$HOME/.config/kilo/kilo.jsonc" "$HOME/.config/kilo/kilo.jsonc.bak"
  # ... (JSONC-safe injection)

  # Create plan directories
  mkdir -p ".kilo/plans/pending" ".kilo/plans/completed"

  # Write AGENTS.md with .kilo/plans/ paths
  write_kilo_agents_md

  msg "Kilo plan-it installed! Plugin: @opencode-tools/kilo-plugin"
fi
```

---

## Step 6: Kilo install-doc-it

Same pattern — writes `doc-it.js` into the same plugin module, then creates docs/ tree.

```bash
if [ "$CLI_MODE" = "kilo" ]; then
  # Add doc-it.js to existing plugin module
  cat > "$PLUGIN_DIR/dist/doc-it.js" << 'TOOLEOF'
  // ... (plugin code from Step 4d)
TOOLEOF

  # Create docs tree in current project
  mkdir -p docs/ai-context docs/features docs/architecture ...

  # Write doc templates (same content as opencode version)
  write_kilo_docs

  # Append doc pipeline to AGENTS.md
  append_kilo_doc_pipeline
fi
```

---

## Step 7: Kilo install-restrictions

```bash
detect_cli()
  ├─ "kilo" → modify ~/.config/kilo/kilo.jsonc
  │   └─ Add to "permission.bash" section:
  │      "git push*": "ask",
  │      "git merge*": "ask",
  │      "sudo*": "ask",
  │      "npm publish*": "ask",
  │      "rm -rf*": "ask",
  │      ...
  │
  └─ "opencode" → modify ~/.config/opencode/opencode.json (current behavior)
      └─ Add to "agent.plan.permission.bash" section
```

**JSONC handling:** `kilo.jsonc` has comments, so `jq` won't work. Instead, write a complete `kilo.jsonc` with merged permissions (backup original first).

---

## Step 8: Kilo AGENTS.md

```markdown
## 📋 Plan-First Protocol

On ANY task:
1. Create plan → `.kilo/plans/<task>.md`
2. Return plan to user
3. STOP – do NOT execute

Execute ONLY after: "execute", "proceed", "continue", or explicit approval.

Note: The `write` tool is permitted for `.kilo/plans/**/*.md` in Plan mode.

## ✅ Execution Rules

After user approves:
1. `mv .kilo/plans/<task>.md .kilo/plans/pending/<task>.md`
2. Execute the plan, updating `.kilo/plans/pending/<task>.md`
3. Mark steps [x] as completed
4. Append progress logs

On completion:
1. `mv .kilo/plans/pending/<task>.md .kilo/plans/completed/<task>.md`
2. Return result + next-step plan
```

For doc-it, append the doc pipeline.

---

## Risks & Mitigations

| # | Risk | Mitigation |
|---|------|------------|
| 1 | **Plugin loading**: Kilo binary might not load plugins from `plugin` array in config | Test after install with `kilo run --pure "list plans"`. Fallback: rely on AGENTS.md protocol (the essential part) — agent manages plans via bash |
| 2 | **JSONC config editing**: `kilo.jsonc` has comments, can't use `jq` | Write template + backup original. Use `node -e` with JSON5 parser if needed |
| 3 | **`@kilocode/plugin` version mismatch**: Plugin's dependency might not match Kilo's | npm resolves from parent `node_modules/`. We log the detected version at install time |
| 4 | **`ask()` return type**: Might be `Effect<void>` on newer `@kilocode/plugin` versions | Match our plugin to the version that's installed. v7.1.13 uses `Promise<void>` |

---

## Verification Steps

1. Run both scripts, verify detection works
2. Check `~/.config/kilo/node_modules/@opencode-tools/kilo-plugin/` exists
3. Check `npm install` resolves `@kilocode/plugin` without downloading
4. Check `kilo.jsonc` has `"plugin"` array added
5. Run `kilo run --pure "list plans"` to test if plugin is loaded
6. If step 5 fails: AGENTS.md protocol still works as fallback

---

## Summary: What Gets Installed Where

| Tool | Opencode (`~/.config/opencode/`) | Kilo (`~/.config/kilo/`) |
|------|----------------------------------|--------------------------|
| **plan-it** | `tools/list-plans.ts`, `tools/related-plans.ts`, `tools/stale-plans.ts`, `opencode.json`, `AGENTS.md` | `node_modules/@opencode-tools/kilo-plugin/dist/plan-it.js`, `kilo.jsonc["plugin"]`, `kilo.jsonc["permission"]`, `AGENTS.md` |
| **doc-it** | `tools/doc-drift-checker.ts`, `tools/changelog-generator.ts`, `tools/traceability-generator.ts`, `tools/ai-context-generator.ts`, `tools/rule-violation-checker.ts`, `docs/` tree | `node_modules/@opencode-tools/kilo-plugin/dist/doc-it.js`, `docs/` tree |
| **install-restrictions** | `opencode.json["agent.plan.permission.bash"]` | `kilo.jsonc["permission.bash"]` |
