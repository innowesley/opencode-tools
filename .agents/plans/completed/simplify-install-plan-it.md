# Plan: 100% plan enforcement — protocol in AGENTS.md, write-permission in config, tools as backup

## Goal
Rewrite `install-plan-it.sh` so the plan-first workflow is enforced **100%** — surviving any project-level config override.

## Three-layer enforcement

### Layer 1: Global AGENTS.md (`~/.config/opencode/AGENTS.md`)
Always combined with project AGENTS.md, never removable. Contains the Plan-First Protocol.

### Layer 2: Global opencode.json (`~/.config/opencode/opencode.json`)
```json
{
  "agent": {
    "plan": {
      "permission": {
        "write": {
          ".agents/plans/**/*.md": "allow",
          "*": "deny"
        }
      },
      "prompt": "You are in Plan mode. Follow the Plan-First Protocol in AGENTS.md. You ARE allowed to use the `write` tool for plan files in .agents/plans/ — permission is granted. Use `write` for plan files, not bash heredocs. Never execute implementation steps."
    }
  }
}
```
Key: the `permission.write` glob tells OpenCode "allow write only for plan files".  
The prompt tells the model this is OK.

### Layer 3: Managed config (`/etc/opencode/opencode.json`)
Optional (root-only). Same config, truly unoverridable.

### Backup tools (survive via per-key merge)
- `write-plan.ts` — fallback if model still hesitates to use `write`
- `list-plans.ts` — list pending plans
- `stale-plans.ts` — check for stale plans

## What the installer creates

| File | Content |
|------|---------|
| `~/.config/opencode/AGENTS.md` | Plan-First Protocol (user's version) |
| `~/.config/opencode/opencode.json` | Config with `agent.plan.permission` + `agent.plan.prompt` |
| `~/.config/opencode/tools/write-plan.ts` | Backup tool for saving plans |
| `~/.config/opencode/tools/list-plans.ts` | List tool |
| `~/.config/opencode/tools/stale-plans.ts` | Stale check tool |
| `.agents/plans/pending/` | Directory |
| `.agents/plans/completed/` | Directory |

Note: `./opencode.json` per-project copy no longer needed — the global config with AGENTS.md combined with project ensures the protocol always appears.

## Installer changes
- Remove opencode.json project copies, SKILL.md, pending command
- Simplify to single install mode
- Keep tools, AGENTS.md, global opencode.json config
- Add option to install managed config at /etc/opencode/ (sudo)

## The guarantee
1. ✅ AGENTS.md protocol always in prompt (combined semantics)
2. ✅ Permission allows `write` for plan files only
3. ✅ Prompt tells model to use `write`
4. ✅ Tools as backup if model still avoids `write`
5. ✅ Managed config at /etc/ for root users (truly unoverridable)
