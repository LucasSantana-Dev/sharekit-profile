# Knowledge-Brain Standard (ADR-0029)

Canonical spec for every knowledge / memory / RAG / graph skill. The brain is the
single source of truth for memories + graph snapshots; this file is the single
source of truth for *how skills interact with it*. When a skill touches memory,
graphs, or RAG, it must follow the rules below.

Related: [[adr_0029_cross_project_shared_brain]], [[homelab_dashboard_audit_2026-06-18]]
(prometheus-port + mount-state lessons), `graphify-discipline.md`.

## Paths (do not hardcode variants — use these)

```
BRAIN="${DEV_ROOT}/knowledge-brain"   # vault root (on external drive)
$BRAIN/memory/      # memory .md files + MEMORY.md index
$BRAIN/graphs/<project>/graph.json   # per-project graph snapshots
# memory is symlinked into the Claude memory dir:
SYM="$HOME/.claude/projects/-Volumes-External-HD-Desenvolvimento/memory"  # -> $BRAIN/memory
```

GitHub remote: `<github-user>/knowledge-brain`.

## 1. Mount guard — ALWAYS run before any brain/RAG op

The brain + the RAG embedder cache live on the external drive. If the drive
unmounts (it has — mid-session, 2026-06-18), the symlink dangles, the embedder
won't load, and blind operations silently corrupt state (a stale `[ -f ]` check
read present files as "absent" and chunks were wrongly deleted). So **fail loud,
never silent**:

```bash
BRAIN="${DEV_ROOT}/knowledge-brain"
if ! mount | grep -q "${DEV_ROOT}" || [ ! -d "$BRAIN/.git" ]; then
  echo "BLOCKED: external drive not mounted — knowledge-brain ($BRAIN) unreachable." >&2
  echo "Surface to the user and STOP; do not write, delete, or recall against the brain." >&2
  exit 0   # in a hook; in a skill, surface the blocker as output and halt the phase
fi
```

Skills must treat "drive unmounted" as a hard stop, not a reason to fall back to
guesses. `[ -f "$SYM/x.md" ]` returning false during an unmount means *unknown*,
not *absent* — never delete or "reconcile" on it.

## 2. Write via the symlink path (so the index stays fresh)

Memory writes should target `$SYM/<name>.md` (the symlink), NOT the raw `$BRAIN/memory/`
path. The `reindex-hook.sh` matches the symlink path string to fire an incremental
reindex; a raw brain-path write used to escape it (fixed 2026-06-18 — the hook now
normalizes brain→symlink, but writing via `$SYM` is still the clean default).

Note: `build.py` resolves symlinks, so every memory indexes under the brain
*realpath* — that is the one canonical RAG path. Don't dedup by deleting
brain-path chunks (they are canonical, not duplicates).

## 3. Push protocol (after memory or graph change)

The SessionEnd `sync push-memories` hook commits + pushes automatically. Push
explicitly when the session is NOT ending soon, or after a graph snapshot:

```bash
BRAIN="${DEV_ROOT}/knowledge-brain"
git -C "$BRAIN" add memory/ graphs/ 2>/dev/null
git -C "$BRAIN" diff --cached --quiet || {
  git -C "$BRAIN" commit -q -m "chore: knowledge-brain sync from session" && git -C "$BRAIN" push -q
}
```

Graph snapshots: `cp <repo>/graphify-out/graph.json $BRAIN/graphs/<project>/` then push.
Skip if node count is unchanged (no structural delta).

## 4. Repository-as-SoT gate

A decision a future agent needs must be committed to the relevant repo (ADR) AND
captured in the brain. Don't exit a knowledge workflow with uncommitted
agent-actionable context.

## 5. RAGLight (Phase 2 — deferred)

Cross-project semantic recall will be a RAGLight MCP exposing `search_knowledge`
(`FolderLoader` → `$BRAIN/memory/`, e5-small embedder per ADR-0028). Until live,
`recall` uses the local RAG index (which already covers `$BRAIN/memory` via the
symlink glob) + claude-mem; cross-project reads are grep/read against the vault.

## Conformance checklist (every knowledge/memory/RAG skill)

- [ ] Mount-guards before brain/RAG ops (§1) — fail loud, never silent
- [ ] Uses the canonical paths (§Paths), no hardcoded variants
- [ ] Writes memory via `$SYM` (§2)
- [ ] Pushes memory/graph changes (§3) when not session-end
- [ ] References this standard instead of duplicating the rules
