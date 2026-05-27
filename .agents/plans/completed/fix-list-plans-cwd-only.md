# Fix: Use CWD only for all tools + fix Kilo naming

## Problem 1: `context.worktree` resolves to git root, not CWD

In monorepo setups (e.g., `~/projects/` is a git root, `~/projects/shishaKe/` is a subproject), all tools resolve paths via `context.worktree` (git root) instead of `context.directory` (CWD). This causes:
- Plans read from wrong directory (parent repo's `.agents/plans/pending/`)
- `mv .kilo/plans/... .agents/plans/...` fails because the `mv` runs relative to CWD but `list-plans` reads from git root

## Problem 2: Kilo uses generic plan names

Kilo agent generates names like `1779914971089-proud-wizard` instead of descriptive names like `fix-list-plans-cwd-only`. The prompt says "use **descriptive names**" but Kilo doesn't follow it.

## Fix 1: Replace `context.worktree` → `context.directory` (16 instances total)

### `plan-it` — 6 replacements (lines 177, 238, 381, 624, 638, 673)

All change from:
```typescript
const base = (context.worktree && context.worktree !== '/') ? context.worktree : context.directory
```
to:
```typescript
const base = context.directory
```

### `doc-it` — 10 replacements (lines 741, 762, 778, 794, 810, 1173, 1186, 1194, 1202, 1210)

Same change as above.

## Fix 2: Strengthen Kilo naming instruction

In `plan-it` Kilo AGENTS.md block (line 734), change:
```
1. Create plan → `.kilo/plans/<task>.md` (use **descriptive names**)
```
to:
```
1. Create plan → `.kilo/plans/<task>.md` (MUST use lowercase-kebab-case descriptive names like `fix-auth-timeout` — NEVER use timestamps, UUIDs, or generic names like `task-1`)
```

## Risk Assessment
- **Low risk**: `context.directory` is the CWD, which is what the user is actually working in
- **Backward compatible**: For non-monorepo repos (where git root == CWD), behavior is identical
- **Monorepo fix**: Projects inside subdirectories now correctly resolve to their own plan directories
