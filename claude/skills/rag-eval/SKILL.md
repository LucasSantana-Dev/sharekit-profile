---
name: rag-eval
description: |
  Run retrieval regression gate (hitgate) against current repo state vs frozen baseline.
  Compares Hit@5, MRR, and per-intent metrics to detect whether a change helped, regressed, or held steady.
  Use when (1) shipping changes to ragcore/retrieval code, (2) validating retriever retuning before merge,
  (3) measuring whether a refactor affected search quality (fast / no-regression gate before commit).
metadata:
  owner: evidence-first-rag
  tier: validation
  gate: retrieval-regression
triggers:
  - rag-eval
  - retrieval regression gate
  - check if changes hurt search
  - validate retriever quality
  - is it safe to ship retrieval changes

---

# /rag-eval

Run the retrieval regression gate against the current repo state and report whether a recent change helped, hurt, or held steady.

## When to invoke

- User runs `/rag-eval` or `/rag-eval <label>`
- User has changed files under `ragcore/`, `hitgate/`, or retrieval config and is about to commit or push
- User asks "did this change affect retrieval quality?" or "is it safe to ship?"

## Steps

### 1 — Determine the label

Use the argument if provided, otherwise use `rolling`.

**Done when:** Label is set in memory (or defaulted to `rolling`).

### 2 — Run the gate

```bash
bash hitgate/check.sh <label>
```

Set env vars if configured for a non-default corpus or retriever (see setup guide in references/setup-guide.md):

```bash
RAG_SOURCE_ROOTS="..." RAG_EVAL_DATASET="..." RAG_EVAL_BASELINE="..." EVAL_EXTRA_FLAGS="..." \
  bash hitgate/check.sh <label>
```

If the command exits non-zero AND no baseline file exists at the configured path, you are **BLOCKED: no baseline at [path] — cannot proceed**. See step 4 for recovery path.

**Done when:** `hitgate/<label>.verdict.json` exists and is readable.

### 3 — Read the structured verdict

```bash
cat hitgate/<label>.verdict.json
```

**Done when:** Verdict object is parsed (verdict field is one of: `pass`, `improvement`, `regression`).

### 4 — Report in plain language

**Pass** (`verdict: "pass"`):
> Gate passed. Hit@5 held [base → current]. MRR [base → current]. [Note any improvement in Hit@1 or MRR if `improvements` list is non-empty.]

**Improvement** (`verdict: "improvement"`, `refreeze_recommended: true`):
> Gate passed and Hit@5 improved [base → current, +Xpp]. The frozen baseline is now stale in the positive direction — consider re-freezing:
> ```bash
> cp hitgate/<label>.json hitgate/baseline.example.json
> ```

**Regression** (`verdict: "regression"`):
> Regression: [for each item in `regressions`, state scope + metric + delta in pp]. Next: run the eval in verbose mode to see which cases are now missing:
> ```bash
> python -m hitgate.run --verbose --label <label>
> ```
> Then inspect the MISS rows for the affected intent class.

**No baseline found** (baseline path does not exist):
> No baseline at [path]. To create one, see the first-time setup section in references/setup-guide.md. Then re-run `/rag-eval` to compare against it.

**Done when:** User has received the verdict summary and any actionable next steps.

### 5 — Surface failing cases on regression

Read `hitgate/<label>.json` → `per_case`. Filter to entries where `hit_rank` is null and `intent` matches the regressed class. Show up to 3 as:

```
MISS  intent:indexing  "how does the chunker handle AST symbols"  → expected: chunkers.py
```

This saves the developer from opening the JSON file manually.

**Done when:** Up to 3 failing cases are surfaced (or "none" if all recovered).

## Portability

See `references/setup-guide.md` to adapt for your own retriever, corpus, and baseline.

## Known-good external baselines

See `references/calibration.md` for validation baselines from 7 corpora used to set performance expectations for a new corpus.
