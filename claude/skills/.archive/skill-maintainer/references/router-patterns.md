# Router Patterns

Use this pattern when a higher-level skill should choose or sequence narrower execution skills instead of duplicating them.

## Use the pattern when

- the public skill is useful as the strategy or orchestration entrypoint,
- narrower skills already exist for execution,
- the real value is selecting the right checks, order, and evidence model.

## Router contract

- Keep the public skill name and describe the orchestration job clearly.
- Use `metadata.overlay_of` only when one primary canonical executor exists; document the other routed skills in the body or references.
- Keep `SKILL.md` focused on:
  - when the router should trigger,
  - when to route to a narrower skill directly,
  - how to choose and order the narrower skills,
  - what combined evidence to return.
- Move large catalogs and checklists into `references/`.

## QA router example

A QA router may point to `quality-gates` as the primary executor while still routing to `backend-testing`, `security-audit`, and `security-scan` when the problem is more specific.

## Avoid

- restating the full body of each narrower skill,
- pretending the router itself runs all execution steps,
- using a router when one narrow skill is clearly sufficient.
