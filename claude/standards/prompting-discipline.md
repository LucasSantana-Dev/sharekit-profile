# Prompting Discipline

Use a compact four-block structure for non-trivial work:
- Goal
- Method
- Constraints
- Validation

Prefer short, explicit, operational prompts over vague ambition prompts.
When prompting another agent or model, always specify the output shape and stop conditions.

## Reasoning scaffolds — the model-independence lever

**Why this is the highest-value rule here.** An explicit numbered procedure embedded in the
prompt is what makes the *output* depend on the *task* instead of on *which model* runs it. A
strong model self-scaffolds — it invents the missing steps. A weaker or cheaper model executes
what it is told and flails on what it is not. Writing the steps down closes that gap: research on
chain-of-thought / step scaffolding shows it lifts weaker models far more than strong ones
(indicative +35-40pp on multi-step reasoning, vs a small gain for frontier models). The harness
goal is productivity that does not change when the model does — scaffolds are how a prompt carries
that. Treat the model as an executor of the procedure, not the architect of it.

**When to scaffold (not every prompt).** Scaffold any prompt that (a) is delegated to a subagent,
(b) has ≥3 ordered steps, (c) has a correctness gate the model could skip, or (d) you would
re-explain if the result came back wrong. Skip it for single-step lookups, trivial edits, and
open creative work where steps would over-constrain.

### Scaffold template (delegated / subagent prompt)

```
Goal: <one sentence — the observable end state>
Steps (do in order, do not skip):
  1. <first concrete action — name the file/command/query>
  2. <next — reference the output of step 1 explicitly>
  3. <verification step — the check that proves the work, e.g. "run <cmd>; expect <result>">
Constraints: <what must NOT happen — scope bound, read-only, no new deps>
Output: <exact shape — JSON schema, file path, bullet list of N items>
Stop when: <success condition> | escalate if <blocker> instead of guessing.
```

The verification step (3) is non-optional: without an explicit "prove it" step, a weak model
reports success it did not achieve (the self-report overclaim failure). Bake the proof into the
procedure so the gate runs regardless of model judgment.

### Worked example

**Weak (ambition prompt, model-dependent):**
> "Improve the test suite for the auth module."

**Strong (scaffolded, model-independent):**
> Goal: raise auth-module branch coverage to ≥80% without changing production code.
> Steps: 1. Run `pytest --cov=auth --cov-report=term-missing`; list uncovered lines.
> 2. For each uncovered branch, write one test asserting the *behavior*, not the line.
> 3. Re-run coverage; confirm ≥80% and that all tests pass. Paste the final coverage line.
> Constraints: tests only — do not edit `auth/`. No network. No new deps.
> Output: the new test file path + the final `pytest --cov` summary line.
> Stop when coverage ≥80% and green; if a branch is untestable without refactor, list it and stop.

The second prompt produces nearly the same result whether run by a frontier or a cheap model,
because the procedure — including the coverage gate — lives in the prompt, not in the model's head.

### Pairs with the rest of the harness

- **Structured output** (schema-forced) is the scaffold for the *result*; numbered steps are the
  scaffold for the *process*. Use both for delegated analysis. (See `artifact-schema.md`.)
- **Phase gating** in composites is this same principle at the workflow level — the composite is a
  scaffold a weak orchestrator cannot skip. (See `composite-contract.md`.)
- **Read-only enforcement** via `agentType` makes "do not edit" structural, not a hope the model
  honors the constraint line. (See `agent-routing.md`.)
