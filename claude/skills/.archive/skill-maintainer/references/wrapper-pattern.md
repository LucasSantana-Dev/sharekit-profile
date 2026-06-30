# Thin Wrapper Pattern

Use this pattern when a public skill name should stay available but another skill owns the canonical deeper workflow.

## Use the pattern when

- a legacy skill name is still referenced by users or older docs,
- the overlap is real enough that silent divergence would create maintenance debt,
- removing the old name would break discoverability more than it would help.

## Wrapper contract

- Keep the public skill name and a trigger-rich description.
- Add `metadata.overlay_of` pointing at the primary canonical sibling skill.
- Keep `SKILL.md` focused on:
  - when this wrapper should still trigger,
  - when to route to the canonical skill,
  - what delta still matters here,
  - what evidence to return.
- Move any retained legacy notes into `references/` instead of duplicating the canonical skill body.

## Split-only vs thin wrapper

- Use **split only** when the skill remains the canonical entrypoint and just needs examples or variants moved out of `SKILL.md`.
- Use a **thin wrapper** when the public name should survive but the deeper workflow already belongs to a canonical sibling.
- Do not add wrapper semantics just because a skill is large.

## Avoid

- copying the canonical workflow line for line,
- allowing the wrapper to drift into a second canonical implementation,
- hiding the relationship from maintainers or future cleanup passes.
