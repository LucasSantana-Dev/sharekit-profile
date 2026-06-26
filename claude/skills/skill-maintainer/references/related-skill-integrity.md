# Related Skill Integrity

`Related Skills` is a routing surface, not a wish list.

## Rules

- Only reference installed skills by name.
- Installed canonical siblings are the default choice for `Related Skills`.
- Installed wrapper or alias siblings are allowed when the wrapper is intentionally public and its `overlay_of` target is valid.
- If a nearby capability does not exist, convert the note into plain guidance or track it in backlog instead of naming a fake sibling.
- Prefer fewer accurate related-skill entries over long stale lists.
- When a skill routes to another skill, the receiving skill should actually exist and fit the contract.

## Classification

- Installed canonical sibling: safe to reference directly in `Related Skills`.
- Installed wrapper or alias sibling: safe to reference when the wrapper contract is explicit and maintained.
- Plain-text guidance: use when the adjacent capability should be described, but no installed skill exists.
- Backlog-only missing capability: record the gap in maintainer backlog, not in the skill body as a fake sibling.

## Backlog handling

If cleanup uncovers a true capability gap, record it in a maintainer backlog document rather than creating a placeholder skill or leaving a dead pointer in the skill body.

## Validation

- Every bold skill name in `Related Skills` must resolve to an installed skill.
- Every wrapper or alias skill referenced in `Related Skills` must keep a live `overlay_of` target.
- If a name fails either check, remove it from `Related Skills` and replace it with plain guidance or backlog tracking.
