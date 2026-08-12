# dev.to (technical deep-dive, not in original Day 1-4 script)

Not scripted in launch-plan.md's launch week (that's Show HN/Reddit/X/awesome-list).
This is a Layer-1-owned technical piece for dev.to's audience, who want mechanism,
not positioning. Publish anytime post-launch, ideally after the demo clip exists
(Walk phase) so it can embed the real gate output instead of describing it.

## Title

How we gate AI agent *behavior* in CI, not just code

## Body

Most CI pipelines gate what code does. Nothing gates what an agent is allowed
to do, or whether a config change silently made it worse at picking the right
tool for a task. We built that gate for sharekit and it's simpler than it
sounds.

### The problem

Agent config (skills, hooks, routing logic) changes constantly, and none of
it is covered by a type checker or a unit test. A regex tweak in a routing
hook can silently make the agent pick the wrong skill for a task, and the
first sign of it is a user complaint weeks later.

### The gate

`evals/routing/README.md` in sharekit runs 40 frozen routing-task files
against a pinned OpenRouter model on every PR. Offline validation always
runs (`--validate-only`, no key needed); the full regression check runs when
`OPENROUTER_API_KEY` is configured, and fails CI on >5pp accuracy drop against
a fingerprinted baseline.

Why 40 frozen tasks and not a live curriculum? Because the fixed-catalog
approach is deliberate: reproducibility over recency. A frozen set means a
regression is *always* a regression, not "the eval also changed."

### The part that isn't visible from the gate

The gate's shape (small-n statistical gating, a fixed task catalog, a pinned
baseline) isn't arbitrary. It's downstream of an actual embedding/RAG research
program: bake-offs across e5/bge/jina embedding models with Matryoshka
dimension-truncation trials, a distilled-reranker-vs-RRF ablation that
measured RRF winning at the label scale this system runs at, and a
deliberately reproduced circularity-trap failure (a ranker validating itself
against its own outputs) characterized before guarding against it.

None of that shows up in the README. Full writeup: `docs/ml-rigor.md` in the
repo, if you want the methodology instead of the summary.

### Try it

```
npx @lucassantana/sharekit install <your-repo>
```

Gate fires on the next PR that touches routing config. Repo: [link]

## Send checklist

- [ ] Publish after the demo clip exists (Walk phase), embed or link it
- [ ] Cross-post link to r/ClaudeAI comments if the original Reddit post is still active
- [ ] Tag: ai, opensource, devtools, testing
