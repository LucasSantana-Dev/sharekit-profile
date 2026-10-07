---
name: knowledge-loop
description: "Persist knowledge: recall, sync-memories, rag-curate, handoff. Modes: checkpoint, close (wrap up, sign off, save and stop, close session, --ship). Also \"what did we decide\", \"remember this\"."
user-invocable: true
auto-invoke: end-of-task + recall-questions + checkpoint-requests + session-end + context-budget-warning
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.claude/skills/knowledge-loop
triggers:
  - knowledge loop
  - remember this
  - save knowledge
  - persist
  - wrap up
  - sign off
  - close session
  - save and stop
  - session ending
  - memory persistence
  - end session
  - ship and remember
---

# Knowledge Loop

Unifies the knowledge systems (RAG index, memory notes, handoffs) into one workflow
so capture and retrieval stop being separate manual acts.

## Auto-invocation triggers

- User asks "what did we decide about X" / "where did we leave Y" / "is there a memory note for Z"
- End of a meaningful task (commit landed, PR merged, decision reached)
- User explicitly says "remember", "save this", "checkpoint", "wrap up", "sign off", "save and stop", "close session", "switching projects", "handing off to another machine"
- Session-budget guard signals approaching context limit (>85%: checkpoint plus handoff, then suggest close)

## Workflow

**Mount guard (required before any RAG/brain op, `standards/skill-authoring.md §mount-guard`):**
run [references/mount-guard.sh](references/mount-guard.sh) — if External HD is unmounted,
surface `BLOCKED: External HD unmounted — RAG/vault unreachable` and halt; do not return
empty recall as if the index were searched. In close mode the guard is per phase, see Close mode.

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
invoke `/rag-curate` to add the missing doc or rewrite the weak chunk. Skip if recall
was strong.

**Done when:** skill/rag-curate confirms N chunks rewritten or N docs added — verify via incremental reindex completion and cosine score ≥0.40 for the weak query in top 3 results.

### Phase 4 — Snapshot (if session-ending or context-pressured)
Invoke `handoff` to write a durable resume packet. Write it when work is in progress OR context >80%; skip otherwise.

**Done when:** handoff file written to `~/.claude/handoffs/<project>/latest.md` with exact
next action + file paths — confirm the path exists; or `(skipped: work continues)`.

When memory or the graph changed this session, push to the knowledge-brain after Phase 4 —
routing and stop conditions in [references/phase5-routing.md](references/phase5-routing.md),
executed by [references/push-protocol.sh](references/push-protocol.sh).

**Run `push-protocol.sh` yourself.** This line used to say a Stop hook ran it automatically;
verified 2026-08-29, no hook references that script on any event, so nothing was pushing and
the sentence was a phantom guardrail. `knowledge-loop-nudge.sh` (below) reminds you to run
the loop; it does not push for you.

## Checkpoint mode — what a mid-session stopping point runs

`knowledge-loop-nudge.sh` (Stop hook, `~/.claude-env/hooks/`) fires when a considerable
stopping point passes with nothing captured. It defines "considerable" mechanically from the
transcript, so it is auditable and does not depend on the model noticing:

| signal | threshold |
|---|---|
| commits / pushes / `gh pr create\|merge` | ≥ 1 |
| `Edit`/`Write`/`MultiEdit`/`NotebookEdit` calls | ≥ 8 |
| a write under `memory/` or `handoffs/` | **suppresses** the nudge and resets the window |

Work accumulates across Stops, so four edits now and four later still trip it. One nudge per
20 min per session (`NUDGE_COOLDOWN_S`), so it never nags.

**It is a hook, not a skill, on purpose.** A discipline skill whose triggers are
meta-questions tops out near 50% autonomous invocation however the description is written
(measured; memory `session_2026-06-26_adt_auto_invoke_refresh`). Detection has to be
deterministic; this skill stays the procedure.

At a **checkpoint** run Phases 1-3 and treat Phase 4 as `(skipped: work continues)` unless
work is in progress or context is >80%. A checkpoint that produced no durable output exits clean at Phase 1: recall,
confirm nothing new, say so, move on.

