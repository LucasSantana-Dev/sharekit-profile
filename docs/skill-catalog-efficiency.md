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
- **Catalog**: 235 → 233 active.
- **NOT executed**: the broader P0 "fold/delete" list below. Two independent
  audits proposed merging `add`+`fallback`+`request-refactor-plan`+
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
2. Extend `skill-index.sh` to skip `hidden: true`, then mark the P1 sub-skills
   (-35 listed, no capability loss). This is the next safe move.
3. ~~Fix the `adt-*` folder/name mismatch~~ — done.

## Telemetry prerequisite

Before any further deletion/merge, the trajectory must carry real session data.
The `skill-prune.sh` hook is architecturally sound but starved: the trajectory
is 1.4 KB of synthetic test events. Run the harness against real sessions for
2-4 weeks before treating never-hit as an archive signal. Until then, only
structural dedup (duplicate frontmatter names, byte-identical bodies) is a
reliable signal — and those are now resolved.
