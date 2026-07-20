# 2026-05-13 — Session handoff cadence: soft alert at 3k turns / $1k

## Status

Accepted.

## Context

This session ran 7,603 turns and cost ~$1,819. Cache hit was 98% the whole
time, so the cost isn't from cold reads — it's accumulated output-token
fees. The session shipped real work (v2.10.0, 5 process PRs, 3 follow-ups,
4 closed issues) but past roughly turn 3,000 the marginal value per turn
declined: more retries, more "let me check that again", more context
re-anchoring through compactions.

The question: when should a session hand off rather than keep extending?

## Research

### Cost shape inside a session

| Turn range | Typical activity | Cache hit | Cost/turn (Opus 4.7) |
|---|---|---:|---:|
| 0–500 | Bootstrap, context-load, first task | 70–85% | ~$0.10 |
| 500–2,000 | Steady shipping, composite skills firing | 90–96% | ~$0.18 |
| 2,000–4,000 | Long-tail loops (CI watches, sweeps) | 96–98% | ~$0.22 |
| 4,000+ | Diminishing returns, more retries | 98%+ | ~$0.25+ |

The 4,000+ band is where session-length cost compounds and where
cumulative confusion (forgotten earlier decisions, repeated lookups)
starts costing turns without producing value.

### Options

| Option | Trigger | Trade |
|---|---|---|
| Never auto-handoff (current) | None | Maximizes context continuity; risks long expensive sessions |
| **Soft alert at thresholds** | 3,000 turns OR $1,000 estimated cost OR cache hit <90% | User-controlled stop point; doesn't force handoff but surfaces the cost |
| Hard auto-handoff | Same triggers, forced | Predictable cost ceiling; risks mid-task interruption |
| Time-based (every 4 hours) | Wall clock | Easy to implement; ignores work shape |

## Critic challenge

What changes the answer:

1. **Cache savings vs context-loss cost.** A fresh session loses warm
   cache (~98% hit) and starts cold (~30–50% hit) for the first 100–200
   turns. The break-even is roughly: a fresh session costs ~$15–25 to
   reach steady-state, vs. continuing in a long session at $0.25/turn.
   **Hard handoff pays back after ~60–100 turns of post-handoff work.**
   If you're 80% done with the current task, don't handoff. If you're
   starting fresh work, handoff first.
2. **The complexity of `/handoff` itself.** A clean handoff requires
   `/handoff` to write a good resume packet, which itself costs turns and
   may miss state. Mitigation: today's `handoff` skill writes durable
   packets; tested in session-resume flows.
3. **Auto-anything is fragile.** Forcing a handoff mid-investigation
   loses the trail. Soft alerts (surfacing cost + offering handoff) at
   thresholds is better than automation.

The critic doesn't flip the leading option, but tightens it: **soft alert,
never forced.**

## Decision

**Surface a handoff prompt when ALL of these hold mid-session:**

- ≥3,000 turns since session start, OR
- ≥$1,000 estimated cost (via `token-audit --session $SID`), OR
- Cache hit rate drops below 90% inside the session (signals prompt bloat)

The surface should be a one-line `next-priority`-style suggestion:
> "Session at <turn-count>/<cost> — consider `/handoff` if you're done with the
> current task. Otherwise, ignore."

The user decides; no auto-handoff.

## Consequences

### Positive
- Visibility on cost trajectory while it's still adjustable
- Encourages discrete-task framing (do one thing, hand off, start fresh)
- Pairs with the model-tier ADR (2026-05-13-model-tier-strategy.md):
  if Sonnet is the default, the $1,000 threshold becomes a 4–6× longer
  runway in turn count

### Negative
- Adds a notification surface that could be ignored or become noise
- Doesn't address the underlying "single Opus session" pattern; if user
  ignores all alerts, the cost still accrues
- Implementing the cache-hit-drop signal requires hooking into the
  token-audit stream, which doesn't currently emit mid-session

### Neutral
- Compatible with existing skills (handoff, resume, context-pack)

## Revisit when

- **Average session cost drops below $500** (handoff alert thresholds may
  be set too high)
- **A user-reported incident traces to context-loss after handoff** (the
  handoff packet was insufficient — improve packet, not threshold)
- **`token-audit` gains a streaming/live signal** (then auto-trigger
  becomes viable; today it's only post-hoc)
- **A single composite skill consistently runs over the 3k threshold by
  itself** (suggests the skill needs internal compactions, not a session
  handoff)

## Implementation pointer

The signal can ride the existing `session-token-stop.sh` hook (already
registered in `~/.claude/settings.json` Stop event). Adding a mid-session
threshold check would need a new hook on `UserPromptSubmit` that reads
the session's running cost from claude-mem or computes it from the
transcript. Out-of-scope for this ADR; tracked separately if/when needed.

## Implementation — 2026-05-13T23:00Z

Wired as a UserPromptSubmit hook: `~/.claude/hooks/handoff-cadence-alert.sh`.

- Reads current session JSONL via `$CLAUDE_CODE_SESSION_ID`
- Computes running turn count, cost (PRICING constants from token-audit/audit.py),
  and cache hit rate
- Emits `systemMessage` when any threshold first crosses; tracks fired state in
  `~/.claude/state/handoff-alerts/<sid>.json`
- Throttled to once per 30s wall-clock to avoid re-scanning JSONL on every prompt
- Fires at most once per direction per session

Verified against `f2b9f551` (the 7,603-turn mega-session): hook fires both turns
and cost alerts with values matching the original handoff (7639 turns / $1848.21
estimated).

**Revisit if:** alert triggers too eagerly (raise thresholds) or never triggers
when sessions clearly bloat (lower thresholds + investigate JSONL parse).