## Close mode (session end, one mode: "session end" == "close")

Mode comes from who asked, not context alone. **Checkpoint**: a Stop-hook nudge
(`STOP checkpoint: ...`), end of a task, or "save this". Always checkpoint at any context
level; above 80% it also writes the handoff; it never ships, never prints SESSION CLOSE, and
work continues. **Close**: only when the user's own message says wrap up, sign off, save and
stop, close session, end session, or passes `--ship`. Above 85% with no user close phrase: run
the checkpoint, write the handoff, and suggest close. **Recall**: a question only, Phase 1
then stop. Detail: [references/mode-close.md](references/mode-close.md).

Close = Phases 1-4 above (Phase 3 only on weak hits), then push brain, then the SESSION CLOSE
summary; with `--ship`, ship first. `--ship` means the flag or a close request that explicitly
asks to ship, commit or push. Order never changes: (0 only with ship) ship, memory, handoff,
push brain.

Hard gates (inline on purpose):
- **Mount guard first.** External HD unmounted: say `BLOCKED: External HD unmounted` for the
  brain writes, halt that phase (no retry, no silent skip), offer local-only memory under
  `.agents/memory/`, state the brain push is deferred until remount, never claim it was pushed.
- **Memory:** write only new items, skip what is already recorded (idempotent). Nothing new:
  `SKIPPED: no memory changes needed`.
- **Handoff: write it when work is in progress OR context >80%** (unfinished feature,
  mid-refactor branch, failing test, open task). All shipped and context low:
  `SKIPPED: all work shipped; no handoff needed`. Name the
  unfinished state in the packet. Packet at most ~2000 words, next action copy-pasteable.
- **Push brain** only if memory or graph changed, via `bash ~/.claude/skills/knowledge-loop/references/push-protocol.sh`.
  Never an inline `git add`. Push fails: `BLOCKED: brain push failed`, no silent retry.
- **Without ship, close never commits or pushes project code.** Dirty or unpushed tree:
  report it, still write the handoff, and recommend re-running with `--ship` (or pr-flow).
- **Ship (`--ship` or an explicit ask to ship, commit or push):** commit (conventional, meaningful) and push, or hand off to `pr-flow` when a
  PR is wanted, before any capture. Also update README/CHANGELOG if warranted. Tests failing: ship is `BLOCKED` (no commit, no push), list as unfinished; memory and summary still run.

Close summary (every line DONE, SKIPPED: reason, or BLOCKED: reason, with evidence). Always end
close mode with this block, including when ship hands off to pr-flow (dry run, nothing can execute: say so once,
then give each line the status it would get; never PLANNED or NOT RUN):
```
SESSION CLOSE - <date / project>
  Ship: <commit SHAs / PR | SKIPPED: not requested | BLOCKED: <reason>> (pr-flow | git)
  Recalled: <n hits, top cosine X | SKIPPED: reason> (skill: recall)
  Memory:   <DONE paths | SKIPPED: reason | BLOCKED: reason> (skill: sync-memories)
  Improved: <chunks/docs | SKIPPED: strong hits> (skill: rag-curate)
  Handoff:  <DONE path | SKIPPED: all work shipped | BLOCKED: <reason>> (skill: handoff)
  Push brain: <DONE n files, sha | SKIPPED: no brain changes | BLOCKED: reason> (push-protocol.sh)
  Open watch: <outstanding commitments | (none)>
```

## Reconciliation

Output a single capture summary:
```
KNOWLEDGE LOOP — <topic>
  Recalled:  <n> hits, top cosine <X> (skill: recall) <STATUS>
  Captured:  <memory file paths> (skill: sync-memories) <STATUS>
  Improved:  <chunks rewritten / docs added> (skill: rag-curate) <STATUS>
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
- If `sync-memories` and `rag-curate` would write to the same file → consolidate writes
  to avoid double-update churn
- Never skip Phase 4 when work is in progress OR context is >80%: handoff is required for cross-session continuity

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
