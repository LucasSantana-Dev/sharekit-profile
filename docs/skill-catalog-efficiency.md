# Skill catalog efficiency

> 235 skills listed vs a lean-harness median of ~10-43. This is the analysis and
> the concrete reduction plan.

## The problem

The sharekit catalog lists **235 skills** to the agent at startup. Competitive
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

sharekit lists 235 because it lists **every sub-skill individually** alongside
its composite, plus duplicates, aliases, and project-specific skills. The
composite-first principle (AGENTS.md) says "always invoke composites, never the
individual sub-skills" -- yet all the sub-skills are in the top-level listing,
doubling the apparent catalog size.

## What the audit found

- **~50 individually-listed skills are sub-skills of at least one composite.**
  Per the composite-first principle, the agent should never invoke these
  directly -- they appear in the listing only because there is no hide mechanism.
- **~15 skills are trivial, persona toggles, or project-specific** (Criativaria
  skills, `caveman`, `plow-ahead`, `setup-matt-pocock-skills`, etc.).
- **Duplicate clusters** (specific names): 3x `skill-creator`, 2x `code-review`
  (+ plugin), 2x `graphify`, 2x `impeccable`, 2x `mem-search` (+ plugin),
  `tdd` is an explicit alias of `test-driven-development`.
- **`adt-*` namespace bug**: all 11 `adt-*` folders have a frontmatter `name:`
  that drops the `adt-` prefix, so the folder name and the frontmatter name
  disagree -- a latent collision with non-adt skills of the same name.
- **Telemetry is not yet a usable signal**: `skill-prune.sh` reports 229
  never-hit / 0 active, but the trajectory is only synthetic test events. Real
  session telemetry has not been logged yet.

## The reduction plan (prioritized)

### P0 -- Dedup/merge (~17 skills, no capability loss)

| Action | Skills | Reduction |
|---|---|---|
| Delete `skill-creator-local` (self-described superseded); consolidate to plugin `skill-creator` | skill-creator, skill-creator-local, skill-creator-plugin | -2 |
| Delete flat `code-review`; keep plugin CodeRabbit + `review` | code-review | -1 |
| Delete one duplicate `graphify` | graphify | -1 |
| Delete one duplicate `impeccable` | impeccable | -1 |
| Delete `tdd` (explicit alias of `test-driven-development`) | tdd | -1 |
| Merge `plugin-claude-mem-mem-search` into `mem-search` | mem-search, plugin-claude-mem-mem-search | -1 |
| Fold `diagnosing-bugs` into `debug-deep` | diagnosing-bugs | -1 |
| Fold `request-refactor-plan` into `refactor-plan` | request-refactor-plan | -1 |
| Fold `ponytail-review` + `ponytail-audit` into `overengineering-audit` | ponytail-review, ponytail-audit | -2 |
| Fold `decision-mapping` into `plan` | decision-mapping | -1 |
| Delete `add` (vague; overlaps `plan`+`scope-it`) | add | -1 |
| Delete `fallback` (meta-skill, no concrete behavior) | fallback | -1 |
| Move `setup-matt-pocock-skills` to a one-time script | setup-matt-pocock-skills | -1 |
| Move Criativaria skills to that project's `.claude/skills/` | notion-tasks, criativaria-brain-sync, shorts-edit | -3 |

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

**Combined P0+P1: listed catalog 235 -> ~183.**

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

## Highest-leverage first 3 moves

1. Run P0 dedup (-17, no capability loss).
2. Add `hidden: true` to `skill-index.sh` and mark the 35 P1 sub-skills (-35
   listed, no capability loss).
3. Fix the `adt-*` folder/name mismatch (prevents latent bugs).
