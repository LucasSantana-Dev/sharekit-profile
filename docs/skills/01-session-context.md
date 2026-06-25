# Session & Context Skills

Use at the **start or end of a session**, or when context feels stale. `wake-up` and `resume` are your daily entry points; `handoff` is the exit. The composites (`session-bootstrap`, `session-wrap-up`) chain these automatically.

---

## /wake-up

Compact session-bootstrap brief — answers "what was I doing, what's blocking, what's next" in ~600-900 tokens.

**When to use:** Start of a new session; need quick refresh on last session's work

**Output:** Brief of prior context + immediate next action

---

## /session-bootstrap ⭐ **Composite**

Start-of-day routine. Chains: wake-up → next-priority → pr-snapshot → context-pack

**Phases:**
1. Recall last session context (wake-up)
2. Identify highest-value safe thing to work on (next-priority)
3. Show status of open PRs (pr-snapshot)
4. Build task-aware context bundle (context-pack)

**When to use:** Beginning of work day; first task in a new session

**Output:** Briefing + ready-to-start context

---

## /resume

Rehydrate the current task from handoffs, plans, tasks, memory notes, and git state.

**When to use:** Resuming after a pause, context switch, or context compaction

**Uses:** Handoff files (`~/.claude/handoffs/latest.md`), memory system, active task state

**Output:** Full context for resuming work without re-discovery

---

## /context-pack

Build a task-aware context bundle (relevant code + standards + past decisions) via RAG, capped at a token budget.

**When to use:** Before multi-file work; instead of reading files blindly

**Process:**
1. Query RAG for relevant files/decisions
2. Fetch matching files up to token budget
3. Include project standards + ADRs
4. Return task-aware bundle

**Output:** Curated code + context + standards

---

## /context-save

Capture current task state so work can be resumed later without re-discovery.

**When to use:** Before taking a break or context switch

**Captures:** Current file reads, active plan, uncommitted changes, task progress

**Output:** Saved task state (resumable via `/resume`)

---

## /adt-context

Optimize context window usage — compact stale data, compress via summarization, preserve active state.

**When to use:** Context >70% full; before token-heavy multi-agent work

**Process:**
1. Identify stale tool outputs
2. Compress via summarization (preserve facts, drop process)
3. Preserve active task state
4. Return optimized context

**Output:** Compressed context bundle (saves tokens)

---

## /adt-context-hygiene

Keep sessions focused and efficient — prune stale outputs, preserve active state, recommend compaction.

**When to use:** Session feels bloated; need a clean context

**Process:**
1. Audit for stale outputs (old terminal runs, read results)
2. Identify redundant tool calls
3. Recommend compaction if >75% full
4. Preserve only active task context

**Output:** Hygiene report + compaction recommendation

---

## /handoff

Compact the current conversation into a handoff document for another agent to pick up.

**When to use:** Before context switch, end of session, or handing off to another agent

**Format:** Markdown with exact next actions, file paths with line ranges, copy-pasteable commands

**Output:** Resumable handoff packet saved to `~/.claude/handoffs/<project>/latest.md`

---

## /handoff-diet

Meta-skill codifying the no-wakeup-polling pattern. Reduces handoff spam by 80%.

**When to use:** Optimizing handoff flow for repeated task patterns

**Output:** Efficient handoff pattern configured

---

## /session-wrap-up ⭐ **Composite**

Close out a development session by shipping work, capturing memory, and writing handoff.

**Phases:**
1. Run pre-ship verification gates (verify-before-done)
2. Ship merged work (tag + GitHub release)
3. Sync memories + ADRs to persistent storage
4. Write handoff document for resumption

**When to use:** End of work day; before switching projects; after completing major feature

**Output:** Shipped work + persisted memory + resumable handoff

---

## /session-cleanup

Clean up current session state so work can transition cleanly to the next session.

**When to use:** End of session; before another agent takes over

**Process:**
1. Stash any uncommitted changes
2. Archive session transcript
3. Log session metrics (tokens, turn count)
4. Clear temporary state

**Output:** Clean session state; archived transcript

---

## /zoom-out

Tell the agent to give broader context or a higher-level perspective on unfamiliar code.

**When to use:** Code is too detailed; need architectural overview

**Output:** Higher-level summary of system / module / feature

---

## /optimize

Optimize context usage by reducing bloat, improving token efficiency, and focusing on relevant areas.

**When to use:** Context >75% full; before expensive multi-agent work

**Process:**
1. Audit tool outputs for redundancy
2. Compress stale data
3. Focus on active task
4. Remove debug logs

**Output:** Optimized context (save 20-40% tokens)

---

**Last updated:** 2026-06-25
