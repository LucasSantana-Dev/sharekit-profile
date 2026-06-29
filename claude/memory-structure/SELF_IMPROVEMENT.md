# Memory promotion & self-improvement protocol

> Extends `README.md` / `MEGABRAIN.md` with the **promotion ladder**, **staleness
> scoring**, **PreCompact re-injection contract**, and **nightly distill**.
> These four mechanisms turn the file-based memory from *knowledge persistence*
> into a **closed self-improvement loop** (observe → evaluate → optimize) that
> makes the harness improve with use across any model.

The research basis is the Wave-4 self-improvement cluster (borghei context-engine
SKILL, agentic-stack auto_dream, forge SessionEnd mining, lumos MemorySynthesizer,
SkillForge TD(λ) Q-values) plus the Stanford Meta-Harness result: **harness design
is the #1 performance lever, more than model choice**. Knowledge persistence
(saving notes) is not a closed loop — there is no measurement, no validation, and
no rollback. The protocol below is the closed loop.

---

## 1. The promotion ladder

A fact moves up tiers only when it earns it. The ladder is a ratchet, not a
dump: one-off noise dies at the lowest tier; repeats promote.

| Tier | Location | When a fact lands here | Loaded how |
|------|----------|------------------------|-----------|
| **T0 scratch** | `.harness/runtime/trajectory.jsonl` | Every tool call (auto, by the trajectory hook) | Never — distilled, not loaded |
| **T1 candidate** | `.harness/runtime/pending-distill.jsonl` → `.harness/forge/` | SessionEnd flush stages the session for mining | Never — pending review |
| **T2 working** | `memory/working-<session>.md` | A fact appears **1×** and is mined by the distill | Current session only |
| **T3 session** | `memory/<fact>.md` (tagged `status/active`) | A fact appears **2-3×** across sessions | On-demand via `recall` |
| **T4 cross-session / CORE** | `memory/CORE.md` | A fact is referenced across many sessions or is a hard rule | **Always loaded** (SessionStart + PostCompact re-inject) |
| **T5 domain KB** | megabrain `graphs/<project>/` or a project KB | A fact is domain knowledge (not project-specific) | On-demand via RAG |

**Promotion rule:** never write directly to T3+. Facts enter at T1/T2 from the
distill and promote upward by repetition + host-agent review. Demotion is the
reverse: a fact that stops being referenced decays (see §2) and eventually
archived via `status/archived` (never deleted — history is retained for
non-Markovian search).

This mirrors agentic-stack's `auto_dream.py` (stages candidates mechanically) +
`graduate.py`/`reject.py` (host-agent review with **required rationale**).
Rubber-stamping is structurally impossible: graduation without a rationale is
rejected.

---

## 2. Staleness scoring

Every T3+ fact carries staleness fields in its frontmatter:

```yaml
metadata:
  last_verified: 2026-06-29     # date a named file/flag was confirmed to still exist
  change_frequency: low          # low | medium | high — how often the underlying truth shifts
  confidence: 0.8                # 0.0-1.0 — evidence strength (auto: 0.7+ promotes)
```

**Staleness score** `S = f(last_verified, change_frequency, confidence)`:

- `age_days = today - last_verified`
- `half_life` by `change_frequency`: low=180d, medium=60d, high=14d
- `decay = 0.5 ^ (age_days / half_life)`
- `S = confidence * decay`  (range 0.0-1.0)

A fact with `S < 0.3` is flagged **stale** — the agent must re-verify the named
file/flag before acting on it (this already exists in `README.md`'s "treat
recalled memories as background context… verify a named file/flag still exists
before acting on it"; the score makes that check **mechanical**, not advisory).

Context-rot detection (context-engineering-handbook pattern #33): the distill
surfaces facts whose `S` dropped sharply since last session so the agent can
re-verify or archive them.

---

## 3. PreCompact re-injection contract

Compaction is the moment the model loses the most context. The
`hooks/reinject-compact.sh` PostCompact hook re-injects `CORE.md` (T4) back
into the session so hard rules, identity, and priorities survive compaction.
This is what makes the harness behave **consistently across any model call** —
the always-true core is never lost to compaction.

Contract:
- The hook re-injects only T4 (CORE). T3 is on-demand by `recall`, not
  auto-injected (mass re-injection would re-bloat the context).
- If no `CORE.md` is found, the hook logs a `postcompact-no-core` event to the
  trajectory so the distill can flag the gap.
- The re-injected block ends with a "verify against the source file" note so the
  agent treats it as background context, not freshly-verified truth.

---

## 4. Nightly distill (auto_dream → graduate/reject)

The distill is the **observe → evaluate** bridge. It runs nightly (or on
demand) and mines the trajectory log for candidate learnings.

```
.harness/runtime/trajectory.jsonl   (T0 — every tool call)
        ↓ SessionEnd flush
.harness/runtime/pending-distill.jsonl  (T1 — staged sessions)
        ↓ distill (nightly / `distill scan --now`)
        cluster + heuristic prefilter (≥3 content words, dedupe, decay)
        ↓
.harness/forge/<date>-forge.md      (T1 candidates, confidence-scored)
        ↓ host-agent review (NEVER unattended)
        graduate.py --rationale "…"   →  memory/<fact>.md  (T3)
        reject.py   --reason "…"       →  decision history retained
        reopen.py                      →  requeue
```

**26 lesson patterns** (from forge's `uncaptured-lesson-patterns`): decisions
("decided to"), learnings ("learned that"), failures ("failed because"),
patterns ("always do X"), each with a base confidence weight (0.7-1.0).

**Hard rules for the distill:**
- The distill **stages**; it never mutates semantic memory directly.
- Graduation requires `--rationale` (no rubber-stamping).
- Rejected candidates retain full decision history so recurring churn is
  visible, not fresh.
- Auto-promote is allowed **only** when confidence ≥ 0.7 AND the fact has ≥2
  citations across sessions — otherwise it stays a candidate.
- All graduated facts get the staleness fields (§2) on write.

---

## 5. The evaluate gate (P1 — the optimize half)

The promotion ladder + distill are the **observe** half. The **optimize** half
closes the loop with a measurable signal:

- **with-skill vs no-skill baseline** (selftune `baseline`): run a task with and
  without a skill/prompt/hook; gate on measurable lift.
- **constraint gates**: tests pass, size limits (skills ≤15KB), cache
  compatibility (no mid-conversation changes), semantic preservation.
- **auto-rollback on regression**: if a graduated change drops a metric, revert
  automatically (selftune `watch`, Distill-Agent auto-rollback).
- **all edits human-reviewed via PR**: evolved variants never commit directly
  (hermes-evolution guardrail #5).

The gate is **not** a dependency to adopt today — start local (zero deps,
matches the repo's no-cloud posture). Wire the proposer only once telemetry
+ the eval gate exist; a proposer without held-out eval is just guesswork
(the explicit lesson from selftune vs "agents that save notes").

---

## 6. Evaluator ≠ agent

The judge and the player stay separate. Evaluators are **immutable anchors**
(lumos, gearbox, auto-harness) — they never ship inside a harness package, so
the harness can never grade its own homework. This is why the distill stages
and the host agent (a different session/context) graduates: the reviewer is
not the implementer.

---

*This protocol is what makes the harness improve with use. Without it, memory
is persistence; with it, memory is a flywheel.*
