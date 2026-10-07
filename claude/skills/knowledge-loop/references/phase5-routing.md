# Phase 5 — Push to Brain: Routing & Stop Conditions

**When to run Phase 5:**
- Memory or graph changed this session (not pure recall).
- External HD is mounted (mount guard §1 in mount-guard.sh).

**When to skip Phase 5:**
- Recall-only session with no writes.
- Mount guard check fails → surface blocker, skip push, halt Phase 5.

Close mode always runs push-protocol.sh when memory or graph changed; the skip rule applies to checkpoint only.
Note: the SessionEnd `sync push` hook mirrors the claude-env harness, skills and rag repos; it does not push knowledge-brain.

**What changes**
- **Memory**: Any file written to `~/.claude/projects/-Volumes-External-HD-Desenvolvimento/memory/`.
- **Graph**: `graphify` ran a full build (`--update` or new graph) this session — snapshot at `graphify-out/graph.json`.

**How to detect a change**
- Memory: `git -C "$BRAIN" status memory/` shows modified/untracked.
- Graph: Compare `graphify-out/graph.json` node count to prior via `jq '.nodes | length'`.

**Push protocol**
See `references/push-protocol.sh` — fail loud if mount guard blocks; never retry silently.

## Idempotency safeguard

If memory write happened in Phase 2 AND rag-curate ran in Phase 3 on the same file, use `git -C "$BRAIN" diff --cached` to check if Phase 2 and Phase 3 are touching overlapping regions. If so, reconcile — only push once with combined changeset (don't do redundant commits).
