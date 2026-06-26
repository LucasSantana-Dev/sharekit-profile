# Loop Cost Guide

Token estimates for common loop patterns. Use these during Phase 0 goal
characterization to set user expectations.

## Cost tiers

| Tier | Tokens per run | Typical use |
|---|---|---|
| Quick | < 50K | Single-agent, focused task, 1-2 verify cycles |
| Medium | 50K–500K | Single-agent with retries, or small fleet (2-3 agents) |
| Heavy | 500K–2M | Fleet loop with multiple specialists + subagents |
| Very heavy | 2M+ | Daily fleet loop, large codebase, many parallel agents |

## Per-component costs (rough estimates, Sonnet 4.x)

| Component | Tokens |
|---|---|
| SKILL.md + project context load | 5K–20K |
| One discover pass (Explore agent, medium repo) | 15K–40K |
| One execute pass (coding, 1-3 files) | 10K–30K |
| One verify pass (critic agent) | 5K–15K |
| One retry/iterate cycle | 10K–25K |
| Fleet orchestrator coordination | 10K–30K |
| Each specialist agent in fleet | 20K–80K each |
| Memory read + write | 2K–5K |

## Example loop cost estimates

**Coding loop (single-agent, one bug fix, 2 retries):**
- Context load: 15K
- Discover: 20K
- Execute × 3: 60K
- Verify × 3: 30K
- Total: ~125K (medium tier)

**Research loop (single-agent, 3 sources, 1 retry):**
- Context: 10K
- Discover (search): 25K
- Execute (synthesize): 20K
- Verify (critic): 10K
- Retry: 15K
- Total: ~80K (medium tier)

**Daily audit loop (fleet, 3 specialists):**
- Orchestrator: 20K
- 3 Explore specialists × 40K: 120K
- Critic gate: 20K
- Memory write: 5K
- Total: ~165K (medium tier)

**Full feature build loop (fleet, 4 specialists + subagents):**
- Orchestrator: 30K
- Research specialist: 60K
- Engineering specialist + 2 subagents: 200K
- QA specialist + subagents: 150K
- Critic review: 30K
- Total: ~470K (approaching heavy tier)

## Cost control patterns

1. **Closed loops** cost 30–50% less than open loops — bounded paths mean fewer
   exploratory dead ends

2. **Skip-if-fresh gate** — if prior run is < N days old and passed, skip
   discover/plan and go straight to verify. Saves 40–60% of token cost per run.

3. **Scope limiting** — constrain discover to specific files/modules rather than
   whole repo. Saves 50–80% on large codebases.

4. **Parallel vs sequential** — parallel agents cost the same total tokens but
   finish faster. Use parallel for independent workstreams.

5. **Escape hatch tuning** — 3 retries is usually enough. More than 5 retries
   without progress is almost always a design problem, not a token problem.

6. **Haiku for mechanical phases** — discovery/search phases that just grep or
   list files can use claude-haiku-4-5 instead of Sonnet. 10× cheaper per token.
