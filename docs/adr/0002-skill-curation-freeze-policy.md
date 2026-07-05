# ADR 0002: Skill Curation Policy — Freeze at 46, Add On-Demand

**Status:** Accepted
**Created:** 2026-07-05
**Owner:** Lucas Santana
**Tags:** sharekit-profile, curation, policy

## Context

`sharekit-profile` publishes a curated subset of Lucas's ~167 locally-authored Claude Code
skills to a public npm/GitHub-Pages profile, gated by `curated-skills.txt` (an allowlist).
This session grew the curated set from 41 → 46 (5 skills added via individual confirmation:
`parallel-work-coordinator`, `audit-deep`, `backlog`, `research-and-decide`,
`efficiency-advisor`). 121 skills remain uncurated; ~40 were categorized as "generically
useful to any Claude Code operator," ~77 as narrower/stack-specific, ~9 as clearly personal
or duplicate.

**Note on the allowlist model's provenance:** `curated-skills.txt`'s header comment cites
"ADR-0039" as the decision that established curation-over-full-mirror. No such file exists
in this repo's `docs/adr/` (only `0001-harness-improvement-sequencing.md`); ADR-0039 in the
global knowledge-brain refers to an unrelated decision (excluding project memory copies from
RAG). The curation-model decision itself was apparently never committed as a doc — this ADR
does not retroactively reconstruct it, only documents what's decided going forward. Flagged
as an open gap (see Consequences).

Publishing mechanics observed this session: allowlist edit + rsync + sanitize + gitleaks scan
is fast (seconds/skill); the bottleneck is a **hand-written entry in `index.html`'s JS
`SKILLS` array** (name/category/composite/description) — no generator from `SKILL.md`
frontmatter exists. Nothing currently validates that `curated-skills.txt` and `index.html`
stay in sync; that exact drift (skills curated but missing from the array) was found and
fixed this session with zero warning from CI.

## Decision

**Freeze the curated set at its current level; add skills on-demand only, not speculatively.**

1. Do not bulk-publish the ~40 "generic candidate" skills now. No install-telemetry or
   external-request signal exists to justify the effort against 121 unpublished skills.
2. On-demand process (defined here so it's repeatable without re-litigating each time):
   a specific external request or concrete need for skill X → 30-min review (generic
   applicability + sanitization pass + gitleaks scan) → add to `curated-skills.txt` →
   sync + write its `index.html` entry → commit + push.
3. Add a CI check (any future session, low priority — not gating this ADR) that fails if
   `curated-skills.txt` entries don't all have a matching `index.html` SKILLS entry, so the
   exact drift class found this session can't recur silently.

## Alternatives considered

- **Bulk-curate now (~40 at once):** rejected — sunk-cost pressure from a productive session,
  not evidence the 40 are wanted; 40-80 min of manual `index.html` toil for speculative value;
  concentrates drift risk (an error rate applied across 40 new entries at once vs. one at a
  time under human review).
- **Ask-per-theme (continue current approach indefinitely):** rejected — same manual-entry
  bottleneck, just amortized across future sessions with no clear stopping point; doesn't
  outperform on-demand once demand signal is absent.
- **Criteria-based auto-curation:** rejected — "generic applicability" isn't safely
  automatable against free-text skill prompts (a generically-named skill can still carry a
  buried personal reference or doc-example secret, as this session's one gitleaks LOW finding
  showed); would require building an index.html auto-generator first (doesn't exist) and a
  rule-validation pass, estimated 2-4 hours for a benefit with no confirmed demand.

## Consequences

- Positive: zero speculative maintenance burden; curated-set drift risk stays low (46 stable
  entries); reversal cost of this policy is near-zero (adding a skill later is minutes of
  work, no batch to unwind).
- Negative: ~40 useful skills stay unpublished until requested; external users who'd want
  one won't find it unless they ask.
- Neutral: the ADR-0039 orphaned-reference gap in `curated-skills.txt`'s comment is noted,
  not fixed here — low urgency, doesn't block this policy.

## Revisit when

- 3+ external requests surface for specific uncurated skills → re-open A (bulk) or B
  (ask-per-theme) as live options, now with actual demand evidence.
- 6 months pass with zero on-demand requests → treat as confirmation the freeze level is
  correct; no action needed.
- 5+ on-demand additions land smoothly → consider whether the accumulated pattern justifies
  refreshing the curated list in one batch based on realized (not predicted) demand.
- The `index.html` generator gap gets closed (auto-generate SKILLS entries from `SKILL.md`
  frontmatter) → removes the actual bottleneck this ADR is working around; re-evaluate bulk
  curation once the marginal cost per skill drops to near-zero.
