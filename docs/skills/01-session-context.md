# Session & Context Skills

Use these at session start, after pauses, before context-heavy work, and at clean stopping points. The active closeout path is `knowledge-loop` + `handoff`, not the archived `session-wrap-up` wrapper.

---

## /session-bootstrap ⭐

Start-of-session routine that rehydrates context and points at the safest next action.

**Chains:** resume/last context → next-priority → context-pack

**When to use:** Beginning of a work day, first task in a new session, or after context loss.

**Output:** Briefing, blockers, and task-aware context.

---

## /resume

Rehydrate the current task from handoffs, plans, memory notes, and git state.

**When to use:** Resuming after a pause, compaction, or handoff.

**Output:** Full context for continuing without rediscovery.

---

## /context-pack

Build a task-aware context bundle via RAG, capped to a practical token budget.

**Process:**
1. Query RAG for relevant files, standards, and decisions.
2. Fetch only the necessary files or excerpts.
3. Include current repo rules and active plan context.
4. Return a concise bundle for multi-file work.

**When to use:** Before unfamiliar or multi-file work.

---

## /context-save

Capture current task state so work can be resumed later.

**Captures:** files touched, active plan, uncommitted changes, progress, and next action.

---

## /handoff

Write a durable resume packet for another agent or future session.

**When to use:** Context switch, end of session, or transfer to another worker.

**Output:** `~/.claude/handoffs/<project>/latest.md` with exact next actions and file paths.

---

## Closeout pattern

Use `/knowledge-loop` at meaningful task boundaries. It recalls related context, captures new decisions, curates weak retrievals, and writes a handoff when the session is ending.

**Last updated:** 2026-07-01
