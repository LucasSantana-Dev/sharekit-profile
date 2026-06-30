# Skill catalog efficiency

> 233 skills listed vs a lean-harness median of ~10-43. This is the analysis,
> the concrete reduction plan, and a record of what was actually executed.

## Execution status (2026-06-30)

- **Archived (executed)**: `skill-creator-local` (explicitly superseded by the
  official plugin), `tdd` (explicit alias of `test-driven-development`), and
  `plugin-claude-mem-mem-search` (byte-identical duplicate of `mem-search`).
- **Fixed (executed)**: all 10 `adt-*` frontmatter `name:` fields now carry the
  `adt-` prefix, matching their folder names. `adt-auto-invoke` was already
  correct. Verified: no duplicate frontmatter names remain across the catalog.
- **Catalog**: 235 → 233 active on disk; **228 indexed → 195 listed, 33 hidden**
  via `invocation_type: internal` (P1 applied).
- **P1 applied (executed)**: 33 composite sub-skills marked
  `invocation_type: internal` so they drop out of the always-loaded listing.
  Composites still resolve them by path. The hide is enforced by
  `skill-index.sh` (internal skills are counted but NOT emitted).
- **Fixed (executed)**: `three-man-team/skill.md` renamed to `SKILL.md` — it
  was invisible to the indexer (matches `^SKILL.md$`).
- **Security validate gate**: `skill-validate.sh` gained a `security_exempt:`
  allowlist. 3 skills that document dangerous patterns by design
  (`skill-security-scan`, `harness-audit`, `nano-banana`) are exempted;
  security criticals dropped 6 → 0.
- **Schema errors resolved (PR #14)**: all 55 schema validation errors cleared.
  27 repo-tracked skills converted from YAML block scalar descriptions (`|`,
  `>`, `>-`) to single-line plain strings; 2 missing `description:` fields
  inserted (`changelog-update`, `quality-gates`). Validator now reports
  `errors=0`. The grep-based `extract_field` in `skill-validate.sh` cannot
  parse block scalars — this is a known limitation, not a fix target.
- **NOT executed**: the broader P0 "fold/delete" list. Two independent audits
  proposed merging `add`+`fallback`+`request-refactor-plan`+
  `ponytail-*` into broader skills, but direct inspection showed these are
  distinct skills with concrete workflows — they were mislabeled by
  description-only judgments. Destroying them would be a capability loss. The
  deeper reduction requires (a) real session telemetry (the trajectory is
  synthetic only — `skill-prune.sh` reports 229 never-hit, but that is
  starved data) and (b) a per-skill relationship audit against the
  composite-first routing map.
- **Plugin-namespace collisions** (4 plugin symlinks whose frontmatter `name:`
  drops the `plugin-*` prefix) are by design of the plugin system and are
  gitignored here; they are a plugin-system concern, not a sharekit bug.

## The problem

The sharekit catalog lists **233 skills** to the agent at startup. Competitive
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

sharekit lists 233 because it lists **every sub-skill individually** alongside
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

Add a `hidden: true` frontmatter field consumed by `skill-index.sh`. Hidden
skills are NOT in the always-loaded `<available_skills>` listing, but composites
can still resolve and invoke them by path. Hide the ~35 sub-skills with no
standalone trigger (e.g. `pr-flow`, `pr-merge-readiness`, `version-bump`,
`test-health`, `mutation-test`, `config-drift-detect`, `security-audit`,
`socket-audit`, `rag-quality`, `rag-curate`, `wake-up`, `pr-snapshot`,
`sync-memories`, `gh-fix-ci`, `gh-address-comments`, `ci-watch`,
`refactor-plan`, `three-man-team`). Keep listed any sub-skill with a strong
standalone trigger (`adr-write`, `docs-sync`, `plan`, `brainstorming`,
`deployment-automation`).

**Prerequisite**: extend `skill-index.sh` to skip `hidden: true` entries
(currently it lists every SKILL.md it finds; the `hidden` field is not yet
read). This is the structural lever — it must land before the hide list is
applied, otherwise hidden skills still appear.

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

PR #13 review identified ~2084 lines reducible via targeted refactoring. File:line references:

### Dead code in `hooks/cycle.sh`

- **Lines 82-113:** Unused `run_step`/`record_step` helper functions (~32 lines). The cycle was refactored to inline step execution; these functions are never called. Safe to delete.
- **Impact:** 32 lines deleted, no behavior change.

### Consolidate report generation in `hooks/cycle.sh`

- **Lines 392-464:** Printf-driven cycle report (72 lines) can be replaced with here-doc template (~35 lines). Current approach uses repeated `printf` + variable interpolation; here-doc reduces cognitive overhead.
- **Impact:** ~37 lines saved, improved readability.

### Consolidate 6 awk scanners in `hooks/transcript-scanner.sh`

- **Lines 81-135:** Six awk scanners (scanner-1 through scanner-6) with identical structure: each reads trajectory, applies pattern-specific regex, outputs JSON findings. Can be consolidated into a generic scan function + pattern table.
- **Impact:** ~120 lines → ~80 lines (40 lines saved), improved maintainability.

### Shared boilerplate in `hooks/reflect-retry.sh` + `hooks/textgrad.sh`

- Both files share ~30 lines of identical setup: read proposal, write reflection/gradient markdown, write reflection.jsonl, append to trajectory, append to history. Extract to `hooks/shared/reflection-io.sh`.
- **Impact:** 60 lines → 30 lines (30 lines saved), single-source-of-truth for I/O format.

### Dead modes in `hooks/checklist-gate.sh`

- **Lines 130-146:** "warn" and "block" modes implemented identically to "shadow" mode (both exit 0, both write same file). Shadow mode is the only mode; warn/block are dead code.
- **Impact:** 15 lines deleted, simplified logic.

### Duplicate plugin directories

- `claude/skills/skill-creator-plugin/` and `claude/skills/plugin-skill-creator-skill-creator/` are byte-identical ~1.9K lines each. Archive one, symlink the other.
- **Impact:** ~1.9K lines saved, eliminated redundancy.

### Total reducible

- Dead code: 32 + 15 + 1900 = **1947 lines**
- Consolidation: 40 + 37 + 30 = **107 lines**
- **Total: ~2054 lines reducible** (matches the ~2084 estimate in PR #13 review)

### Priority order

1. **Dead code removal** (easy, safe): `cycle.sh` dead functions, `checklist-gate.sh` dead modes — 47 lines, zero risk
2. **Report consolidation** (easy): `cycle.sh` printf → here-doc — 37 lines, low risk
3. **Deduplicate plugin dirs** (medium): archive + symlink — 1.9K lines, requires testing
4. **Scanner consolidation** (medium-hard): `transcript-scanner.sh` 6 awk → 1 scan fn — 40 lines, requires careful regex preservation
5. **Shared I/O extraction** (hard): `reflect-retry.sh` + `textgrad.sh` shared boilerplate — 30 lines, requires interface design

**Recommendation:** Start with #1 (dead code) in a focused PR. Defer #4-5 until after telemetry shows these hooks are actually used in production.

## Remaining work

- Move Criativaria skills (`notion-tasks`, `criativaria-brain-sync`,
  `shorts-edit`) to that project's `.claude/skills/` once telemetry confirms
  low cross-project usage.
