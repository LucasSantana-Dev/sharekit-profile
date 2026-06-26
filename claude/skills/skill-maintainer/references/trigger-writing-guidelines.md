# Trigger Writing Guidelines

Use this guide when rewriting skill descriptions or generating smoke prompts.

## Description rules

- Lead with the job the skill does, not the skill name.
- Name the user intent and the situations that should trigger the skill.
- Keep the description specific enough that a router could distinguish it from nearby skills.
- Prefer `Use when ...` phrasing over vague category labels.
- Mention nearby exclusions only when confusion is likely.

## Anti-patterns

Avoid these phrases in final descriptions:

- `Use when the request is primarily about ...`
- `help with a <name> task`
- `workflows or outcomes`
- copied skill names with spaces substituted for hyphens
- generic claims that do not reflect the actual workflow in `SKILL.md`

## Smoke prompt rules

- Prompts should read like real user requests.
- Prefer one sentence that implies the workflow and expected output.
- Do not derive prompts by lowercasing the description tail.
- Do not mention the anti-pattern phrases above.
