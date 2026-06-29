---
name: three-layer-eval
description: "Three-layer skill quality evaluation (Static → LLM Judge → Monte Carlo). Layer 1: deterministic checks (frontmatter, triggers, size, links) in <2s. Layer 2: semantic eval across 4 dimensions using Haiku+Sonnet. Layer 3: 50-100 simulated runs for statistical reliability."
triggers:
  - skill eval
  - evaluate skill
  - skill quality
  - plugin eval
  - three layer eval
---

# three-layer-eval

Three-layer evaluation framework for skill quality assessment.

## Layer 1: Static Analysis (<2s)

Deterministic checks — fast, no LLM required.

### Checks

1. **Frontmatter completeness**
   - `name` present and matches directory name
   - `description` present, >20 chars, <200 chars
   - `triggers` array present, at least 1 trigger, each trigger >3 chars

2. **Trigger-phrase presence**
   - At least one trigger appears in the skill body (natural usage)
   - Triggers are not generic words ("help", "run", "do")

3. **Body size**
   - SKILL.md body <8KB (excluding frontmatter)
   - SKILL.md <150 lines
   - Total directory <50KB

4. **Reference link validity**
   - All relative links resolve to existing files
   - No broken anchors (#section links)

5. **Structural patterns**
   - Has clear "When to use" or trigger section
   - Has output/return format documented
   - No TODO or placeholder content

### Output

```
Layer 1: STATIC — PASS/FAIL
  frontmatter: OK
  triggers: OK (3 triggers, all appear in body)
  size: OK (4.2KB body, 87 lines)
  links: FAIL (1 broken: references/old-api.md)
  structure: OK
```

## Layer 2: LLM Judge (Haiku + Sonnet)

Semantic evaluation across 4 dimensions. Uses Haiku for fast scoring, Sonnet for nuanced cases.

### Dimensions

1. **Completeness** (0-10)
   - Does the skill cover its stated use cases?
   - Are edge cases documented?
   - Is the output format clear?

2. **Trigger-accuracy** (0-10)
   - Do triggers accurately predict when to invoke?
   - Are there false positives (triggers that match unrelated work)?
   - Are there false negatives (missing triggers for valid use)?

3. **Safety** (0-10)
   - Does the skill avoid destructive operations by default?
   - Are there guardrails for irreversible actions?
   - Does it respect the harness boundary (no project-specific imports)?

4. **Portability** (0-10)
   - Can the skill run in any repo?
   - Does it depend on specific tools or environments?
   - Are assumptions documented?

### Execution

```
Haiku pass: score each dimension 0-10 with brief justification
Sonnet pass: review Haiku scores, adjust if needed, provide detailed feedback
```

### Output

```
Layer 2: LLM JUDGE — avg 7.8/10
  completeness: 8/10 — covers main use cases, missing edge case X
  trigger-accuracy: 9/10 — triggers are precise, no false positives
  safety: 7/10 — has guardrails but missing checkpoint for operation Y
  portability: 6/10 — assumes tool Z is installed, should document
  
  Sonnet notes: The skill is solid but could benefit from explicit
  failure modes section. Trigger "fix bug" is too generic — consider
  narrowing to "fix test failure" or "fix build error".
```

## Layer 3: Monte Carlo Simulation (50-100 runs)

Statistical reliability testing via simulated invocations.

### Method

1. Generate 50-100 synthetic prompts that should/shouldn't trigger the skill
2. Run the skill's trigger-matching logic against each prompt
3. Measure:
   - **Precision**: % of triggered runs that were correct invocations
   - **Recall**: % of valid invocations that triggered the skill
   - **False positive rate**: % of triggered runs that were incorrect
   - **False negative rate**: % of valid invocations that didn't trigger

### Execution

```bash
# Generate test prompts
./skills/three-layer-eval/generate-prompts.sh <skill-name>

# Run simulation
./skills/three-layer-eval/simulate.sh <skill-name> --runs 100

# Analyze results
./skills/three-layer-eval/analyze.sh <skill-name>
```

### Output

```
Layer 3: MONTE CARLO — 100 runs
  precision: 0.92 (92/100 triggered runs were correct)
  recall: 0.87 (87/100 valid invocations triggered)
  false positive: 0.08 (8/100 triggered incorrectly)
  false negative: 0.13 (13/100 valid invocations missed)
  
  Confidence interval (95%): ±0.06
  
  Failure modes:
    - Prompt "debug this" triggers but is too generic (3 cases)
    - Prompt "fix test" doesn't trigger but should (7 cases)
```

## Combined report

```
SKILL EVALUATION: <skill-name>
================================

Layer 1: STATIC — PASS (1 issue)
Layer 2: LLM JUDGE — 7.8/10 avg
Layer 3: MONTE CARLO — precision 0.92, recall 0.87

OVERALL: GOOD (minor improvements needed)

Top 3 improvements:
1. Fix broken link: references/old-api.md
2. Narrow trigger "fix bug" → "fix test failure"
3. Add checkpoint for operation Y

Detailed findings: <attached>
```

## When to use

- Before merging a new skill
- Quarterly skill quality audit
- When a skill feels unreliable (false positives/negatives)
- After major skill refactors

## References

- Inspired by lm-eval-harness EvalResults schema
- Inspired by CodeWhale typed receipts
- See standards/typed-result-schema.md for output contract
