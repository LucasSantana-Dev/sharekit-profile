# Research Brief: team expansion (2026-07-31)

**Planning question:** what should the next phase of sharekit-profile be so
developers can adopt it at work — multi-developer teams and cross-team
features, not solo operation?

**Method:** landscape-scan, 4 parallel tracks (internal state, OSS landscape,
state of the art, community practice). Baseline claim verified, not assumed.

## Baseline verdict (track 1, VERIFIED)

"80% solo-shaped" holds with nuance: ~90% of FILES are path-portable, but
~100% of the publish/sync/install pipeline is single-operator. Concrete:
`sync-sharekit-profile/SKILL.md:33,43,334` hardcodes operator paths;
identity baked into `sharekit.toml`, marketplace.json, README (77 personal
references across 12 files); `memory-scopes.json` team backend is prose-only
(no shared vault); `repo-mode.sh` (cooperative-mode detection) lives outside
this repo; no team onboarding doc exists (onboard-new-repo onboards REPOS,
not PEOPLE); installer lives in the separate `sharekit` repo.

## Position statement

Governance is genuinely ahead of the landscape (fingerprinted mcp-policy +
deterministic policy-gate beats GitHub Copilot's GA allowlist; eval gates
match the 2026 skill-eval canon; constitution.json predates spec-kit's
constitution pattern adoption). Adoption is behind: no install/update path
(fork-drift by design), no onboarding flow, no team rollout playbook, no
shared-memory backend, solo identity baked into the package contract. The
ecosystem rewards installer-driven, composable distribution (obra/superpowers
via `npx skills add`, private marketplaces via `extraKnownMarketplaces`) —
a forked personal profile cannot give teams versioned updates.

## Ranked opportunities

| # | Opportunity | Impact | Effort | Evidence |
|---|-------------|--------|--------|----------|
| 1 | Team onboarding kit: `docs/team-onboarding.md` + one-command bootstrap (starter profile: 1-3 hooks, lean CLAUDE.md, 3 starter skills) + ship `repo-mode.sh` in-repo | high | low-med | T1 (no onboarding doc, repo-mode out-of-repo, VERIFIED); T4 (teams start with ONE hook, 30/60/90 playbook, CLAIMED) |
| 2 | De-solo the package: parameterize sync-sharekit-profile paths, `.harness/operators.json` multi-identity, de-personalize sharekit.toml/marketplace | high | low | T1 (SKILL.md:33/43/334, 77 personal refs, VERIFIED) |
| 3 | Install/update path: marketplace + `extraKnownMarketplaces` recipe + versioned update channel (stable/latest) | high | med | T2 (installers beat forks, fork-drift, VERIFIED; marketplace.json already shipped) |
| 4 | Team rollout playbook: 30/60/90 checklist, RACI (rollout lead, skill captain), champions model, pilot composition (20/60/20), outcome-over-seat metrics | high | low | T4 (Delta champions CLAIMED, GitHub rollout docs VERIFIED, vanity-metrics pitfall CLAIMED) |
| 5 | Team-scope memory vault: git-backed shared vault implementing memory-scopes team tier + memory-promote flow end-to-end | high | high | T1 (backend prose-only, VERIFIED); T3 (org context federation = top upstream feature request, anthropics/claude-code#14467, VERIFIED) |
| 6 | Spec-anchored lifecycle: PR↔spec linking + spec-drift checker (spec maintenance is every SDD tool's weak point) | high | med | T3 (Fowler VERIFIED, spec-kit discussion #152) |
| 7 | CI-native review pack: risk tiers + structured severity + re-review state for role agents | high | med | T3 (Cloudflare: 131k reviews/30d, $1/review, 0.6% override — only large-scale VERIFIED result) |
| 8 | Dual-emit AGENTS.md + CLAUDE.md from one source | med | low | T2 (34.4% vs 31.6% adoption split, arXiv 2602.14690 VERIFIED) |
| 9 | Config size-cap hook + cross-developer drift detector | med | low | T4 (CLAUDE.md bloat >800 lines = sprint-2 stall, CLAIMED) |
| 10 | Local adoption signal panel (skill invocations, hook firings) | med | med | T4 (seat metrics mislead, CLAIMED) |
| - | Agent-Teams-compatible task protocol | DEFER | - | T3 (experimental upstream, unstable; wait-and-adapt) |

## Contradictions / open forks

- Orchestration layer bet: Cloudflare chose OpenCode server; Claude Agent
  Teams is the first-party competitor. Do not build on either yet.
- "Skills work unmodified across harnesses" is vendor-claimed; hooks are NOT
  portable. Cross-harness claims must be scoped to skills only.
- Rollout statistics (1,948% growth, 38min/day saved vs METR 19% slower) are
  vendor-stage or context-dependent — use as directional, not targets.

## Source index (load-bearing)

- Cloudflare AI code review (blog.cloudflare.com/ai-code-review, 2026-04-20) — VERIFIED
- anthropics/claude-code#14467 (org CLAUDE.md feature request) — VERIFIED
- arXiv 2602.14690v5 (agent context file adoption dataset) — VERIFIED
- code.claude.com/docs/en/plugin-marketplaces + /settings (2026-07-29) — VERIFIED
- martinfowler.com SDD 3-tools (2025-10-15) — VERIFIED
- GitHub Copilot rollout-at-scale docs — VERIFIED
- Delta/Kiro DVT209 (vendor stage), Digital Applied 30/60/90, Faros/Jellyfish/Hivel metrics — CLAIMED, directional only
