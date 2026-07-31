# evals/routing — skill-routing regression gate

LLM-behavioral eval gate for the harness's skill catalog. Complements the
deterministic hook gates (`hooks/eval-*.sh`, bats): this one replays routing
tasks through a pinned model and fails when accuracy regresses.

Methodology: gate on **aggregate accuracy**, never per-skill at small n; ground
truth mined from real session logs and **human-verified**; frozen baseline,
fingerprints in `.harness/manifest.json` make baseline/dataset drift
CI-detectable.

## Layout

- `router_eval.py` — replays tasks through a pinned OpenRouter model against
  the skill listing. Gate: accuracy must not drop >5pp below baseline.
- `dataset/routing_v0.jsonl` — 18 mined, human-verified routing tasks.
- `dataset/routing_authored_v0.jsonl` — 22 authored tasks: coverage for
  high-traffic skills + 4 negative-routing cases (`expected: none`).
- `baseline/routing_baseline.json` — the frozen reference run.
- `extract_episodes.py` — ground-truth GENERATOR for teams (see below).
- `build_dataset.py` — distills episodes into a versioned dataset.

## Usage

```bash
python3 router_eval.py --validate-only   # offline schema/baseline check (CI)
python3 router_eval.py                   # run + gate (needs OPENROUTER_API_KEY)
python3 router_eval.py --set-baseline    # after an INTENTIONAL routing change
```

- Skill listing defaults to this repo's `claude/skills/` + `skills/`. Override
  with `--skills-dir PATH` (repeatable) or `SKILLS_DIRS` (colon-separated) to
  gate a live install instead.
- Model is pinned via `ROUTER_EVAL_MODEL` (default `moonshotai/kimi-k2.6`).
  **Changing the model invalidates the baseline** — set a new one and record why.
- The shipped baseline (0.944 @ 18 scored tasks, 2026-07-30) was measured
  against this repo's curated catalog (49 skills). Tasks whose expected skill
  is **not in the listing under test** are reported as SKIP and excluded from
  the gate denominator — the gate measures routing quality on the catalog it
  runs against, not catalog coverage. 22/40 shipped tasks skip on this repo
  because the curated catalog intentionally omits skills like `deep-research`
  and `code-review`; extending the catalog automatically re-covers them.
- `OPENROUTER_BASE_URL` overrides the API base (test fixture uses this).

## Generating your own ground truth (teams)

The shipped mined tasks came from one operator's sessions; treat them as
portable coverage, not your team's truth. To build team-local ground truth:

```bash
CLAUDE_PROJECTS_DIR=/path/to/your/session/logs python3 extract_episodes.py
python3 build_dataset.py     # distills episodes.jsonl -> dataset/routing_v0.jsonl
# then HUMAN-REVIEW every task, sanitize personal paths/names, commit
```

`episodes.jsonl` contains real prompts — it is gitignored; never commit it.
Mine from logs older than your freeze date; the held-out refresh comes from
sessions after it (temporal split, anti-contamination).

## Contamination control

- The eval set is frozen; no optimization loop (GEPA etc.) may tune skill
  descriptions against these tasks. Build a held-out set before optimizing.
- The replay simulates routing with a single model call; the real harness
  routes with the full system prompt. Divergence is expected: the gate guards
  *changes* (description edits, listing structure), not absolute quality.
- 40 tasks → ±8pp margin at 95% CI. The gate fires on >5pp drops; treat
  single-task misses as triage pointers, not verdicts.

## Known limits (v0)

- Routing is the only archetype. Autonomy-tier, format-compliance, and
  end-state archetypes need harness-in-loop execution (Phase 0.5).
- `dataset/routing_v0.jsonl` task `rt-003` was sanitized for publication
  (personal path removed); flagged with `"sanitized": true`.
