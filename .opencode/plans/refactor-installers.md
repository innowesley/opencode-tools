# Refactor Installers — Context Preservation Plan

## Goal
Refactor two shell-based installer scripts (`doc-it` and `plan-it`) from destructive scaffolders into lifecycle-aware, idempotent, ownership-driven package-management tooling for an LLM-assisted engineering platform (`opencode-tools`).

## Key Design Decisions
- **Ownership model**: `generated` (always overwrite), `seed` (write-if-missing), `managed` (replace via sentinel/merge), `user` (never touch).
- **AGENTS.md sentinel blocks**: `<!-- BEGIN ... MANAGED BLOCK -->` / `<!-- END ... MANAGED BLOCK -->`, manipulated via `replace_managed_block` / `remove_managed_block`.
- **JSON deep-merge**: Per-path rules via `MANAGED_JSON_RULES`; `agent.plan.prompt` is a managed leaf with inline sentinel blocks.
- **Prompt sentinels**: Manipulated via `replace_managed_block_in_string`, not raw JSON string replacement.
- **`safe_cp_tool`**: Compares `source-version` headers; hash-based guard is a known gap.
- **Uninstall**: Manifest-tracked files only; plan directories checked for non-.md content before removal.
- **`install <cli> <project>`**: Deprecated in favor of `init <cli> <project>`.

## Files
| File | Lines | Role |
|------|-------|------|
| `_lib.sh` | 411 | Shared library |
| `plan-it` | 1240 | Plan-it installer |
| `doc-it` | 1614 | Doc-it installer |
| `install-plan-it` | symlink | → plan-it |
| `install-doc-it` | symlink | → doc-it |

## Completed
- Phase 0 — `_lib.sh` shared library
- Phase 1 — `plan-it` rewrite (deep-merge, sentinels, doctor, manifest)
- Phase 1 — `doc-it` rewrite (ownership split, generated/seed separation, Kilo plugin)
- Verification: both scripts pass `bash -n`; init is idempotent
- Fix P0 #1 — `plan-it:55-74`: Reordered prompt temp file write before Node read
- Fix P0 #2 — `plan-it:973`: Added missing `require('fs')` in doctor JSON parse
- Fix P0 #3 — `doc-it:866,874`: Replaced `msg()` with `console.log()` inside Node `-e` context
- Fix P0 #3 extended — `plan-it:675,677,685`: Same `msg()`→`console.log()` fix in plan-it Kilo JSONC section
- Fix P1 #4 — `plan-it:771-784`: Changed uninstall from heuristic to safe empty-dir-only removal; user `.md` plans preserved
- Fix P1 #5 — `_lib.sh:259-290`: `safe_cp_tool` now checks sha256 before overwrite; if sha differs and version not newer, treats as user-modified and skips
- Fix P2 #6 — `_lib.sh:125`: Added `escapeRegex()` function in `replace_managed_block_in_string` Node script to escape sentinel markers
- Fix P2 #7 — `_lib.sh:137-176`: Replaced `validate_sentinels` depth-only tracking with real identity stack (tracks begin/end pairing)
- Fix P2 #8 — `plan-it:662-687`, `doc-it:853-876`: Replaced regex-based Kilo JSONC mutation with comment-stripping + `JSON.parse` + targeted replacement; also passing paths via `process.argv` and fixing `msg()`→`console.log()`
- Fix P2 #9 — `_lib.sh:386-391`: Replaced `ls -A` with nullglob+dotglob check in `safe_rmdir`
- Fix P2 #10 — `_lib.sh:393-403`: Replaced unquoted `ls -t $pattern` with nullglob array expansion + quoted `ls -t` in `prune_backups`
- Fix P2 #11 — `_lib.sh:182-223,329-380`: Refactored `merge_json_config`, `manifest_add`, `manifest_remove` to pass all paths via `process.argv` instead of shell interpolation into Node `-e` source
- Fix P2 #12 — `doc-it:781,1174`: Improved route detection regex to handle chained routers (`.route('/path').get(...)`)
- Fix P3 #13 — `doc-it:59,1261`: Replaced word-splitting `mkdir -p $dir/$DOCS_TREE` with brace expansion `mkdir -p "$dir/docs/$DOCS_TREE_BRACE"`
- Fix P3 #14 — `doc-it:624-627,1010-1013`: Replaced single-line YAML regex with multi-line YAML parser (`parseYamlList`) supporting indented lists
- Fix P3 #15 — `doc-it:557,1139`: Replaced `readdir(dir, { recursive: true })` with manual recursive `walk()` for Node <20.5 compatibility
- Fix P3 #16 — `doc-it:882`, `plan-it:654`: Wrapped `npm install` in subshell; removed `2>/dev/null` and `|| true` error swallowing
- Fix P3 #17 — set -euo pipefail consistency: `cd` in subshell (fixed), glob loops already guarded with `[ -f "$f" ] || continue`

## Status

### ✅ Fixed
All 17 bugs (#1–#17) resolved. See Completed section above for details.

### ✅ Fixed
- **#18 — Kilo plugin deduplication**: Extracted shared core module (`doc-it-core.js`) with all tool logic. Opencode tools are now ~15-line thin wrappers. Kilo plugin is ~65-line thin wrapper. All 5 tools' logic lives in one place.
- **Structural — Template heredocs**: No longer needed — thin wrappers are already minimal.
- **Structural — Uninstall safety**: sha256 guard added to `safe_cp_tool` (Fix #5).
