# Compatibility Wrappers

Use this reference when an older public skill name still needs to exist next to a newer canonical skill.

## Wrapper goals

- keep the old name discoverable,
- route quickly into the canonical workflow,
- preserve only real legacy delta,
- avoid maintaining two full implementations.

## Minimum wrapper contents

- a trigger-rich description,
- `metadata.overlay_of` pointing to the canonical sibling,
- `Use When` and `Do Not Use When` boundaries,
- a short workflow that starts with the canonical skill,
- references for any retained legacy notes.

## Good candidates

- legacy names that appear in old docs,
- transitional names that users still ask for,
- aliases that carry a small but real environment delta.

## Bad candidates

- two full skills that differ only by wording,
- wrappers that secretly introduce new canonical behavior,
- wrappers that never route to the canonical skill.
