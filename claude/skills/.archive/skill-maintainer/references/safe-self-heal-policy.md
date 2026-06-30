# Safe Self-Heal Policy

## Allowed unattended fixes

- run `normalize_skills.py --write`
- regenerate `smoke-prompts.md`
- remove `.DS_Store`
- restore deterministic metadata and section contracts already governed by the normalizer
- refresh sweep artifacts and comparison state

## Not allowed unattended changes

- creating or deleting skills
- changing canonical or overlay ownership decisions
- adding or removing wrappers
- editing backlog policy based on inference
- rewriting related-skill routing unless maintainer tooling already governs it deterministically
- any browser, auth, sign-up, or personal-data flow

## Escalation

If a finding falls outside the allowed unattended list, classify it as
`manual_followup` and stop short of structural edits.
