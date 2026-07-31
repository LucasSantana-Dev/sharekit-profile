# Plan: team expansion — solo-operator harness to team-ready (2026-07-31)

**Goal:** make sharekit-profile adoptable by developers at work — multi-developer teams and cross-team features.
**Brief:** `.claude/plans/research-brief-team-expansion.md` (every phase cites its evidence line).
**In scope:** de-soloing, onboarding, distribution, rollout playbook, spec lifecycle, memory vault, drift/signal tooling.
**Out of scope:** agent-teams protocol (experimental upstream, DEFER), CI-native review pack (opp 7 — next cycle), cross-harness hook porting (hooks are not portable; skills-only claims).
**Replan triggers:** brief opportunity ranking invalidated by new evidence; a phase exposes >3 friction points (invoke /research-and-decide before continuing); upstream ships org-profile support (claude-code#14467) making Phase 5 redundant.

Current state: governance layer shipped (PRs #81-88, 2026-07-31). Publish/sync/install pipeline 100% single-operator; no onboarding doc; memory team backend prose-only.

## Phase 1 — De-solo the package (brief opp 2; evidence: SKILL.md:33/43/334, 77 personal refs, VERIFIED)

- Parameterize `claude/skills/sync-sharekit-profile/SKILL.md`: `PROFILE_REPO` from env `SHAREKIT_PROFILE_REPO` with repo-discovery fallback; mount-guard message made generic.
- Add `.harness/operators.json` (multi-operator identity map); extend `hooks/check-identity.sh` to read it (emails array already supported — point it here).
- De-personalize `sharekit.toml`, `.claude-plugin/marketplace.json` owner fields into documented placeholders with a `scripts/personalize.sh` (or document the env override).
- **Files Touched:** `claude/skills/sync-sharekit-profile/SKILL.md`, `.harness/operators.json` (new), `hooks/check-identity.sh`, `sharekit.toml`, `.claude-plugin/marketplace.json`, `tests/identity.bats`, `tests/marketplace.bats`
- **Verify:** `bats tests/identity.bats tests/marketplace.bats && bash scripts/check-harness-manifest.sh`
- **Done when:** no hardcoded operator path/identity blocks a second operator's clone; manifest + marketplace gates green.

## Phase 2 — Team onboarding kit (brief opp 1; evidence: T1 no onboarding doc + repo-mode out-of-repo VERIFIED; T4 starter-profile CLAIMED)

- `docs/team-onboarding.md`: install (document external `sharekit` npm dependency), identity setup via `.harness/operators.json`, `.agents/mode` marker, starter profile (which 3 hooks + which 3 skills to enable first), week-1 checklist.
- Ship `claude/scripts/repo-mode.sh` into this repo (`scripts/repo-mode.sh`) with the `.agents/mode` marker spec in the doc.
- `scripts/bootstrap-team.sh`: one-command scaffold — committed `.claude/settings.json` stub, operators.json stub, enables starter hooks only.
- **Files Touched:** `docs/team-onboarding.md` (new), `scripts/repo-mode.sh` (new, moved), `scripts/bootstrap-team.sh` (new), `tests/` (bootstrap fixture test)
- **Verify:** `bash scripts/bootstrap-team.sh --dry-run && bats tests/`
- **Done when:** a fresh clone + one command yields a working starter profile with zero references to the original operator's machine.

## Phase 3 — Install/update path (brief opp 3; evidence: T2 installers beat forks VERIFIED)

- Document + test the `extraKnownMarketplaces` + `enabledPlugins` recipe so a repo clone auto-provisions the profile as plugins.
- Versioned update channel: `stable`/`latest` refs via release-please tags; `docs/configuration.md` gains channel-assignment section.
- **Files Touched:** `docs/team-onboarding.md`, `docs/configuration.md`, `scripts/check-marketplace.sh` (channel assertion), `tests/marketplace.bats`
- **Verify:** `bats tests/marketplace.bats && bash scripts/check-marketplace.sh`
- **Done when:** a team repo can pin `stable` and receive updates without forking this repo.

## Phase 4 — Team rollout playbook (brief opp 4; evidence: T4 champions/30-60-90/pilot composition CLAIMED-directional, GitHub docs VERIFIED)

- `docs/team-rollout-playbook.md`: 30/60/90 checklist, RACI (rollout lead 20-30% allocation, skill captain), pilot composition 20/60/20, outcome-over-seat metrics guidance, hook-fatigue rule (start with 1-3 hooks).
- **Files Touched:** `docs/team-rollout-playbook.md` (new)
- **Verify:** `bash hooks/skill-validate.sh --dir claude/skills` (docs lint via CI)
- **Done when:** a rollout lead can run the first quarter from the doc alone.

## Phase 5 — Team-scope memory vault (brief opp 5; evidence: T1 backend prose-only VERIFIED; claude-code#14467 VERIFIED)

- Implement git-backed team vault: `scripts/team-memory-sync.sh` (pull/push shared vault repo), wire `.harness/memory-scopes.json` team scope to it, complete `memory-promote` end-to-end (proposal → vault PR).
- **Files Touched:** `scripts/team-memory-sync.sh` (new), `.harness/memory-scopes.json`, `claude/skills/memory-promote/SKILL.md`, `tests/memory-scopes.bats`
- **Verify:** `bats tests/memory-scopes.bats`
- **Done when:** two clones can share a promoted memory note through the vault with the scope gate enforced.

## Phase 6 — Spec-anchored lifecycle (brief opp 6; evidence: Fowler VERIFIED, spec-kit #152)

- PR↔spec linking convention (PR body `Spec: specs/<feature>/` line) + `hooks/check-spec-drift.sh` (spec requirements modified without tasks update, or PR touching code with no spec reference when specs/ exists).
- **Files Touched:** `hooks/check-spec-drift.sh` (new), `specs/_template/`, `docs/team-onboarding.md`, `tests/`
- **Verify:** `bats tests/`
- **Done when:** spec drift fails a gate; template PR flow documented.

## Phase 7 — Config size-cap + drift detector (brief opp 9; evidence: T4 CLAUDE.md bloat stall CLAIMED)

- `hooks/check-config-size.sh` (warn >400 lines CLAUDE.md, fail >800) + cross-developer drift check leveraging existing `check-harness-drift.sh` pattern.
- **Files Touched:** `hooks/check-config-size.sh` (new), `tests/`
- **Verify:** `bats tests/`
- **Done when:** oversized config warns in pre-commit.

## Deferred (with reasons)

- CI-native review pack (opp 7): SHIPPED 2026-07-31 via spec `.claude/plans/spec-ci-review-pack.md` + plan `.claude/plans/ci-review-pack-impl-2026-07-31.md` (claude-code-action orchestration, fork decision resolved).
- Dual-emit AGENTS.md/CLAUDE.md (opp 8): SHIPPED 2026-07-31 (PR #96, scripts/sync-agents-claude.sh + drift-guard).
- Adoption signal panel (opp 10): SHIPPED 2026-07-31 (PR #96, scripts/adoption-panel.sh; privacy model = local-only by design).
