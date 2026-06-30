# Harness research synthesis

> Deep-research survey of 52 repos across 5 categories (harness/agent
> frameworks, RAG/context engineering, fine-tuning/eval, agentic coding,
> self-improving/evolutionary). This doc folds the cherrypicked findings into
> concrete, prioritized integration points for the sharekit harness and names
> the next implementation phase (P8).

## Source

- Survey run: 52 repos, 5 categories.
- Deliverable: 10 cherrypicked recommendations, 5 resolved contradictions,
  7-item do-not-adopt list.
- Primary levers targeted: 4 (context budget + staged disclosure),
  5 (retrieval gates with confidence thresholds), 6 (reasoning scaffolds),
  with additional leverage in 2, 7, and 8.

## Findings at a glance

The survey confirms that sharekit already implements the highest-leverage
patterns most lean harnesses converge on: a progressive-disclosure skill index
(P4 `skill-index.sh`), a deterministic orchestration substrate (P4
`dispatch.sh`), an eval bench with a seen/heldout split (P3 `eval-tasks.sh`),
and a non-Markovian history store (P2 `history.sh`). The gaps the survey
surfaces are in the *retrieval postprocessing chain*, *inline reasoning
scaffolds*, and *checklist-style pre-completion gates*.

## Top 10 cherrypicked recommendations (prioritized for P8)

### 1. Binary-checklist verification gates (lever 8)
- **From**: awesome-cursorrules collections
- **Mechanism**: Security/Quality/Testing/Performance/Documentation gates, each
  a set of binary checkboxes, blocking if any item fails.
- **sharekit integration**: new `hooks/checklist-gate.sh` (PreToolUse or Stop)
  that enforces binary self-verification before a task is marked complete.
- **Why it fits**: makes lever 8 (pre-commit deterministic validators)
  concrete; catches silent quality regressions before the eval gate.
- **Effort**: 2-3 days.

### 2. LongContextReorder postprocessor (lever 4)
- **From**: LlamaIndex
- **Mechanism**: reorders retrieved nodes to place crucial data at the
  start/end of the context window, addressing "lost in the middle."
- **sharekit integration**: add a reorder postprocessor to the recall pipeline
  (`autorecall-hook.sh` / the RAG recall path) that reorders injected context
  before injection.
- **Why it fits**: direct improvement to lever 4; models attend better to
  start/end of context. sharekit already injects `# Knowledge graph context`
  — this just reorders it.
- **Effort**: 1-2 days.

### 3. Smart Approvals prefix-rule learning (lever 2)
- **From**: OpenAI Codex CLI
- **Mechanism**: when a command is escalated for approval, the system
  proposes a `prefix_rule` pattern that persists so similar commands
  auto-approve in future.
- **sharekit integration**: extend `hooks/policy-gate.sh` with a persisted
  rules file that learns from approval decisions (ALLOW/DENY/REQUIRE_APPROVAL
  verdicts already exist there).
- **Why it fits**: reduces approval friction over time without compromising
  safety — builds on the existing tamper-evident ledger.
- **Effort**: 2-3 days.

### 4. Inline retry-with-reflection (lever 6)
- **From**: Reflexion (NeurIPS 2023)
- **Mechanism**: on eval failure, generate a self-reflection (what went
  wrong), store in episodic memory, retry with the reflection as context.
- **sharekit integration**: add a reflection step to the agent execution
  loop after eval failure — generate a reflection, store in trajectory +
  memory, retry up to N times. Distinct from the batch flywheel
  (`propose.sh`); this is per-task.
- **Why it fits**: immediate quality improvement on failed tasks without
  waiting for the full cycle.
- **Effort**: 2-3 days.

### 5. Transcript scanners (lever 7)
- **From**: inspect-ai
- **Mechanism**: post-hoc analysis of trajectory logs for failure patterns
  (misconfigured environments, refusals, evaluation awareness, hallucination).
- **sharekit integration**: new `hooks/transcript-scanner.sh` that runs after
  `trajectory-log.sh`, scanning for systemic failure patterns the per-task
  eval scores don't catch.
- **Why it fits**: sharekit already logs every tool call to
  `.harness/runtime/trajectory.jsonl`; this adds a post-hoc analysis pass.
- **Effort**: 3-4 days.

### 6. Red-team adversarial test generation (lever 8)
- **From**: promptfoo
- **Mechanism**: auto-generate adversarial test cases (prompt injection,
  jailbreaks, excessive agency, hallucination, PII leaks).
- **sharekit integration**: add `evals/red-team/` with adversarial tests
  against skill prompts; extend `eval-tasks.sh` to carry an adversarial split.
- **Why it fits**: finds security vulnerabilities in skill prompts before
  deployment.
- **Effort**: 4-5 days.

### 7. Memory blocks with char budgets (lever 4)
- **From**: Letta/MemGPT
- **Mechanism**: structured, agent-managed sections of the context window
  with per-block char limits and self-edit capability.
- **sharekit integration**: add a memory block abstraction
  (`claude/memory-structure/blocks.yaml`) with labels, limits, read-only
  flags; extend `context-guard.sh` to enforce the budgets.
- **Why it fits**: explicit per-section budgeting of the context window.
- **Effort**: 3-4 days.

### 8. "Dreaming" (sleep-time compute) (cross-cutting)
- **From**: Letta/MemGPT
- **Mechanism**: background subagents review recent trajectories and write
  lessons into memory.
