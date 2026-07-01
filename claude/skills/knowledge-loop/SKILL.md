---
name: knowledge-loop
description: Composite skill — query, capture, improve, and persist knowledge in one workflow. Chains recall (RAG query) → sync-memories (write durable note) → rag-maintenance (improve weak retrievals) → handoff (durable snapshot if session-ending). Use when the work involves "what did we decide", "remember this", "save where we are", or any closing checkpoint.
user-invocable: true
auto-invoke: end-of-task + recall-questions + checkpoint-requests
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.claude/skills/knowledge-loop
---

# Knowledge Loop

Unifies the three knowledge systems (RAG index, claude-mem, handoffs) into one workflow
so capture and retrieval stop being separate manual acts.

## Auto-invocation triggers

- User asks "what did we decide about X" / "where did we leave Y" / "is there a memory note for Z"
- End of a meaningful task (commit landed, PR merged, decision reached)
- User explicitly says "remember", "save this", "checkpoint", "handoff"
- Session-budget guard signals approaching context limit

## Workflow

**Mount guard (required before any RAG/brain op — `standards/skill-patterns.md §mount-guard`):**
run [references/mount-guard.sh](references/mount-guard.sh) — if External HD is unmounted,
surface `BLOCKED: External HD unmounted — RAG/vault unreachable` and halt; do not return
empty recall as if the index were searched.

### Phase 1 — Query (always)
Invoke `/recall` (MCP: `rag_query(query="<topic>", top=5)`) with the user's question
or the active task topic. For which knowledge source to route to, `recall` is canonical —
see [references/recall-routing.md](references/recall-routing.md). If the user is asking a
recall question, return the answer immediately and skip Phase 2/3 unless they also asked to
capture something.

**Done when:** recall returns `{hit_count: N, top_cosine: X, source: [memory|handoff|commit|code]}` — confirm top result answers your question (cosine ≥0.50) or increase `top` up to 8.

### Phase 2 — Capture (if new knowledge produced)
Invoke `/sync-memories` with what was learned, decided, or built this session. Skip if
the session was pure read/recall with no durable output. To classify what artifact to
write (memory vs committed doc) and which tags apply, follow the decision tree in
[references/graduation-gate.md](references/graduation-gate.md).

**Done when:** all memory files written to `~/.claude/memory/` (or project-local `memory/`) and registered in memory index — confirm via file listing + MEMORY.md pointer.

### Phase 3 — Improve (conditional)
If recall returned weak hits (cosine <0.40) for a query that should have hit something,
invoke `/rag-maintenance` in curation mode to add the missing doc, rewrite the weak chunk,
or reindex stale content. Skip if recall was strong.

Improvement discipline:
- Create a superseding memory for changed current state; do not rewrite historical memories as if old decisions never happened.
- If a recalled memory contradicts repo truth, mark the new capture as `supersedes` and reference the old note.
- Treat weak recall as a retrieval bug until proven otherwise: inspect source, chunk, index freshness, and query wording.
- If the filesystem has more memory files than the index, record coverage drift and schedule reindex before relying on recall.

**Done when:** `rag-maintenance` confirms N chunks rewritten or N docs added — verify via incremental reindex completion and cosine score ≥0.40 for the weak query in top 3 results.

### Phase 4 — Snapshot (if session-ending or context-pressured)
Invoke `handoff` to write a durable resume packet. Skip if work continues immediately.

**Done when:** handoff file written to `~/.claude/handoffs/<project>/latest.md` with exact
next action + file paths — confirm the path exists; or `(skipped: work continues)`.

When memory or the graph changed this session, push to the knowledge-brain after Phase 4 —
routing and stop conditions in [references/phase5-routing.md](references/phase5-routing.md),
executed by [references/push-protocol.sh](references/push-protocol.sh). (The Stop hook runs
this automatically; invoke manually only if pushing mid-session.)

## Reconciliation

Output a single capture summary:
```
KNOWLEDGE LOOP — <topic>
  Recalled:  <n> hits, top cosine <X> (skill: recall) <STATUS>
  Captured:  <memory file paths> (skill: sync-memories) <STATUS>
  Improved:  <chunks rewritten / docs added> (skill: rag-maintenance) <STATUS>
  Snapshot:  <handoff path> (skill: handoff) <STATUS>
  Open watch: <future obligation | (none)>
```

If a phase was skipped, mark it `(skipped: <reason>)` so the trail is visible.

## Outputs / Evidence

- Recall results inline
- Memory files written (paths + one-line preview)
- RAG re-index confirmation (chunk delta)
- Handoff path if Phase 4 ran

## Repository SoT capture gate

After capturing any decision, check: "Would a future agent need this committed context to make a correct decision?" If yes and it is not yet committed (only exists in memory, Slack, or ephemeral form) — surface it as an open action: "Decision X needs to be committed before next session can rely on it." Do not exit the loop with uncommitted agent-actionable context.

## Failure / Stop Conditions

- If recall returns nothing AND no new knowledge was produced this session → exit clean,
  no capture needed
- If `sync-memories` and `rag-maintenance` curation would write to the same file → consolidate writes
  to avoid double-update churn
- Never skip Phase 4 if context is >80% — handoff is required for cross-session continuity

## Worked example

End of a multi-round token-optimization session that shipped 15 hooks + a /caveman skill + autocompact tuning.

```
KNOWLEDGE LOOP — token optimization rounds 1-4
  Recalled:  3 hits, top cos 0.50 (skill: recall)
  Captured:  token_opt_round4_2026-05-13.md + token_baseline_2026-05-13.md
             (skill: sync-memories — manual write because the work was
              still in-flight when the prompt arrived)
  Improved:  (skipped: RAG hits strong, no curation needed — top cos 0.50
              is above the 0.40 weak-hit threshold)
  Snapshot:  handoffs/latest.md + precompact_snapshot_2026-05-13T23-53-44Z.md
             (skill: handoff — auto-written by PreCompact hook 5 min earlier,
              so phase 4 was effectively idempotent)
```

Key points the example demonstrates:
- Each phase output names the underlying skill, even when invoked indirectly (PreCompact hook fired `handoff` for me).
- A skipped phase says **why**, not just "skipped" — the threshold (cos 0.40) is the audit trail.
- Capture and Snapshot can land in the same turn without conflict; both write to `memory/`.
