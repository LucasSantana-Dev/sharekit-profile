# 2026-07-01 — Parallel-mandate hard rule: amend with token-economics gates

**Status:** Accepted
**Driver:** June-2026 token audit ($9,077/28d, agentsview) + published subagent-economics data surfaced a conflict between the CLAUDE.md "parallel execution mandatory" hard rule and subagent cost structure.

## Context

The global CLAUDE.md hard rule mandates one `Agent()` per independent unit for ≥2 independent tasks. Purpose: prevent sequential-drift (lazy inline execution → wall-clock waste + single-context bloat toward the 200k ceiling; measured: 64 sessions >200k peak, mean 211k).

Conflicting evidence (2026 practitioner data): subagent dispatch for analysis work costs 2–4× single-agent baseline when children receive full/near-full context; savings only when child output is small or work is context-independent. Coordinated agent teams ≈ 15×. Forks inherit parent cache for free. Measured: 2.85 subagents/session avg; main sessions ran apex/Opus pricing most of June.

Counter-evidence for keeping dispatch: same-day session had 3 read-only audit agents keep ~150k tokens of transcript-scan output out of the apex-priced main context, each returning 1–3k reports — isolation clearly paid.

## Decision

**Amend, don't drop (Option B).** The mandate stays for genuinely independent units, with four minimal gates:

1. **Self-contained child prompts** — never duplicate full conversation context into children; pass only what the unit needs.
2. **Summary-only returns** — child final output must be a summary (≤~2k tokens); raw tool dumps stay in the child's context. This is the observable mitigation for output-size prediction error (critic finding).
3. **Fork-first** — when a child genuinely needs conversation state, use a fork (cache-inherited) instead of a fresh agent.
4. **Inline small analysis** — analysis subtasks whose expected combined tool output is trivially small (<~5k tokens) run inline; dispatch is not required for them.

**No gate-stacking.** If gate calibration fails, escalate to Option D (invert default: inline unless ≥3 units or per-unit tool output >20k) — do NOT add more gates to B (complexity-collapse risk; agents learn exemptions as the rule).

## Alternatives considered

- **A — keep unchanged:** locks in 2–4× penalty on analysis fan-outs; only defensible if wall-clock is non-negotiable. Rejected: no evidence the speed premium is valued at $/month scale.
- **C — drop mandate:** 15–30% potential savings but reintroduces sequential-drift collapse (the rule's original reason) within weeks absent monitoring. Rejected.
- **D — invert default (inline unless ≥3 units / >20k output):** 20–35% savings, +10–20% wall-clock. Kept as the designated FALLBACK if B's gates become dead code. Rejected as first choice: hard thresholds are more arbitrary than B's gates (blocks a 2-unit job with 25k output that should parallelize).
- **E — worker tiers only:** ~5% savings; treats symptom not structure (tiers already largely in place via `CLAUDE_CODE_SUBAGENT_MODEL=haiku`). Rejected: false economy.

## Consequences

- Positive: preserves parallelism guard rail + wall-clock on justified fan-outs; cuts context-duplication waste; reversible by reverting one CLAUDE.md bullet + one workflow.md subsection.
- Negative: gates 1 and 4 require judgment (fuzzy); risk of gates decaying into dead code — monitored via revisit triggers.
- Neutral: known data gap — no stratification of subagent work by type (analysis vs execution) or child-output size distribution. Monthly `session-insights` check covers the trend signals below.

## Revisit when (any TWO simultaneously → mandatory re-evaluation)

1. Cost flat/up for 2+ consecutive months despite the gates.
2. Child-output summaries overrun the ~2k guideline >6 times in 50 sessions.
3. Session peak context trends toward 180k+ (over-exempting → inline bloat).
4. Wall-clock +20% YoY (over-gating → lost parallelism).
5. Cache hit ratio <90% (fork pollution / context divergence).

Fallback path: B → D (never B + more gates).

## Links

- Evidence + implementation log: knowledge-brain memory `token-optimization-plan-2026-07`
- Amended artifacts: global `CLAUDE.md` (hard rules), `standards/workflow.md#parallel-execution-mandatory`
