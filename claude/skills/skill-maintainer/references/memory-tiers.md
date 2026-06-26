# Memory Tiers

Use one tier per skill.

## `stateful`

Use for skills that maintain queue state, resume work, watch CI, sync memories, manage operational cycles, or depend on durable repo history.

Requirements:
- Read memory before acting.
- Write back durable observations after meaningful work.
- Document what is worth persisting.

## `contextual`

Use for skills that benefit from existing project or workflow context, but do not need default writeback.

Requirements:
- Read memory when repo, product, or workflow history affects correctness.
- Only write memory if the skill changed policy or established a durable convention.

## `ephemeral`

Use for one-shot generation or narrow transformations where memory does not improve correctness.

Requirements:
- No default memory reads or writes.
- Only mention memory if the workflow explicitly asks for it.
