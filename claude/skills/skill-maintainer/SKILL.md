---
name: skill-maintainer
description: "Audit the local skill catalog for duplicates, stale references, vague descriptions, and broken routing rules. Normalize filenames, consolidate redundant skills, and flag which skills need description tightening. Use when skill discovery feels fuzzy, duplicate-handling needs cleanup, or the routing table has grown brittle."
triggers:
  - maintain skills
  - improve skills
  - audit skill catalog
---

# skill-maintainer

Use when the skill system itself needs work.

## Audit rules

- identify duplicate names
- prefer folder skills with `SKILL.md`
- archive loose duplicates
- remove stale references to retired tools
- tighten vague descriptions and trigger lists
- ensure core skills are checkpoint-aware and safe by default

## Reference policies

Load the matching policy when its audit rule fires — these encode the detailed
rules behind the checklist above (read on demand, not all at once):

- Duplicates & support files — `references/duplicate-policy.md`, `references/support-file-policy.md`
- Descriptions & triggers — `references/trigger-writing-guidelines.md`
- Routing & wrappers — `references/router-patterns.md`, `references/wrapper-pattern.md`, `references/review-response-wrapper.md`
- Related-skill links — `references/related-skill-integrity.md`
- Safe-by-default / self-heal — `references/safe-self-heal-policy.md`
- Evidence before building — `references/demand-evidence-policy.md`
- Browser-skill boundaries — `references/browser-automation-boundaries.md`
- Cadence, gates & triage — `references/recurring-sweep-contract.md`, `references/monthly-gate-policy.md`, `references/backlog-triage-contract.md`

Templates/fixtures used by the sweep: `references/skill-template.md`,
`references/smoke-prompts.md`, `references/routing-smoke-fixtures.json`,
`references/memory-tiers.md`.

## Output

Return:
- canonical skills
- duplicates to archive
- missing core skills
- concrete file changes to make
