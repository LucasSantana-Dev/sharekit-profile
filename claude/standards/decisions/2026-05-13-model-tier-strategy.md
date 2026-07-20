# 2026-05-13 — Model-tier strategy: Opus/Sonnet split

## Status

Accepted.

## Context

This session (`f2b9f551`) ran 7,603 turns on Claude Opus 4.7 (1M ctx) and
cost ~$1,819 — roughly 10% of the 30-day Claude Code spend in a single
session. Cache hit rate held at 98%, so the spend isn't from cold reads —
it's the per-output-token Opus rate × very high turn count.

Audit of what those turns did:
- 30–40% routine glue (`gh pr view`, `git status`, status snapshots, sweep
  reports, schedule wakeups)
- 30–40% small file edits (sed/Edit), PR comments, commit messages
- 15–25% real thinking (research-and-decide, critic dispatches via Agent,
  ADR drafting, root-cause diagnosis like the default-branch finding)
- ~5% subagent orchestration

Opus 4.7 was used uniformly for all of it. Sonnet 4.6 costs ~5× less per
output token. For the 60–80% routine glue work, Opus is overkill.

## Research

### Options

| Option | Cost shape | Trade |
|---|---|---|
| **Opus-only (current)** | $1,819 / 7,603 turns ≈ $0.24/turn | uniform quality; no decision overhead |
| **Opus/Sonnet split** | est. $300–500 same workload | save ~75%; needs routing rule |
| Sonnet-only | est. $200–300 | risk on critic / architecture decisions |
| Haiku 4.5 for glue + Opus for thinking | est. $150–250 | maximum savings; risk on tool-use reliability |

### Routing signals

Triggers that justify staying on Opus mid-session:
- Composite skills that explicitly need depth: `/research-and-decide`,
  `/critic`, `/audit-deep`, `/three-man-team`
- Multi-perspective work where a wrong call has prod-risk
- Root-cause analysis (the kind that finds default-branch misconfigurations)
- Complex code review with semantic critique

Triggers that don't justify Opus:
- CI status polling and sweep reconciliation
- gh pr merge, gh pr edit, gh issue create
- Conventional commit message drafting
- Updating memory files / index entries

## Critic challenge

What changes the answer:

1. **Sonnet 4.6's critic quality.** The earlier critic agent flipped both
   bulk-install F3 and migration-to-Fly today. Those flips required
   cross-context reasoning that Opus does easily. If Sonnet misses 1-in-5
   flips, the total cost (wrong decision shipped + redo) outweighs the
   per-turn savings. Mitigation: critic dispatches always Opus (already
   built into `/research-and-decide` and `/three-man-team` skill specs).
2. **Switching overhead.** Manually re-selecting model 50× per session
   isn't viable. Mitigation: default to Sonnet at session start; opt up
   to Opus only via `/think`, composite-skill invocations, or explicit
   `/model opus`.
3. **Tool-use reliability.** Sonnet 4.6's tool-use is approximately
   equivalent to Opus 4.7 per Anthropic benchmarks; both pass the
   "sequence of gh + git operations" stress that defines glue work.

The critic doesn't flip the leading option. Opus/Sonnet split wins.

## Decision

**Default to Sonnet 4.6 for routine work. Reserve Opus 4.7 for explicit
deep-thinking contexts.**

### When to opt up to Opus

- Any `/research-and-decide` invocation (composite already requires Opus
  for the critic phase)
- Any `/critic`, `/audit-deep`, `/three-man-team` invocation
- `/think` user prompt prefix
- Explicit `/model opus` mid-session when a question genuinely needs depth

### Default operating model

Sonnet 4.6. The session-start `/wake-up` skill already picks Sonnet by
default for "active work, comfortable context" mode; this just makes that
the standing rule rather than an opt-in.

## Consequences

### Positive
- Estimated ~75% cost reduction on long sessions (this session would have
  been ~$450 instead of $1,819)
- Faster output cadence (Sonnet 4.6 is faster per turn)
- Forces composite skills to be explicit about when they need Opus, which
  is good documentation hygiene

### Negative
- Risk of Sonnet missing a subtle bug that Opus would catch in routine
  review. Mitigation: composite reviews (`/pr-review-toolkit:review-pr`)
  still escalate to Opus per their skill specs
- Slight friction at "edge cases" (decision-ish work that doesn't quite
  warrant a full composite skill) — user has to remember to opt up

### Neutral
- This decision is reversible at any moment via `/model opus` mid-session
- Doesn't affect API key, plan, or billing surface — just the model
  selector

## Revisit when

- **Anthropic ships Sonnet 5.x or Opus 4.8** with materially different
  pricing or capability gap
- **A Sonnet-driven session produces a wrong-shippable decision** (e.g.,
  approves a bad merge, misses a real review concern) — capture as a
  feedback memory and re-evaluate the split
- **Anthropic re-prices Opus 4.7 down by ≥50%** (closing the gap)
- **The complexity-classifier hook reliably distinguishes "needs Opus"
  prompts** — at that point auto-routing becomes viable and this manual
  rule should be replaced

## Implementation — 2026-05-13T23:00Z

Wired as a UserPromptSubmit hook: `~/.claude/hooks/model-tier-router.sh`.

Hooks can't change the active model — they advise via `systemMessage`. The hook:
- Detects current session model from latest assistant turn in JSONL
- Classifies the incoming prompt as `depth` (matches `research-and-decide|critic|
  audit-deep|three-man-team|architecture decision|security review|root cause|
  trade-off|ADR|incident|postmortem|...`) or `routine` (everything else)
- Suggests `/model claude-opus-4-7` if `depth` on sonnet/haiku
- Suggests `/model claude-sonnet-4-6` if `routine` on opus
- Fires at most once per direction per session (`~/.claude/state/model-tier-router/<sid>`)

Composite skills still escalate to Opus internally via `Agent(model="claude-opus-4-7")`,
so a Sonnet session doesn't lose depth for ADRs/critic work — only the routine
glue between composites runs cheap.

**Revisit if:** users ignore the advice (means heuristic is too noisy or wrong) or
session costs don't drop after switching (means routing isn't where the cost is).
