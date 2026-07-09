# Phase 1+2 — Architecture and Mode Decision

This phase makes two explicit decisions. Both must appear in `architecture.md`.

See [cost-guide.md](cost-guide.md) for token cost estimates before deciding.

## Decision A: Loop size

**Single-agent loop** — one agent runs the full cycle. Best when:
- Focused, bounded task (one file, one PR, one article)
- No parallel workstreams
- Cost tier is quick or medium

**Fleet loop** — orchestrator + specialist agents. Best when:
- Multiple parallel workstreams with different skill needs
- Cost tier is medium or heavy

State which you chose and why you rejected the other.

## Decision B: Loop mode

**Closed loop** (default) — bounded path designed by the human; agent runs inside defined steps with explicit stop conditions. 30–50% cheaper than open.

**Open loop** — agent explores its own path. Use only when the search space is genuinely unknown and the user accepts higher cost and less predictability.

State which you chose and why. Recommend closed unless the user's goal is explicitly exploratory.

If fleet: sketch the orchestrator + specialist breakdown in a diagram.

Save as `architecture.md`. Present to user and confirm before Phase 3.

## Critic gate (after architecture confirmed)

Dispatch ONE `Explore` agentType critic — read-only, never edits — with this prompt:

> "Challenge this loop architecture: What could make the loop spin forever? What stop condition is missing or too weak? What failure mode does the escape hatch not cover? What would cause the Verify stage to always pass even when it should fail?"

- If critic finds ≥1 critical issue → revise `architecture.md` before Phase 3.
- If critic finds only minor concerns → log them in `architecture.md` under a "Critic notes" section and proceed.

Done when: critic verdict returned; critical issues resolved or none found.
