# Fix: project-level tools fail with `Cannot find module '@opencode-ai/plugin'`

## Problem
When opencode loads tools from a project's `.opencode/tools/`, two things are missing:

1. **`@opencode-ai/plugin` dependency** — tools import `{ tool } from "@opencode-ai/plugin"` but there's no `node_modules/@opencode-ai/plugin` in the project tools directory.
2. **`doc-it-core.js`** — tools have relative imports like `import { checkDocDrift } from "./doc-it-core.js"` but only `.ts` files are copied, the `.js` core is left behind.

The global tools in `~/.config/opencode/tools/` work fine because:
- `@opencode-ai/plugin` exists at `~/.config/opencode/node_modules/@opencode-ai/plugin/`
- `doc-it-core.js` is in the same directory

## Fix (Option B)
In `doc-it`'s `init_project()` function (line ~1305-1310), after copying `.ts` tools:

1. **Copy `doc-it-core.js`** to the project tools directory
2. **Create `node_modules/@opencode-ai/plugin` symlink** pointing to the global install

### File to modify
`/home/kunta/apps/opencode-tools/doc-it`, function `init_project()`, lines 1305-1310.

### Current code
```bash
if [ -d "$OPCODE_CONFIG_DIR/tools" ]; then
  for f in "$OPCODE_CONFIG_DIR/tools"/*.ts; do
    [ -f "$f" ] || continue
    safe_cp_tool "$f" "$dir/.opencode/tools/$(basename "$f")"
  done
fi
```

### New code
```bash
if [ -d "$OPCODE_CONFIG_DIR/tools" ]; then
  for f in "$OPCODE_CONFIG_DIR/tools"/*.ts "$OPCODE_CONFIG_DIR/tools/doc-it-core.js"; do
    [ -f "$f" ] || continue
    safe_cp_tool "$f" "$dir/.opencode/tools/$(basename "$f")"
  done
fi

# Create symlink for @opencode-ai/plugin so module resolution works
mkdir -p "$dir/.opencode/tools/node_modules/@opencode-ai"
if [ -d "$OPCODE_CONFIG_DIR/node_modules/@opencode-ai/plugin" ]; then
  ln -sfn "$OPCODE_CONFIG_DIR/node_modules/@opencode-ai/plugin" \
    "$dir/.opencode/tools/node_modules/@opencode-ai/plugin"
fi
```

Also copy `doc-it-core.js` on Kilo init (it doesn't have the `.ts` tools copy loop, but for consistency with the global Kilo plugin approach, this should be fine — the Kilo plugin bundles everything in one file).

## Verification
- Run `bash -n doc-it` — syntax check
- Re-init a project: `curl ... | bash -s init opencode .` (on a test project)
- Confirm `ls .opencode/tools/node_modules/@opencode-ai/plugin/` exists
- Confirm opencode agent can load tools without `Cannot find module` error

## Risk Assessment
- **Low risk**: symlink is created only when the global install exists
- **Backward compatible**: existing project dirs won't be affected unless re-initialized
- **No breaking changes**: tools continue to work globally as before
- **Rollback**: remove the symlink + `doc-it-core.js` from the project tools dir
