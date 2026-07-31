# Plan: CI-native review pack implementation (2026-07-31)

**Goal:** implement `.claude/plans/spec-ci-review-pack.md` — CI-native multi-agent review pack installable into any team repo.
**Spec:** `.claude/plans/spec-ci-review-pack.md` (decisions D1-D7 cited there; this plan does not re-decide them).
**In scope:** review-pack plugin (agents + prompts), tier classifier, coordinator output contract, workflow template, re-review state reader, tests, docs.
**Out of scope:** hosted server, autofix application, AGENTS.md-freshness reviewer, Agent Teams orchestration (spec OUT OF SCOPE entries).
**Replan triggers:** claude-code-action plugin input fails in a real run (fall back to vendored prompt files, spec D1 open fork); >3 friction points in Phase 2 (invoke /research-and-decide); fingerprint scheme proves unstable in Phase 5 test (back to spec D5).

Current state: marketplace with 6 plugins live; llm-policy.json tiers; role agents (critic, code-reviewer, security-reviewer) exist as read-only agents; bootstrap-team.sh scaffolds consuming repos.

## Phase 1 — Plugin scaffold (spec D1, D7)

- Create `claude/agents/review/` pack: `coordinator.md` (strongest model, judge pass: dedupe, re-categorize, reasonableness filter, decision rubric biased to approval), `reviewer-general.md`, `reviewer-security.md`, `reviewer-quality.md`, `reviewer-docs.md` — each with an explicit "What NOT to Flag" section (D3, D4).
- Register `review-pack` plugin in `.claude-plugin/marketplace.json` (source `./claude/agents/review`); add `curated-agents.txt` entries if the drift-guard requires.
- **Files Touched:** `claude/agents/review/*.md` (new), `.claude-plugin/marketplace.json`, `curated-agents.txt`
- **Verify:** `bash scripts/check-marketplace.sh && bash scripts/check-harness-manifest.sh`
- **Done when:** marketplace gate passes with 7 plugins; `claude plugin validate .` clean.

## Phase 2 — Tier classifier + context builder (spec D2, D6)

- `scripts/review-tier.sh`: inputs = PR diff stats (via `gh pr diff --name-only` + numstat); emits tier (trivial|lite|full), the reviewer fan-out list for that tier, and writes `review-context/` (per-file patch files + shared context file, noise pre-filter: lockfiles, `.min.*`, `.map`, `@generated`; migrations exempt).
- Deterministic thresholds in ONE place at the top of the script (spec open question 2).
- **Files Touched:** `scripts/review-tier.sh` (new), `tests/review-tier.bats` (new)
- **Verify:** `bats tests/review-tier.bats && shellcheck -S warning scripts/review-tier.sh`
- **Done when:** fixture diffs classify correctly (10-line docs -> trivial + downgraded coordinator flag; 150-line -> lite; 60-file -> full; auth/ path -> full; lockfile-only -> zero reviewable files).

## Phase 3 — Coordinator output contract (spec D4)

- `claude/agents/review/coordinator-schema.json`: the `--json-schema` for claude-code-action structured output — fields: `event` (APPROVE|COMMENT|REQUEST_CHANGES), `findings[]` {path, position, severity (critical|warning|suggestion), rule_id, body, fingerprint}, `summary`.
- Fingerprint = sha256(path + rule_id + snippet) computed by `scripts/review-fingerprint.sh` (shared with Phase 5).
- **Files Touched:** `claude/agents/review/coordinator-schema.json` (new), `scripts/review-fingerprint.sh` (new), `tests/review-pack.bats` (new)
- **Verify:** `jq empty claude/agents/review/coordinator-schema.json && bats tests/review-pack.bats`
- **Done when:** schema validates; fingerprint stable across line-number shifts on fixture snippets.

## Phase 4 — Workflow template (spec D1, D5 fork degradation)

- `.github/workflows-templates/ai-review.yml`: PR trigger; claude-code-action@v1 with `plugin_marketplaces: ["LucasSantana-Dev/sharekit-profile"]`, `plugins: ["review-pack@sharekit-profile"]`, tier step running review-tier.sh, coordinator step with schema, one batched review post; fork-PR guard (read-only token -> full review, no comment write); heartbeat + 25min timeout; retry only on 429/503.
- `bootstrap-team.sh` gains an optional `--with-review` flag copying the template.
- **Files Touched:** `.github/workflows-templates/ai-review.yml` (new), `scripts/bootstrap-team.sh`, `tests/team-kit.bats`
- **Verify:** `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows-templates/ai-review.yml'))" && bats tests/team-kit.bats`
- **Done when:** template parses; bootstrap `--with-review` copies it; fork path degrades without failing.

## Phase 5 — Re-review state reader (spec D5)

- `scripts/review-state.sh`: fetches the bot's prior review + inline threads for the PR (`gh api`), extracts the hidden fingerprint block, emits `<previous_review>` + resolved/unresolved lists for the coordinator prompt; degrades to empty on first run or fork PRs.
- **Files Touched:** `scripts/review-state.sh` (new), `tests/review-state.bats` (new)
- **Verify:** `bats tests/review-state.bats`
- **Done when:** fixture comment payloads parse; fixed finding omitted, unfixed re-emitted with identical fingerprint (spec AC-4 shape); force-push fixture keeps fingerprints.

## Phase 6 — Dogfood + docs (spec AC-1..AC-6)

- Add the workflow to THIS repo (self-review on future PRs), workflow_dispatch for a manual dry-run.
- `docs/team-onboarding.md` gains an "AI review pack" section (install, tiers, break-glass label, cost note pointing at llm-policy).
- Update `.claude/plans/team-expansion-2026-07-31.md` deferred section (opp 7 -> shipped).
- **Files Touched:** `.github/workflows/ai-review.yml` (new), `docs/team-onboarding.md`, `.claude/plans/team-expansion-2026-07-31.md`
- **Verify:** `bats tests/ && bash scripts/check-harness-manifest.sh`
- **Done when:** full suite green; manual dry-run on one open PR produces a schema-valid review (or documented dry-run limitation if no API key in CI secrets).

## Executor note

Mid-task unknowns go back into the spec (`.claude/plans/spec-ci-review-pack.md`), not into ad-hoc research. Phases 1-3 are independent enough to fan out; 4-6 are sequential.
