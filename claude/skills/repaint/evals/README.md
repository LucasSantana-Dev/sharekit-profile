# repaint evals

31 evals in `evals.json` (canonical `assertions`-as-plain-strings format; fixtures in `files/`), runnable by [`agent-skills-eval`](https://www.npmjs.com/package/agent-skills-eval). They check that changes to the skill don't regress the six places a capable model gets frontend wrong unaided.

## Run

```bash
# Validate the skill + count evals WITHOUT spending (refused endpoint):
NOKEY=x npx agent-skills-eval@0.1.1 . --strict --base-url http://127.0.0.1:1/v1 --api-key-env NOKEY

# Real run (with-skill only; drop --baseline since the +19–26pp delta is already known):
OPENROUTER_API_KEY="$(cat ~/.repaint-openrouter.key)" npx agent-skills-eval@0.1.1 . \
  --target z-ai/glm-4.6 --judge openai/gpt-4.1-mini \
  --base-url https://openrouter.ai/api/v1 --api-key-env OPENROUTER_API_KEY \
  --concurrency 4 --workspace <dir>
```

## The delta-gate (how to read a run)

The source repo's `baseline.json` (not shipped in this profile) holds a committed reference run (mean **88.4%**, noise band **4.0pp**, measured 2026-06-23 over 3 runs). Treat the evals as a **regression gate on the delta**, not a certificate of absolute quality. Six rules:

1. **Advisory, not hard-blocking.** The pipeline is doubly stochastic — the model *generates* and an LLM *judges*. A hard CI fail would flap. A run that drops within the noise band is noise, not a regression.
2. **Gate on the delta, not the absolute.** Never claim "88% = good." Claim "−X pp vs baseline = something broke." The absolute number is judge-optimistic by construction (auto-scored, no hand-labeled holdout).
3. **Pin the judge.** Pass-rate is only comparable across runs with the *same* judge model. `baseline.json` records `judge_model`; re-baseline if you change it.
4. **Noise floor first.** The measured band is **4.0pp** (stdev 1.67pp across 3 runs). Ignore aggregate wobble within ±4pp.
5. **Ignore the tool-stall artifact.** A lone `0/N` on an inspect/fixture eval (observed: `eval-4 = 0/6` in one of three runs) is a single-shot / tool-less harness limitation — the skill correctly emits a tool call the harness can't run. It is **not** a skill regression. Judge per-eval health by **majority across runs**, never a single run.
6. **Re-baseline on intentional change.** When a change deliberately moves scores (or the eval set itself changes) and the new scores are accepted, commit a fresh `baseline.json` with a note saying why.

## Plateau caution

Past ~91%, *adding rules hurts generalization* (the skill is already large). The lever is **prominence** — surfacing buried reference guidance up into the SKILL.md gates — **not** adding new rules. Apply this to every SKILL.md edit.
