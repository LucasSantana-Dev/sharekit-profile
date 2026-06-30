---
name: skill-creator-local
description: Local fork of skill-creator (superseded by the official plugin for the
  bare `/skill-creator` name). Retained for its unique `scripts/init_skill.py`
  bootstrap and `references/` workflow docs that the plugin lacks. Use only when you
  specifically need the local init-script flow; for create/improve/eval use the
  official plugin via `/skill-creator`.
license: Complete terms in LICENSE.txt
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.agents/skills/skill-creator
---









# Skill Creator

Use this skill to build or revise skills that another agent can reliably pick up and use.

## Use When

- A new skill needs to be authored from scratch.
- An existing skill needs better triggers, metadata, or support-file structure.
- A large skill needs to be split into `references/`, `scripts/`, or `assets/`.
- A thin wrapper or overlay needs a documented relationship to a canonical skill.

## Do Not Use When

- The task is to audit the whole installed skill platform. Use `skill-maintainer`.
- The request only mentions the legacy `create-skill` name and needs compatibility guidance first. Start with that wrapper, then come back here.

## Inputs / Prereqs

- Know the skill's job, expected outputs, and trigger phrases.
- Load `~/.agents/skills/skill-maintainer/references/skill-template.md` before drafting a new skill contract.
- Load `references/workflows.md`, `references/output-patterns.md`, or `references/compatibility-wrappers.md` only when the task needs them.

## Workflow

1. Clarify the real usage pattern with concrete prompts, not abstract category names.
2. Decide whether the skill needs only `SKILL.md` or also `scripts/`, `references/`, or `assets/`.
3. Write frontmatter with `name`, a trigger-rich `description`, `metadata.owner`, `metadata.tier`, and `metadata.canonical_source`.
4. Add `metadata.overlay_of` only when the skill is a thin wrapper or overlay over a canonical sibling.
5. Keep the body concise and procedural. Put long variants, examples, and schemas in `references/`.
6. Add concrete outputs, stop conditions, and memory hooks only when they materially change behavior.
7. Validate the skill with `scripts/quick_validate.py` and at least one representative prompt.

## Outputs / Evidence

- A valid skill folder with frontmatter, concise workflow guidance, and only the needed support files.
- A clear trigger-rich description that another agent can match.
- At least one representative prompt or validation path.

## Failure / Stop Conditions

- Do not create a new skill when a small update to an existing canonical skill would solve the problem.
- Do not keep duplicate content in both `SKILL.md` and `references/`.
- Do not add README-style maintenance clutter inside a skill folder.

## Load These Resources

- `~/.agents/skills/skill-maintainer/references/skill-template.md`
- `~/.agents/skills/skill-maintainer/references/memory-tiers.md`
- `references/workflows.md`
- `references/output-patterns.md`
- `references/compatibility-wrappers.md`

## Memory Hooks

- Read memory when the skill touches workspace-specific policy, overlays, or canonicalization rules.
- Write memory only if the session creates a durable skill convention or maintenance rule.
