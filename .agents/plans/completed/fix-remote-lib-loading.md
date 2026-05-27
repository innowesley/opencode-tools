# Fix: Remote Pipe Loading of `_lib.sh`

## Problem
When user runs:
```bash
curl -fsSL https://raw.githubusercontent.com/innowesley/opencode-tools/main/plan-it | bash -s install opencode
```
`$0` = `bash`, so `SCRIPT_DIR` is wrong, and `source "$SCRIPT_DIR/_lib.sh"` fails.

Affected files: `plan-it`, `doc-it` (both line 5).

## Solution
Replace static `source "$SCRIPT_DIR/_lib.sh"` with dynamic fallback that fetches from GitHub when local file is missing.

## Changes

### `plan-it` lines 4-5 → dynamic sourcing
### `doc-it` lines 4-5 → dynamic sourcing

## Risk Assessment
- **Low risk**: local execution unchanged, remote pipe gets fallback fetch
- **Backward compatible**: same functions/variables loaded either way
- **Self-cleaning**: temp file removed after source
