# Harness model-independence audit — 2026-06-26

**Goal.** Make harness quality *independent of the model running it*. Productivity should come from
the tools built around the model — deterministic hooks that enforce, RAG/memory that supply context,
skills/agents that encode procedure, and evals that gate regressions — so a cheaper or weaker model
produces nearly the same result as a frontier one. This report records what changed, the measured
"how much better," and the research behind each lever.

**North-star test for every change:** *does the outcome now depend on the task instead of on which
model is involved?* A strong model self-corrects, self-scaffolds, and notices its own broken output.
A weaker model executes what it is told. Every lever below moves a guarantee out of "the model
notices" and into "a script / a procedure / a structural constraint enforces it."

---

## Scoreboard (measured deltas)

| Dimension | Metric | Before | After | How measured |
|---|---|---|---|---|
| **Skills** | Won't-load skills (invalid-YAML + no-frontmatter) | **19** | **0** | `scripts/harness-skill-scorecard.py` |
| **Skills** | Structural score (consistent classification¹) | **92.1%** (220/239) | **100%** (239/239) | scorecard `structural_score_pct` |
| Skills | Invalid-YAML frontmatter (won't load) | 18 | **0** | scorecard `hard_breakdown` |
| Skills | No-frontmatter (won't register) | 1 | **0** | scorecard |

¹ The first raw scan reported 85.4% because it counted the 16 intentional `adt-*`/`plugin-*`
namespace-prefix skills (where dir name ≠ invocation name *by design*) as defects. Reclassifying
`name≠dir` as SOFT — to match the gate hook exactly — gives the honest apples-to-apples baseline of
**92.1%**. Either way the actionable count is the same: **19 genuinely-broken (won't-load) skills → 0.**
| **Hooks** | `skill-quality-gate.sh` enforcement | warn-only (exit 0) | **HARD-block** (exit 2) on invalid-YAML / unclosed-fence | hook source + 5 test cases |
| **Standards** | Standards reachable from CLAUDE.md index | 25 of 37 | **37 of 37** | index grep vs disk |
| **Standards** | `prompting-discipline.md` | 11-line stub | **reasoning-scaffold standard** (top weak-model lever) | file |
| **Agents** | Read-only analysis agents with Bash blocked | 0 | **3** (explore, critic, overengineering-auditor) | `disallowedTools` frontmatter |
| **Regression gate** | Automated catalog-quality drift check | none | **weekly** (run-diagnostics.sh §4b) | committed `scorecard-baseline.json` |

The structural score is the harness's first objective, model-independent quality number. It is
re-runnable (`python3 ~/.claude/scripts/harness-skill-scorecard.py`) and committed as a baseline, so
any future change that breaks a skill shows up as a negative delta in the weekly diagnostic.

---

## What changed, and why it's model-independent

### 1. Skill catalog: 19 won't-load skills → 0 (structural score 92.1% → 100%)
18 skills had **invalid-YAML frontmatter** — prose `description:`/`auto-invoke:` fields containing
unquoted `:` or `,` that broke the YAML parser, so the skill silently failed to load. 1 skill
(`task-start`) had no frontmatter at all (markdown `**Name**:` instead). Fixed by converting prose
scalars to folded block scalars (`>-`, needs no escaping) and adding real frontmatter.

*Model-independence:* an invalid-YAML skill loads for **no** model. This isn't a quality nudge — it's
a skill that wasn't in the catalog at all. Fixing it makes the catalog uniformly available regardless
of model. (Canonical `<github-user>/skills` 4a896c9; mirror `claude-env` 61b036a.)

### 2. skill-quality-gate.sh: warn-only → HARD-blocking floor
The PostToolUse hook was `exit 0` (printed a warning, saved anyway). Now it `exit 2`-blocks on the two
unambiguous-breakage checks — invalid YAML and unclosed code fence — and soft-warns the rest
(name≠dir, size, missing Done-when / stop-conditions / workflow). `SKILL_GATE_BYPASS=1` escapes for
intentional WIP.

*Model-independence:* a weaker model **cannot** ship a structurally-broken skill even if it doesn't
notice the breakage — the harness rejects the write. The guarantee moved from "model reviews well" to
"script enforces." (claude-env 541f1e7.) This is research lever #8 (pre-commit deterministic
validators: ~95% first-try-correct, ~1-5ms, model-agnostic).

### 3. Standards index: 25 → 37 reachable
12 standards existed on disk but were **not listed** in the always-loaded CLAUDE.md standards index —
including the 262-line `red-flags.md` anti-action catalogue, `naming-conventions.md`,
`dependency-injection.md`, `async-patterns.md`, `shell-secret-management.md`, and
`skill-catalog-topology.md`. They were invisible: nothing told an agent to load them. Each is now
indexed with a one-line "when to load" hint.

*Model-independence:* a strong model might stumble onto `red-flags.md`; a weak one never will without
a pointer. The pointer makes "load the right rule" deterministic instead of dependent on the model
guessing the file exists. (claude-env 7fd4505 — written to the tracked `config/CLAUDE.md` so the
next sync-pull can't revert it.)

### 4. prompting-discipline.md: stub → reasoning-scaffold standard
Expanded the 11-line stub into a standard for **numbered-step reasoning scaffolds** in delegated
prompts: a copy-paste template (Goal → ordered steps → mandatory verification step → constraints →
output shape → stop condition), a worked weak-vs-strong example, and the rule for *when* to scaffold.

*Model-independence:* this is research lever #6 — **the highest model-independence lever**.
Chain-of-thought / step scaffolding lifts weaker models far more than strong ones (indicative
+35-40pp on multi-step reasoning) because a strong model self-scaffolds and a weak one doesn't. The
mandatory verification step specifically kills the self-report-overclaim failure (agent reports
success it didn't achieve). The procedure lives in the prompt, not in the model's head. (Canonical
skills f67eaa1; mirror a577f94.)

### 5. skill-quality-spec.md: + Model-Independence Gate
Added a section framing the deterministic HARD/SOFT floor (the gate hook + the scorecard) as the
layer *beneath* the 13 judgment-based quality points. The 13 points are the ceiling a capable
reviewer reaches; the structural gate is the floor that holds regardless of the reviewing model.

### 6. Read-only analysis agents: Bash blocked by construction
`explore`, `critic`, `overengineering-auditor` now list `Bash` in `disallowedTools` (verified safe:
these three have zero shell dependence in their bodies; the other read-only agents legitimately need
git/grep/eval so were left). Combined with `agentType`-based dispatch, "this agent does not edit /
shell out" is now structural, not a hope the model honors a "read-only" line in its prompt.

*Model-independence:* CLAUDE.md already mandates analysis subagents be write-incapable by
construction — a prompt saying "read-only" has been violated in practice. Removing the tool removes
the possibility for every model. (claude-env 541f1e7.)

### 7. Scorecard regression gate (weekly)
`run-diagnostics.sh` §4b now runs the scorecard, compares `structural_score_pct` against the
committed `scorecard-baseline.json` (100%), and writes `harness_scorecard_auto.md` to memory —
flagging any **newly-broken** skills as a REGRESSION and reindexing the report into RAG. Tested with a
simulated regression (correctly reported `-0.8 [REGRESSION]` + the 2 newly-broken skill names).

*Model-independence:* this is research lever #7 — the harness previously had **no self-regression
gate** (the single biggest gap). Drift now gets caught by a script on a schedule, not by a model
happening to re-audit. (claude-env 8a8677a.)

---

## Research grounding

Eight techniques from a deep-research synthesis on model-independent agent harnesses, ranked by
model-independence leverage. Levers actioned this session in **bold**:

1. Schema validation / structured-output forcing (+~35-45pp on structured tasks)
2. **Deterministic lifecycle hooks** (compliance ~97% vs ~72% narrative) — gate hardening
3. Workflow DAGs + phase gating (weak models are executors, not architects)
4. Context budget + staged disclosure (3-5× effective horizon)
5. Retrieval gates with confidence thresholds (-40% calls)
6. **Reasoning scaffolds / numbered steps** — *highest* lever; CoT lifts weak models ≫ strong — prompting-discipline.md
7. **Component eval gates / regression baselines** — the harness's biggest gap — scorecard weekly gate
8. **Pre-commit deterministic validators** (~95% first-try, ~1-5ms, model-agnostic) — gate hook

Confidence: levers 1,2,3,7,8 very-high (established / Anthropic guidance); 4,5,6 high. Cited
percentages are indicative, not benchmarked on this harness.

---

## Dimension audit summary

The goal named six audit dimensions. Status:

| Dimension | Finding | Action |
|---|---|---|
| **Skills** | 18 invalid-YAML + 1 no-frontmatter (genuinely broken) | Fixed → 100%; gate now blocks recurrence |
| **Hooks** | quality-gate was a no-op warner | Hardened to HARD-block |
| **Agents** | 3 read-only agents could still shell out | Bash blocked by construction |
| **Standards** | 12 orphan standards unreachable from index; prompting-discipline a stub | Wired all 12; rewrote scaffold standard |
| **Patterns** | 8 patterns (7/8 concrete templates); 1 imprecise anchor; 3 model-independence patterns missing | Fixed anchor; added 3 patterns (8 → 11) |
| **MCP servers** | Healthy fallbacks; 0% manifest adoption (checker validates nothing) | Documented; declaration recommended as future work |

### Patterns audit
Read-only audit of `skill-patterns.md` (the copy-paste template library). Findings:
- **8 named patterns**, 7 of 8 concrete copy-paste templates (87.5%) — already strongly
  model-independent (templates remove formatting variance across models). No structural defects, no
  unclosed fences, no truncation.
- **1 imprecise cross-reference** (line 119: cited `§Verified RAG`, actual heading is "Verified RAG /
  knowledge invocation patterns") → fixed.
- **3 model-independence gaps** — no copy-paste pattern for the named levers: schema-forced
  structured output, numbered-step reasoning scaffolds, read-only `agentType` enforcement. **Added all
  three** (`§reasoning-scaffold`, `§structured-output`, `§read-only-agent`), taking the library from
  8 → 11 patterns. These are the exact levers research ranks #1 and #6 plus the read-only hard rule.
- *Incidental:* 0 skills currently cite a `skill-patterns.md §anchor` (the anchors exist but aren't
  yet adopted) — untapped standardization, noted as future work, not a defect.

### MCP-server audit
Read-only audit of MCP wiring (`skill-mcp-check.py` + `skill-mcp-manifest.md`). Findings:
- **No model-independence failures from broken MCP.** claude-mem ingestion is known-broken, but **no
  skill sole-depends on it** — `audit-deep` and `context-pack` use it only as a fallback behind
  rag-index/grep. The graceful-degradation design *is* model-independence: a model that can't reach an
  MCP server falls back to grep/file-read rather than failing. That's the right pattern.
- **`mcp__serena__find_symbol`-style references are paired with a grep alternative** in the skills
  that use them — so an unavailable MCP server degrades, it doesn't break.
- **Manifest adoption is 0%** — ~8 skills reference `mcp__` tools but none declare `mcp_servers:` in
  frontmatter, so the (sound, batch-capable) `skill-mcp-check.py` gate currently validates nothing.
  This is the one real gap: declaring the dependency would let the gate flag an unavailable server
  *before* runtime. Recommended as future work (per-skill judgment; not auto-fixable safely).
- **`openai-docs`** (a vendored `.system/` skill for Codex) references the unconfigured
  `openaiDeveloperDocs` server but ships a thorough documented fallback (auto-install → escalate →
  ask user → bundled references → official-domain web search). Not modified (vendored; behavior
  already robust).

**Verdict: MCP layer is model-independent today via fallbacks; manifest adoption is the upgrade
path, not a defect.**

---

## What's next (honest ceiling)

The structural floor is at 100% — every skill loads. The remaining quality headroom is in **SOFT**
nudges, which are advisory, not breakage:

- `no-done-when`: **191** skills lack an explicit checkable completion criterion
- `no-stop-conditions`: **123** skills lack a named "if X → halt" failure path

These are the next quality levers, but they require judgment to fix well (a wrong done-condition is
worse than none), so they're deliberately SOFT — not auto-blocked. They're tracked by the same
scorecard, so progress is measurable. The model-independent *floor* is the win this session; the
*ceiling* is ongoing.

---

*Generated 2026-06-26. Reproduce the headline number any time:
`python3 ~/.claude/scripts/harness-skill-scorecard.py`*
