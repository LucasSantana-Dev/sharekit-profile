---
name: handoff
description: Capture active work state before budget runs low, switching projects, or ending session. Write durable resume packet to `~/.claude/handoffs/<project>/latest.md` for next session to continue without rediscovery.
metadata:
  owner: Lucas Santana
  tier: orchestration
  canonical_source: CLAUDE.md §1–2 (handoff resume pattern)
triggers:
  - handoff
  - save state
  - prepare resume
  - end of session checkpoint
  - hand off to codex
  - hand off to next session
  - capture context
  - budget approaches limit
  - switching projects
---

# handoff

Capture active task state before running out of context, switching models, or stopping for the day.

## Guard condition

Before writing: verify External HD mounted and target directory is writable.

```bash
mount | grep -q "${DEV_ROOT}" || {
  echo "BLOCKED: External HD unmounted — cannot write ~/.claude/handoffs/<project>/latest.md"
  exit 1
}
```

## Capture (use references/template.md)

Write to `~/.claude/handoffs/<project>/latest.md` with these sections in order:

- **Active objective** — one sentence, what you're finishing or resuming
- **Repo, branch, worktree** — exact paths + worktree parent (e.g., `${DEV_ROOT}/.worktrees/my-task/`)
- **What changed** — file paths touched, git status summary (no full diffs)
- **What was verified** — tests passed, deploys green, decision checkpoints cleared
- **What remains** — next 2–3 steps, in order
- **Blockers + gates** — anything blocking next action; what condition unblocks it
- **Exact next action** — command to run or skill to invoke (copy-pasteable)
- **Key anchors** — PR/issue URLs, commit SHAs, decision links (ADRs, memory)

See `references/template.md` for format.

## Rules (non-negotiable)

1. **Keep it specific** — "fixed auth" [FAIL], "added jwt-refresh middleware to POST /auth/login, verified with curl + integration test" ✓
2. **Do not dump whole files** — path + line range only (e.g., `src/db/schema.ts:42–67`)
3. **Do not archive until next action is truly complete** — if you're mid-feature, do NOT commit/merge anything before writing this handoff
4. **Use the template** — deviating adds ambiguity for the receiving session

## Done when

- [ ] External HD mounted
- [ ] Target directory exists (`~/.claude/handoffs/<project>/`)
- [ ] Packet written and readable
- [ ] Next action is copy-pasteable (tested in same session if possible)
- [ ] Key URLs/commits/commands are absolute paths or full git refs
- [ ] No whole files dumped; all file refs include line ranges or function names
- [ ] Packet is ≤ ~2000 words (else split into multiple sub-packets or reference external ADRs)

## Pair with

On the receiving end, invoke `/resume` to auto-load and stage the handoff packet.

See CLAUDE.md §1 (handoff resume pattern) for integration rules.
