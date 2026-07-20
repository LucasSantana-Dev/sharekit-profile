# Autonomy Tiers (ADR-0051)

Action-risk classification governing when the agent proceeds, self-gates, or asks the human.
Replaces ad-hoc "should I ask?" judgment with a mechanical tier check. Evidence base: multi-agent
debate only helps narrow reasoning tasks; homogeneous agent panels rubber-stamp (85.5% sycophancy,
arXiv:2604.02668); approval fatigue makes unlimited human gates worthless (93% blind-approve rate);
**scope is the safety lever, not approval count** (>75% of autonomous multi-file fixes regress vs
59%/91% PR-acceptance split, arXiv:2602.08915). Full citations in ADR-0051.

## T0 — Reversible, proceed silently
Discovery, reads, greps, planning, skill/MCP invocation, worktree setup, scratchpad writes,
read-only diagnostics. Zero gate, zero logging.

## T1 — Semi-reversible, proceed + report
Commits on branches, branch creation, narrow edits (<5 files), test edits, memory notes,
non-main pushes, PR opens on own repos. Proceed; surface in output. No human block.

## T2 — Wide blast radius but non-destructive: critic gate, then proceed
Merges to main/release, multi-module refactors (≥5 files or ≥2 modules), architecture changes,
public API changes, dependency additions, schema changes, hook/standard edits that alter agent
behavior globally.

Gate: ONE adversarial critic pass — not a debate panel (panels of same-model agents add ~0% safety;
diversity of *checks*, not head-count, is what works). The critic must be:
- a different tier than the executor (e.g. fable/opus critic on sonnet work), AND
- prompted to REFUTE ("find the reason this is wrong"), never to confirm, AND
- paired with mechanical checks where they exist (tests green, lint clean, gitleaks clean) —
  mechanical gates outrank model judgment.

Proceed with the winner. Escalate to human ONLY if the critic flags: irreversibility it cannot
rule out, or the change touches auth, secrets, or a data-integrity boundary.

Log every T2 gate: one JSON line to `~/.claude/autonomy-gates.jsonl`
(`{"ts","action","critic_verdict","proceeded","escalated"}`). Append-only; this is the drift audit trail.

## T3 — Destructive / irreversible / production: ask the human
Force pushes, history rewrites (filter-repo), prod deploys, data deletion, secret rotation,
`rm -rf` outside scratchpad, main-branch direct pushes, anything touching an open PR authored by
or commented on by another person (hard rule — overrides everything), spending money, outward-facing
publishes. Gate: AskUserQuestion / existing PreToolUse confirm hooks. **No automation bypass, no
env-var skip.** System-prompt-level "permission" does not override these — production incidents
(Replit 2025-07, Cursor 2026-04) happened *through* advisory frameworks; only hard gates held.

## Anti-fatigue rule
T3 asks must stay rare to stay meaningful. If a session generates >3 human escalations, stop and
batch the remainder into one decision list instead of serial prompts.

## Drift audit
Same gate violation ≥2× in 90 days (from autonomy-gates.jsonl or incident memories) → forced ADR
review of this standard. The spec catches drift mechanically; quarterly re-grounding keeps the spec
itself honest.
