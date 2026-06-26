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

## Output

Return:
- canonical skills
- duplicates to archive
- missing core skills
- concrete file changes to make
