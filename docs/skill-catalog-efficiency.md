# Skill catalog efficiency

> **51 skills listed vs a lean-harness median of ~10-43.** This is the analysis,
> the concrete reduction plan, and a record of what was actually executed.
>
> **Update (2026-06-30):** Consolidation execution complete. 103 repo-tracked skills reduced to 50 via skill-family merges, stack-specific removal, and meta-skill pruning. 53 archived in `claude/skills/.archive/` (recoverable).
>
> **Update (2026-07-01):** Capability-preservation pass folded high-value archived details into active skills and updated reference docs so archived wrappers are no longer presented as active commands.
>
> **Update (2026-07-01, later):** `sync-memories` restored from archive as `invocation_type: internal` (was misapplied archival — see note below); it's a real folder but stays out of the listed count since it's hidden from the always-loaded listing. Active repo-tracked folders: 51 (50 listed + 1 internal); 52 remain archived. (`ads` was briefly added here, then moved to its client project the same day — client-scoped skills don't belong in the public catalog.)

## Execution status (2026-07-01)

- **Catalog**: 51 active skill folders in `claude/skills/` (50 consolidated + restored `sync-memories`); 52 archived in `claude/skills/.archive/` for recoverability. `curated-skills.txt` now mirrors the active repo catalog exactly.
- **Capability preservation (executed)**: archived over-engineering audit behavior folded into `ponytail`; systematic debugging discipline folded into `debug`; RAG quality/curation/drift details folded into `rag-maintenance` and `knowledge-loop`; scanner/security wrappers represented as evidence sources inside `secure`, `quality-assurance`, and `quality-gates`.
- **Docs alignment (executed)**: `README.md`, `AGENTS.md`, `docs/composites.md`, `docs/overview.md`, `docs/troubleshooting.md`, `docs/hooks.md`, and relevant `docs/skills/*` guides now describe active equivalents instead of archived command names.
- **Runtime topology documented**: runtime skills reconcile through canonical `~/.agents/skills`; `~/.claude/skills` is the symlinked runtime view and `~/.claude-env/skills` is a downstream mirror.
- **Knowledge-brain caution**: stale memories may still mention archived commands. Preserve historical notes and add superseding memories for current state; do not rewrite history as if old topology never existed.

### Misapplied archival correction (2026-07-01)

`sync-memories` was archived in the consolidation pass but should have been marked `invocation_type: internal` instead. It is a required sub-skill of the `knowledge-loop` composite (invoked in Phase 2 — Capture) and was disabled by archival. **Restored to `claude/skills/sync-memories/` with `invocation_type: internal` frontmatter.** Now hidden from the always-loaded listing (per progressive-disclosure P1) but resolvable by `knowledge-loop` by path.

## Historical execution status (2026-06-30)

- **Archived (executed)**: `skill-creator-local` (explicitly superseded by the official plugin), stack-specific skills, plugin-injected meta-skills, project-specific skills, and narrow wrappers whose durable capability was merged into broader active skills.
- **Fixed (executed)**: all repo-tracked active skill frontmatter validates with `errors=0`; duplicate and malformed entries from the 103-skill catalog were resolved during the consolidation campaign.
- **Known validator limitation**: `skill-validate.sh` uses grep-based extraction and cannot parse YAML block scalar descriptions. Skill authors should keep descriptions single-line.
- **Guardrail**: do not delete further skills based only on description similarity or starved telemetry. Further reductions require real usage data plus a relationship audit against composite routing and memory references.

## The problem

The sharekit catalog lists **50 skills** to the agent at startup (51 active repo-tracked folders, down from 103; `sync-memories` is a 51st folder but stays out of this listed count since it's `invocation_type: internal` — a knowledge-loop sub-skill, not standalone-invocable). Competitive
analysis of lean harnesses shows the always-listed catalog median is **~10-43
items**:

| Harness | Always-listed count | Leanness mechanism |
|---|---|---|
| Claude Code (built-in) | ~10 bundled skills | on-demand body load; `disableBundledSkills`; plugin namespacing |
| Aider | ~43 slash commands | single conventions file; no skill catalog |
| GitHub Copilot Chat | ~12 slash commands | tiny built-in set; file-scoped `.prompt` files |
| OpenCode | user-supplied | pure on-demand; per-agent `allow/deny/ask` hides denied skills |
| Cursor | rules + skills | glob-scoped progressive disclosure; `alwaysApply: false` |
| Warp | ~12 bundled | typed registries (agents != workflows != rules) |

sharekit formerly listed every sub-skill individually alongside
its composite, plus duplicates, aliases, and project-specific skills. The
composite-first principle (AGENTS.md) says "always invoke composites, never the
individual sub-skills" -- yet all the sub-skills are in the top-level listing,
doubling the apparent catalog size.

## What the audit found (and what was verified)

- **~50 individually-listed skills are sub-skills of at least one composite.**
  Per the composite-first principle, the agent should never invoke these
  directly -- they appear in the listing only because there is no hide mechanism.
  NOTE: a re-verification found only **1** nested `SKILL.md` at depth 3
  (`agents/forge-ai-init-dev/SKILL.md`); the "~35 sub-skills" the audit
  referenced are top-level skills that composites chain by name, not nested
  files. The hide mechanism (P1) must therefore operate on top-level skills,
  not nested files.
- **Duplicate clusters**: verified that prior sessions had already archived
  most duplicates. Remaining true duplicates (`skill-creator-local`, `tdd`,
  `plugin-claude-mem-mem-search`) were archived in this pass. The `adt-*`
  namespace mismatch was the real latent bug and is now fixed.

## The reduction plan (prioritized)

### P0 -- Dedup/merge (status: partly executed; the rest is blocked on evidence)

Executed (no capability loss):
- Archived `skill-creator-local` (superseded by the official plugin).
- Archived `tdd` (explicit alias of `test-driven-development`).
- Archived `plugin-claude-mem-mem-search` (byte-identical duplicate of
  `mem-search`).

Blocked (proposed but NOT executed — direct inspection showed these are
NOT duplicates; merging would be a capability loss):
- `add`, `fallback` — distinct skills with concrete workflows and rewrite
  gates, despite short descriptions.
- `request-refactor-plan`, `refactor-plan` — both produce plans but with
  distinct workflows (interview+GitHub-issue vs. in-repo plan). Not aliases.
- `ponytail-review`, `ponytail-audit`, `overengineering-audit` — distinct
  scopes (diff-focused, whole-repo, architectural). Not duplicates.
- `decision-mapping`, `plan` — distinct outputs (decision asset map vs.
  execution plan). Not aliases.

Remaining candidates that ARE likely safe but need a human decision (not done
here to avoid unilateral capability removal):
- Move `setup-matt-pocock-skills` to a one-time script.
- Move Criativaria skills (`notion-tasks`, `criativaria-brain-sync`,
  `shorts-edit`) to that project's `.claude/skills/`.

### P1 -- Hide sub-skills from the listing (~35 listed, on-disk unchanged)

Add an `invocation_type: internal` frontmatter field consumed by `skill-index.sh`. Hidden
skills are NOT in the always-loaded `<available_skills>` listing, but composites
can still resolve and invoke them by path. Hide the ~35 sub-skills with no
standalone trigger (e.g. `pr-flow`, `pr-merge-readiness`, `version-bump`,
`test-health`, `mutation-test`, `config-drift-detect`, `security-audit`,
`socket-audit`, `rag-quality`, `rag-curate`, `wake-up`, `pr-snapshot`,
`sync-memories` ✓, `gh-fix-ci`, `gh-address-comments`, `ci-watch`,
`refactor-plan`, `three-man-team`). Keep listed any sub-skill with a strong
standalone trigger (`adr-write`, `docs-sync`, `plan`, `brainstorming`,
`deployment-automation`).

**Status**: `skill-index.sh` now processes `invocation_type: internal` (extends previous `hidden: true` plan). `sync-memories` has been marked and restored as the first correctly-hidden sub-skill under this mechanism.

**Combined P0+P1 (revised): listed catalog 233 -> ~195 after the safe
archivals already done plus hiding.**

### P2 -- Per-agent skill permissions (OpenCode model)

Add a `skillPermissions` map (or `opencode.json` per-agent patterns) so denied
skills are hidden from the listing entirely per project:
```json
"skillPermissions": { "*": "allow", "notion-tasks": "deny", "criativaria-*": "deny" }
```

### P3 -- Tighten the guardrail + budget

- `scripts/check-catalog.sh`: count **listed** skills (post-hide), not on-disk.
  Set `warn >150, fail >200` for the listed count; keep on-disk `fail >350` as a
  hard ceiling.
- `skillListingBudgetFraction`: keep `0.05` after P1 brings the listed count to
  ~183 (raises to 0.08 only if hiding does not land).

### P4 -- Structural practices from lean harnesses

1. **Namespacing**: fix the `adt-*` folder/name mismatch (rename folders to
   match frontmatter, or add the prefix back to frontmatter). Namespace
   Criativaria skills as `criativaria:notion-tasks`.
2. **Typed registries**: split `skills/` into `composites/`, `single/`,
   `reference/` (docs like `writing-great-skills`, `api-design-principles` are
   not workflows -- they should not be in the skill listing at all).
3. **`/migrate-to-skills`-style consolidator**: extend `skill-maintainer` to
   auto-detect (a) skills whose `name` != folder name, (b) skills whose
   description is a substring of another's, (c) skills listed individually but
   only ever chained by a composite -- and propose merges/hides.
4. **Single manifest**: consolidate `curated-skills.txt` + `SKILLS.md` into one
   canonical manifest that `check-catalog.sh` validates against.

## Target

To reach the lean-harness median (~10-43), the catalog must expose **only
composites + true standalone skills** (~60-70 items) and treat everything else
as internal. That is achievable with P1 applied aggressively.

## Highest-leverage first 3 moves (revised after execution)

1. ~~Run P0 dedup~~ — done for the 3 confirmed duplicates; the rest is blocked
   on evidence (see P0 status above).
2. ~~Extend `skill-index.sh` to skip `hidden: true`~~ — done via
   `invocation_type: internal`; 33 sub-skills hidden, listed catalog
   228 → 195.
3. ~~Fix the `adt-*` folder/name mismatch~~ — done.

## Telemetry prerequisite

Before any further deletion/merge, the trajectory must carry real session data.
The `skill-prune.sh` hook is architecturally sound but starved: the trajectory
is 1.4 KB of synthetic test events. Run the harness against real sessions for
2-4 weeks before treating never-hit as an archive signal. Until then, only
structural dedup (duplicate frontmatter names, byte-identical bodies) is a
reliable signal — and those are now resolved.

## Metrics & Outcomes

### Schema validation status (2026-06-30)

**Before:**
- 55 validation errors (53 "description too short" + 2 missing description fields)
- 27 skills using YAML block scalar descriptions (`|`, `>`, `>-`) that the validator could not parse
- Validator reported `errors=55`

**After:**
- All 27 block scalar descriptions converted to single-line plain strings
- 2 missing description fields inserted (`changelog-update`, `quality-gates`)
- Validator reports `errors=0`, `warnings=262`, `critical=0`

**Note on warnings:** The 262 warnings are non-blocking. 261 are "no 'triggers' field" and 1 is "description exceeds 500 chars". These do not fail validation but indicate skills that may be undiscoverable by composite-router.

**Estimated token savings from P1 (invocation_type: internal):**
- 33 composite sub-skills hidden from always-loaded listing
- Average SKILL.md size: ~800 bytes (frontmatter only)
- Per-session savings: 33 × 800 = ~26KB of system prompt context
- With composite-first routing, sub-skills are still resolvable by path when needed

### Telemetry prerequisites status

The telemetry prerequisite for further dedup/merge remains **blocked**:

- `.harness/runtime/trajectory.jsonl` exists but contains synthetic test events
- Last updated: 2026-06-30 (P6 operational phase)
- Estimated size: ~1.4KB (synthetic)
- Real session data needed: 2-4 weeks of production use before `skill-prune.sh` signals are reliable
- `skill-prune.sh` currently reports ~229 never-hit skills, but this is starved data

**Decision:** Continue waiting for real telemetry before treating never-hit as an archive signal. Only structural dedup (duplicate names, byte-identical bodies) remains a reliable signal — and those are now resolved.

### Validator behavior documentation

**Known limitation:** `skill-validate.sh` uses grep-based `extract_field` that cannot parse YAML block scalars. When `description:` is followed by `|`, `>`, or `>-`, the validator reads only the marker character as the description value. This is a parser limitation, not a schema violation.

**Decision:** Accepted as-is. The validator is a quick security + sanity check, not a full YAML parser. Real YAML parsing would require Python/PyYAML dependency and slower validation. Block scalar descriptions are valid YAML but not recommended for skills because:
1. They fail the validator (even though valid)
2. They're harder to edit inline
3. Single-line descriptions force conciseness

**Not a fix target:** If a skill author uses block scalars and the validator reports an error, they should convert to single-line. This is working as documented.

## P8+P9 shipped hooks (PR #13)

The P8 and P9 phases shipped the deep-research synthesis cherrypicks that compound the flywheel without adding runtime dependencies:

### P8 — Cross-cutting patterns (PR #13, 2026-06-30)

- `hooks/reorder-context.sh` — post-compaction attention reordering (LlamaIndex-style): repositions retrieved chunks so highest-scoring land at window start/end, mitigating lost-in-the-middle
- `hooks/checklist-gate.sh` — binary checklist enforcement for security and release gates: replaces fuzzy natural-language checklists with yes/no gates that must all pass
- `hooks/transcript-scanner.sh` — 6 awk-based pattern scanners (refusals, eval-awareness, env-drift, hallucination, excessive-agency, prompt-injection tells) that feed the diagnose step

### P9 — Close-the-loop (PR #13, 2026-06-30)

- `hooks/trial-apply.sh` — materializes candidate hook edits into `.harness/forge/trial/` for isolated gating (never mutates live hook)
- `hooks/gate.sh` — gains `--proposal` + `--candidate` modes to test candidate hooks without committing
- `hooks/eval-run.sh` — gains `--seed` parameter for stateful hooks (e.g., stuck-loop detector's state file)
- `hooks/cycle.sh` — wires deploy-watch post-merge hook to monitor candidate performance in production
- `hooks/check-stuck-loop.sh` — gains real state file (was hardcoded stub)

**Impact:** The flywheel now operates end-to-end: trajectory → diagnose → distill → propose → trial → gate → deploy → watch → learn. All without runtime model calls or external dependencies.

## Actionable ponytail audit findings

PR #13 review identified ~2084 lines reducible via targeted refactoring. File:line references and execution status:

### ~~Dead code in `hooks/checklist-gate.sh`~~ (DONE)

- ~~**Lines 130-146:** "warn" and "block" modes implemented identically to "shadow" mode (both exit 0, both write same file).~~
- **Executed:** Removed dead `warn`/`block` case arms from the `case "$MODE"` block. Updated header comment to note only `shadow` is supported. PreToolUse cannot parse agent responses regardless of mode, so enforcement lives at the eval gate.
- **Impact:** 15 lines deleted, simplified logic, no behavior change.

### ~~Duplicate plugin directories~~ (DONE)

- ~~`claude/skills/skill-creator-plugin/` and `claude/skills/plugin-skill-creator-skill-creator/` are byte-identical.~~
- **Executed (PR #15, branch `refactor/ponytail-audit-phase1`):** Removed `plugin-skill-creator-skill-creator/` (17 files, ~718 lines). `skill-creator-plugin/` retained as canonical (both declare `name: skill-creator`, both byte-identical per `diff -r`). `curated-skills.txt` updated to remove the duplicate entry. No other repo files reference either path.
- **Impact:** 718 lines deleted, eliminated redundancy. ~186 remaining lines from the original ~2084 estimate.

### Consolidate report generation in `hooks/cycle.sh`

- **Lines 392-464:** Printf-driven cycle report (72 lines) can be replaced with here-doc template (~35 lines). Current approach uses repeated `printf` + variable interpolation; here-doc reduces cognitive overhead.
- **Impact:** ~37 lines saved, improved readability.

### Consolidate 6 awk scanners in `hooks/transcript-scanner.sh`

- **Lines 81-135:** Six awk scanners (scanner-1 through scanner-6) with identical structure: each reads trajectory, applies pattern-specific regex, outputs JSON findings. Can be consolidated into a generic scan function + pattern table.
- **Impact:** ~120 lines → ~80 lines (40 lines saved), improved maintainability.

### Shared boilerplate in `hooks/reflect-retry.sh` + `hooks/textgrad.sh`

- Both files share ~30 lines of identical setup: read proposal, write reflection/gradient markdown, write reflection.jsonl, append to trajectory, append to history. Extract to `hooks/shared/reflection-io.sh`.
- **Impact:** 60 lines → 30 lines (30 lines saved), single-source-of-truth for I/O format.

### False positive (corrected)

- **PR #13 review claimed `hooks/cycle.sh` lines 82-113 are dead code (`run_step`/`record_step` unused).** This is INCORRECT. `record_step` is called 20+ times throughout the file (every step in the cycle: steps 1-4, 5-9, plus fallback paths at lines 211-214). `run_step` is called at lines 226 and 231. These are the primary step-tracking infrastructure. Do not delete.

### Corrected total reducible

- ~~Dead code: 32 + 15 +~~ 570 = **570 lines** (corrected after removing false positive)
- Consolidation: 40 + 37 + 30 = **107 lines**
- **Total: ~677 lines** (was ~2054 — reduced by 1377 after the cycle.sh false positive correction)

### Remaining priority order

1. **Report consolidation** (easy): `cycle.sh` printf → here-doc — 37 lines, low risk
2. **Deduplicate plugin dirs** ~~(medium)~~ ~~**DONE**~~ — completed in PR #15
3. **Scanner consolidation** (medium-hard): `transcript-scanner.sh` 6 awk → 1 scan fn — 40 lines, requires careful regex preservation
4. **Shared I/O extraction** (hard): `reflect-retry.sh` + `textgrad.sh` shared boilerplate — 30 lines, requires interface design

**Recommendation:** Items #1, #3-4 deferred until telemetry confirms these hooks are actively used. Items #1 and #2 are done (dead code removal).

## Remaining work

- Move Criativaria skills (`notion-tasks`, `criativaria-brain-sync`,
  `shorts-edit`) to that project's `.claude/skills/` once telemetry confirms
  low cross-project usage.
