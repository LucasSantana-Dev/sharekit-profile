# Decision: resolve plugin/local skill name collisions in ~/.claude/skills/

- **Date:** 2026-06-22
- **Status:** Accepted
- **Process:** /skill-maintainer audit → /research-and-decide (decision-critic NEEDS_REVISION, reconciled by verifying the load-bearing claims, session 2026-06-22)
- **Governs:** duplicate `name:` declarations in the skill catalog that caused fuzzy skill discovery.

## Context

The /skill-maintainer audit found three duplicate `name:` declarations in the
catalog scan, the suspected root cause of fuzzy skill discovery:

1. `name: skill-creator` declared 4×: local real dir `skill-creator/` (a fork
   differing from the official plugin), `.system/skill-creator`, and two symlinks
   (`skill-creator-plugin`, `plugin-skill-creator-skill-creator`) both → the same
   `claude-plugins-official/skill-creator` cache.
2. `name: mem-search` declared 2×: `mem-search` + `plugin-claude-mem-mem-search`,
   both → the same `thedotmack/claude-mem/10.3.1` cache. (claude-mem ingestion is
   currently broken — 218k stuck messages.)
3. `name: code-review` declared 2×: local real `code-review/` + plugin symlink
   `plugin-coderabbit-code-review` (distinct tools sharing an internal name).

The plugin manager mirrors each plugin skill under the namespaced convention
`plugin-<plugin>-<skill>/`. Two extra **bare** symlinks (`mem-search`,
`skill-creator-plugin`) duplicate that and follow no manager convention.

### Verified before deciding (decision-critic Claims To Verify)

- `.system/` is **Codex's** skill root (`.codex-system-skills.marker`; SKILL.md says
  "extends Codex's capabilities") — **not** in Claude's catalog. `.system/skill-creator`
  is not a Claude collision.
- The bare symlinks are **not** git-tracked and **not** in `installed_plugins.json`;
  the manager uses the namespaced convention universally → bare ones are manual/legacy
  and will **not** be recreated by the manager.
- For same-target symlink pairs the duplicate `name:` is cosmetic — both resolve to one
  SKILL.md, so discovery returns the right skill regardless of which dir survives.
- Official plugin skill-creator is materially more complete than the local fork
  (479 vs 77 lines; full eval harness — `run_eval`/`run_loop`/`aggregate_benchmark`/
  `improve_description`, grader/comparator/analyzer agents, eval-viewer). The local
  fork uniquely has `scripts/init_skill.py` + `references/` workflow docs the plugin lacks.

## Decision

1. **skill-creator (the only *genuine* ambiguity — two different skills):** make the
   official plugin canonical for `/skill-creator` (operator chose "the most complete
   skill"). **Demote, not delete** the local fork → renamed dir + `name:` to
   `skill-creator-local`, preserving its unique `init_skill.py` and reference docs.
   Reversible: rename back.
2. **mem-search (bare): keep.** It is the primary `/mem-search` handle, may be
   referenced by automation, and its dependency on the (broken) claude-mem ingestion
   is unverified. Deletion = low value, non-zero risk.
3. **code-review: keep both.** The plugin is reachable via its namespaced form; the
   duplicate internal `name:` is cosmetic, no invocation clash.
4. **Bare/legacy symlinks (`skill-creator-plugin`, `mem-search`): leave in place.**
   They resolve to the same targets as the namespaced aliases; deleting them is
   cosmetic and risks breaking hardcoded invocations. Not worth fighting the manager.
5. **`.system/`: leave** — Codex namespace, outside Claude's catalog.

## Consequences

- No real (non-symlink) `name:` collisions remain in the catalog.
- `/skill-creator` unambiguously routes to the more capable official plugin; the
  local fork's unique bootstrap script stays available as `/skill-creator-local`.
- Remaining duplicate `name:` declarations are all same-target symlink pairs
  (cosmetic) — accepted as benign.
- The fragile parts the critic flagged (deleting bare symlinks, betting on manager
  recreation behavior) were deliberately NOT done.

## Revisit when

- `/skill-creator` mis-routes, or the operator stops needing the local
  `init_skill.py` flow (then archive `skill-creator-local/`).
- claude-mem ingestion is fixed or abandoned (re-decide whether `mem-search`
  stays — restore from plugin if removed).
- The plugin manager changes its symlink convention (could recreate or orphan the
  bare aliases).
