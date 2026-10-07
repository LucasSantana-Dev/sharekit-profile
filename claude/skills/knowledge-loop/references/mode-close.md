# Close mode detail

Merged from `session-close` and `session-wrap-up` (archived 2026-10-07). Hard gates live in
SKILL.md; this file holds the long form. One mode: session end == close.

## Order

`[ship]` -> Memory -> Handoff -> Push brain (steps, not the Phases 1-4 of SKILL.md; close runs those too). Steps are sequential and never reorder. A
step whose precondition fails is skipped with a reason; a blocked phase halts (no retry, no
silent skip). Idempotency: state-check before each write, skip if already done.

## Step: Ship (`--ship`, or a close request that explicitly asks to ship, commit or push)

1. `git status` in every touched project directory.
2. Uncommitted changes: conventional, meaningful commits. No empty commits.
3. Push to the remote, or hand off to `pr-flow` when the work should become a PR.
4. Remove temporary or experimental files you created.
5. Update README/CHANGELOG if warranted.
6. Checks failing: ship is `BLOCKED: <reason>` (no commit, no push); carry it to the handoff as unfinished. Memory and summary still run.

Without ship, close is memory-only and never commits or pushes project code. Report a
dirty or unpushed tree and recommend `--ship`.

## Step: Memory (always)

Invoke `/sync-memories`. Update project overview, architecture, testing state, security or
workflow notes only if changed. Write only new items; skip what is already recorded.
Done when file paths are confirmed written (`.agents/memory/<project>.md` or vault entries)
or `SKIPPED: no memory changes needed` (pure read-only session).
Fallbacks: no Serena configured, use `.agents/memory/` only; no project detected, local
memory only. Continue to the Handoff step even if Memory was partial.

## Step: Handoff (work in progress OR context >80%)

Invoke `/handoff`. Precondition: write the handoff when work is in progress OR context >80%
(unfinished feature, mid-refactor branch, failing test, active task). If all work is merged and pushed and context is low: `SKIPPED: all work shipped; no handoff needed`.
Done when the packet is at `~/.claude/handoffs/<project>/latest.md` (or the project dir) with
objective, repo/branch/worktree, what changed, what was verified, what remains, blockers,
next action (copy-pasteable), key anchors. At most ~2000 words, no whole-file dumps; split or
link ADRs if longer. Name failing tests and unfinished state explicitly.
If the write fails, surface the error and halt the phase; do not auto-skip.

## Step: Push brain (only if memory or graph changed)

Precondition: the Memory or Handoff step wrote to the brain. Otherwise `SKIPPED: no brain changes detected`.
Mount guard before any vault write (standards/knowledge-brain.md section 1):
```bash
mount | grep -q "${DEV_ROOT:-$HOME/dev}" || { echo "BLOCKED: External HD unmounted, cannot push brain"; exit 0; }
```
Then run the shared script, never an inline copy:
```bash
bash ~/.claude/skills/knowledge-loop/references/push-protocol.sh
```
The old inline `git add memory/ graphs/ 2>/dev/null` staged nothing when one pathspec was
missing and hid the error (measured 2026-09-16); the script stages one pathspec at a time.
Done when `git -C "$BRAIN" log --oneline -1` reflects the push, or "nothing to push" is
confirmed. Push failure: `BLOCKED: brain push failed - <error> - try later`; local brain
state is already updated, next session retries.

## Stop conditions

1. External HD unmounted at any step (the guard is per step): `BLOCKED: External HD unmounted`, offer local-only
   memory under `.agents/memory/`, defer the brain push, halt that step, do not continue
   past it as if it succeeded, never claim the brain was pushed.
2. Handoff write fails: halt that step, surface the error.
3. Brain push fails after a successful write: surface, no silent retry.

## Summary rules

Signal-first: lead with the per-phase status line, then evidence (paths, SHAs). Each line
names its skill (recall, sync-memories, rag-curate, handoff, push-protocol.sh, pr-flow). Under ~200 tokens.