- **sharekit integration**: new `hooks/dream.sh` launched by `cycle.sh` after
  compaction events — a background pass that reviews recent trajectory logs
  and writes insights to memory. Distinct from the nightly `distill.sh`
  (which mines candidates for the proposer); this writes lessons directly to
  memory.
- **Why it fits**: inline learning between flywheel cycles.
- **Effort**: 3-4 days.

### 9. Textual gradient descent for prompt optimization (levers 6+7)
- **From**: TextGrad (Nature, March 2025)
- **Mechanism**: forward pass (agent execution) → loss (eval failure) →
  backward pass (LLM-generated criticism) → step (update prompt).
- **sharekit integration**: add a TextGrad-style optimization pass to the
  flywheel's distill/propose phase — use eval failures as loss, generate
  textual gradients, update prompts.
- **Why it fits**: automatic prompt improvement; complements (does not
  replace) the existing evolutionary proposer.
- **Effort**: 4-5 days.

### 10. ExpeL-style insight extraction (lever 6)
- **From**: ExpeL (AAAI 2024)
- **Mechanism**: gather success/failure experiences, extract cross-task
  insights via ADD/UPVOTE/DOWNVOTE/EDIT operations, inject insights into
  agent prompts at inference.
- **sharekit integration**: add an insight-extraction phase to the flywheel
  that maintains a curated insight list with confidence scores; inject into
  the proposer's non-Markovian context (`history.sh`).
- **Why it fits**: cross-task knowledge transfer.
- **Effort**: 4-5 days.

## Resolved contradictions

1. **Reflection vs forward-only** — adopt reflection for eval-gated tasks
   (failure clearly detectable), NOT for open-ended exploration. Make it
   opt-in per task type (recommendation #4 honors this).
2. **Code-as-action vs tool-call-as-action** — keep structured tool calls as
   the default (safety-first); allow code-as-action ONLY in a sandboxed mode
   behind the Codex-CLI two-axis safety model (sandbox × approval). Do NOT
   adopt code-as-action as default.
3. **Holistic vs component-level optimization** — component-level (DSPy/
   promptfoo style) for the regular flywheel cycle (tractable, debuggable);
   periodic holistic optimization (Symbolic Learning style) as a deeper, less
   frequent pass.
4. **Always-visible memory blocks vs retrieval-based memory** — hybrid:
   always-visible blocks for critical, frequently-needed info (with char
   budgets), retrieval-based for the long tail (CPU cache vs RAM).
5. **Automatic curriculum vs fixed eval catalog** — keep the fixed catalog
   (seen/heldout split) for regression testing; ADD an auto-curriculum
   generator that proposes new eval tasks. Auto-generated tasks go into the
   seen set after validation.

## Do-not-adopt list

1. **ADAS Meta Agent Search as a runtime** — requires executing untrusted
   model-generated code; violates the read-only/security posture; $300-500
   per run. Use only as inspiration for a constrained search space.
2. **Reflexion for all tasks** — fails on diverse/creative tasks; adds
   latency and tokens. Keep opt-in per task type with a max retry count.
3. **LangFuse/Phoenix as runtime dependencies** — breaks portability;
   conflicts with the no-external-runtime-dependencies posture. Adopt the
   PATTERNS (OTel-native tracing, observation-level evals) as native hooks,
   not as dependencies.
4. **Full graph-based memory (GraphRAG) as primary memory** — graph
   construction is compute-heavy and model-dependent. Use lightweight graph
   retrieval (LightRAG-style) for the temporal-KG; community detection only
   as an optional offline pass.
5. **Code-as-action as the default action space** — violates the security
   posture; validation is harder. Keep structured tool calls default.
6. **Voyager's automatic curriculum as the sole task source** — breaks
   reproducibility. Use as a SUPPLEMENT to the fixed catalog.
7. **promptfoo's `optimize` as the sole optimization method** — use an
   ensemble (TextGrad + DSPy + ExpeL). Adopt promptfoo's `--validation-split`
   pattern and red-team generation, not its single-method optimizer.

## Recommended P8 scope

P8 should target the three highest-leverage, lowest-risk recommendations that
build directly on existing hooks:

- **P8.1 — LongContextReorder postprocessor** (#2): 1-2 days, pure addition
  to the recall path, no new subsystem.
- **P8.2 — Binary-checklist verification gates** (#1): 2-3 days, new hook,
  lever 8 made concrete.
- **P8.3 — Transcript scanners** (#5): 3-4 days, builds on the existing
  trajectory log.

Recommendations #4 (inline reflection), #3 (smart approvals), and #9
(TextGrad) are higher-value but higher-risk and should follow in P9 once P8
validates the patterns. Recommendations requiring new abstractions (#7 memory
blocks, #8 dreaming) should be designed against the target architecture
(`docs/target-architecture.md`) before implementation.

## What sharekit already has that others are still building

The survey found sharekit is ahead on: non-Markovian full-history search
(`history.sh`), the held-out eval split (`eval-tasks.sh`), the deterministic
orchestration substrate (`dispatch.sh`), tamper-evident policy ledger
(`policy-gate.sh`), and isolated candidate gating (`trial-apply.sh` + `gate.sh
--proposal`). These are the load-bearing invariants and should not be
regressed by any P8+ change.
