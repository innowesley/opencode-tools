# Two-Stage Plan Workflow: `.opencode/plans/` → `.agents/plans/`

**Goal:** Update `install-plan-it.sh` to implement a two-stage plan lifecycle:
1. Agent creates plan → **`.opencode/plans/<task>.md`**
2. User approves → **`mv` to `.agents/plans/pending/<task>.md`**
3. Agent executes & updates file in `.agents/plans/pending/`
4. On completion → **`mv` to `.agents/plans/completed/`**

---

## ⚠️ Critical Rule: NEVER use `cp`

All transitions between stages **MUST use `mv` (move)**. Using `cp` would leave stale copies in `.opencode/plans/` or `.agents/plans/pending/`, breaking the single-source-of-truth invariant. The plan file must exist in exactly **one** location at any given time.

- ❌ `cp .opencode/plans/x.md .agents/plans/pending/x.md` ← **FORBIDDEN**
- ✅ `mv .opencode/plans/x.md .agents/plans/pending/x.md` ← **CORRECT**
- ✅ `mv .agents/plans/pending/x.md .agents/plans/completed/x.md` ← **CORRECT**

---

## Files to Modify

All changes are in [`install-plan-it.sh`](/home/kunta/projects/opencode-tools/install-plan-it.sh) (the single source of truth that generates all config files).

### 1. `opencode.json` (lines 23-37) — Write Permissions

**Current:**
```json
"permission": {
  "write": {
    ".agents/plans/**/*.md": "allow"
  }
}
```

**Change to:**
```json
"permission": {
  "write": {
    ".opencode/plans/**/*.md": "allow",
    ".agents/plans/**/*.md": "allow"
  }
}
```

Also update the prompt text to instruct the agent on the two-stage workflow.

### 2. `AGENTS.md` (lines 39-61) — Full Workflow Update

**Current** (single-stage):
```
1. Create plan → `.agents/plans/pending/<task>.md`
2. Return to user → STOP
After approval: execute, update file
On completion: mv to `.agents/plans/completed/`
```

**Change to** (two-stage):
```
1. Create plan → `.opencode/plans/<task>.md`
2. Return to user → STOP

After approval:
  1. mv .opencode/plans/<task>.md .agents/plans/pending/<task>.md
  2. Execute, update .agents/plans/pending/<task>.md
  3. Mark steps [x], append logs

On completion:
  1. mv .agents/plans/pending/<task>.md .agents/plans/completed/<task>.md
  2. Return result + next-step plan
```

### 3. `pending.md` command (lines 268-308) — Dual Listing

**Current:** Lists only `.agents/plans/pending/`.

**Change to:**
- List **drafts** from `.opencode/plans/` (not yet approved)
- List **in-progress** from `.agents/plans/pending/` (approved, being worked on)
- "archive" should move from `.agents/plans/pending/` to `.agents/plans/completed/`

### 4. Tools — Add `.opencode/plans/` Scanning

| Tool | Change |
|------|--------|
| `list-plans.ts` | Add `"drafts"` status that scans `.opencode/plans/` |
| `related-plans.ts` | Also scan `.opencode/plans/` for draft plans |
| `stale-plans.ts` | Also check `.opencode/plans/` for stale drafts |

### 5. `mkdir` line (line 21) — Per-Project Directory Creation

**Current:** Creates `$HOME/.agents/plans/pending` and `$HOME/.agents/plans/completed`.

**Change to:** Keep those, and add comment that `.opencode/plans/` is per-project (created by agent at write time via the permission rule).

---

## Implementation Steps

- [x] Research current install-plan-it.sh structure
- [x] Identify all references to `.agents/plans/` in AGENTS.md, opencode.json, commands, and tools
- [x] **Step 1:** Edit `opencode.json` heredoc — added `.opencode/plans/**/*.md` write permission; updated prompt
- [x] **Step 2:** Edit `AGENTS.md` heredoc — rewrote workflow for two-stage lifecycle
- [x] **Step 3:** Edit `pending.md` command heredoc — added drafts listing from `.opencode/plans/`
- [x] **Step 4:** Edit `list-plans.ts` heredoc — added `"drafts"` status enum
- [x] **Step 5:** Edit `related-plans.ts` heredoc — added `.opencode/plans/` scanning
- [x] **Step 6:** Edit `stale-plans.ts` heredoc — added `.opencode/plans/` scanning
- [x] **Step 7:** Update `mkdir` line — added comment about `.opencode/plans/` being per-project
- [x] **Verify:** Syntax check passed (`bash -n install-plan-it.sh` ✅)

---

## Progress Log

- **2026-05-26 02:00:** Plan created by user request
- **2026-05-26 02:00:** User clarified `mv` only, never `cp`
- **2026-05-26 02:00:** Execution approved (`ok`)
- **2026-05-26 02:01:** All 7 steps implemented + verified
- **2026-05-26 02:01:** `bash -n install-plan-it.sh` ✅ syntax clean
- **2026-05-26 02:01:** Plan moved to `.agents/plans/completed/`

---

## Verification

After changes, run `bash install-plan-it.sh install` and verify:
- `opencode.json` has both permission paths
- `AGENTS.md` describes two-stage workflow
- `commands/pending.md` lists both `.opencode/plans/` and `.agents/plans/pending/`
- Tools compile/parse correctly
