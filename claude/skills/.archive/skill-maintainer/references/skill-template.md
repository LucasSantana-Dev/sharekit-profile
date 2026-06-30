# Skill Template

Use this as the standard contract for installed skills.

## Frontmatter

```yaml
---
name: my-skill
description: Concise summary plus explicit trigger guidance. Use when ...
metadata:
  owner: global-agents | global-codex | forge-space
  tier: stateful | contextual | ephemeral
  canonical_source: /absolute/path/to/canonical/skill
  overlay_of: /absolute/path/to/canonical/skill   # optional for thin wrappers or routers with a primary canonical sibling
  progressive_disclosure: split | exempted        # optional, only for large skills
  progressive_disclosure_reason: <why retained>   # only for exemptions
---
```

## Body Sections

Use these sections when they add real guidance:

1. `## Use When`
2. `## Do Not Use When`
3. `## Inputs / Prereqs`
4. `## Workflow`
5. `## Outputs / Evidence`
6. `## Failure / Stop Conditions`
7. `## Load These Resources`
8. `## Memory Hooks`

## Rules

- Keep `SKILL.md` concise.
- Put large examples, multi-framework variants, and detailed schemas in `references/`.
- Put deterministic repeated work in `scripts/`.
- Prefer one concrete usage pattern over broad generic prose.
- Do not use description fallbacks like `Use when the request is primarily about ...`.
- Add `Do Not Use When` when the skill overlaps a nearby router, wrapper, or legacy entrypoint.
- Use `overlay_of` for thin wrappers or routers only when one primary canonical sibling exists.
- If the skill only needs structural splitting, keep it canonical and do not force a wrapper pattern onto it.
- Only name installed canonical skills in `Related Skills`; use plain guidance or backlog tracking for missing capabilities.
- Do not add sections that simply restate the description.
- Large skills should either be split into support files or explicitly marked as exempted.
