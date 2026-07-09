---
name: decide-now
description: Force a decision when the agent is stuck in analysis paralysis, going in circles, or repeatedly weighing options without committing. Picks the best available option, states the rationale, and moves forward immediately. Use when the agent has been deliberating for 3+ turns, when options are deadlocked, or when the user says "just decide", "pick one", "move on", or "stop deliberating". Also use when the user asks for a decision and the agent keeps hedging.
triggers:
  - decide now
  - pick one
  - stop deliberating
  - force decision
---

# decide-now

Make the right call faster by grounding the decision in what's actually happening — not in generic best practices.

## decide-now vs /decide

| | decide-now | /decide |
|---|---|---|
| **When** | Answer depends on current context | One-time architectural bet |
| **Speed** | Fast (minutes) | Thorough (research phase) |
| **Output** | Chat verdict | ADR file |
| **Examples** | "merge now or wait?", "fix or defer?", "A or B for this task?" | "which ORM?", "which deploy target?" |

Rule of thumb: if the answer would change depending on what's in memory / git / plans / PRs right now → decide-now. If future agents need to know the decision was made → /decide.

## Workflow

### 1. Load relevant context

Don't read everything — scan for what the question actually needs. Common sources:

| Question type | What to load |
|---|---|
| Merge / PR readiness | `gh pr view <N>` CI status, open review threads, CodeRabbit state |
| Prioritization | Memory index, open issues, active plans, recent commits |
| Approach selection | Recent ADRs, CLAUDE.md constraints, active plans, memory |
| Bug fix vs defer | CI state, PR stack, issue severity, what's in flight |
| Dependency on external state | Handoff at `~/.claude/handoffs/<project>/latest.md` |

Always check: **CLAUDE.md hard rules** — a rule there can override everything else. When checking reviewer-comment rules: CodeRabbit, dependabot, renovate, and other configured bots are explicitly NOT "another person" — they don't block merges per CLAUDE.md bot-exemption.

### 2. Synthesize

Before forming a recommendation, ask:
- Does any CLAUDE.md rule constrain the options?
- What would be consistent with the current trajectory of work?
- Does memory record a similar decision and its outcome?
- Are there blockers or dependencies that change the calculus?
- What's the cost of being wrong? (reversible → bias toward action; irreversible → bias toward caution)

### 3. Output — always this shape

```
Decision: <one-line verdict — the actual choice, not "it depends">

Why: <2-3 sentences grounded in the loaded context; cite specifics (PR #N, memory note X, ADR slug, plan phase)>

Tradeoff: <what you're giving up with this choice — one sentence>

Next step: <the smallest concrete action to execute on this decision>
```

**No hedging.** If the question has a clear answer from context, give it. If it's genuinely ambiguous, say so and name the single missing piece that would resolve it — don't produce a "both have merits" answer.

## Examples

**User:** "Should I merge PR #45 now or wait for CodeRabbit?"

```
Decision: Merge now.

Why: All 5 CI checks are green (test/shellcheck/ruff/actionlint/gitleaks). CodeRabbit has been triggered but no blocking findings from it yet — waiting adds delay without adding safety. CLAUDE.md hard rule "never merge with human reviewer comments" doesn't apply here (only bot activity).

Tradeoff: CodeRabbit may flag something after merge; fixable in a follow-up commit.

Next step: gh pr merge 45 --repo ... --squash
```

---

**User:** "Fix the FORMAT gate regression on this branch or defer it?"

```
Decision: Fix it now.

Why: FORMAT gate is a CI blocker — the branch can't merge until it passes. Memory records a prior session where deferring a gate regression caused 2 extra CI round-trips. The fix is mechanical (regenerate golden baseline), not a design decision.

Tradeoff: Adds one commit to the branch.

Next step: python3 eval/runner.py --update-baseline && git add eval/baselines/ && git commit -m "eval: update FORMAT golden baseline"
```
