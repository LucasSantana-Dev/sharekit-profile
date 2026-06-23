---
name: dep-sweep
description: Composite skill — batch-process the queue of open Dependabot / Renovate / npm-bot PRs by grouping them by risk, auto-merging the safe ones into `release`, and surfacing only the risky ones for human review. Chains gh PR enumeration → risk classification (devDeps / patch / minor / major / lockfile-only) → pr-merge-readiness per group → auto-merge safe group → flag risky group → optional /pr-to-release for batch entry on release. Use when bot-PR noise has piled up; reduces a 20-PR queue to "merged 14, 6 need eyes".
user-invocable: true
auto-invoke: "dependabot PRs", "renovate queue", "clean up bot PRs", "update deps", weekly if ≥10 open bot PRs
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.claude/skills/dep-sweep
---

# Dep Sweep

Turn a wall of bot PRs into one decision pass. Auto-merges the safe class
into `release` and surfaces only the genuinely risky updates for human review.
Reduces the daily/weekly drag of "20 dependabot PRs are open and I keep
ignoring them".

## Auto-invocation triggers

- User says "deal with dependabot", "clean up renovate", "update deps",
  "merge the bot PRs"
- ≥10 open PRs authored by `dependabot[bot]`, `renovate[bot]`, or `pre-commit-ci[bot]`
- Weekly cadence if the repo has automated dep updates configured

## Risk classification (always first)

For each open bot PR, classify into one of:

| Bucket | Heuristic | Default action |
|---|---|---|
| **AUTO-MERGE (safe)** | devDependencies only, OR patch bumps to any dep with passing CI, OR lockfile-only resyncs, OR pre-commit hook bumps | Auto-merge into `release` |
| **REVIEW (medium)** | Minor bumps of runtime deps, OR any bump that touches a known-sensitive package list (see project config) | Surface to user with diff summary |
| **HOLD (risky)** | Major bumps, OR bumps that fail CI, OR bumps to deps tagged `requires-manual` in `.claude/dep-sweep-config.json`, OR security advisories | Comment on PR with reason; leave open |

Sensitive package list defaults: `react`, `next`, `vue`, `svelte`, anything
matching `^@types/node$`, `eslint`, `typescript`, ORM packages (`prisma`,
`drizzle-orm`, `typeorm`), test frameworks (`vitest`, `jest`, `playwright`),
bundlers (`vite`, `webpack`, `turbo`, `rollup`).

Override via `.claude/dep-sweep-config.json`:
```json
{
  "sensitive": ["@my-org/internal-sdk"],
  "always_hold": ["legacy-package"],
  "auto_merge_minor": false,
  "base_branch": "release"
}
```

## Workflow

### Phase 1 — Enumerate
```bash
gh pr list --state open --json number,title,author,headRefName,labels,baseRefName \
  --jq '[.[] | select(.author.login | test("dependabot|renovate|pre-commit-ci"))]'
```

If empty: STOP with "No bot PRs open."

### Phase 2 — Classify
For each PR, fetch:
- `gh pr view <n> --json files,additions,deletions`
- Title parsing for bump type (`major|minor|patch` from semver delta)
- Files changed (lockfile-only? config? runtime imports?)

Assign bucket per the table above. Show the classification table to user:

```
AUTO-MERGE (12):
  #421 chore(deps): bump @types/node 22.7 → 22.8
  #423 chore(deps-dev): bump vitest 1.6.0 → 1.6.1
  ...
REVIEW (4):
  #418 chore(deps): bump next 14.2 → 14.3
  ...
HOLD (2):
  #410 chore(deps): bump react 18 → 19          [major]
  #415 chore(deps): bump prisma 5 → 6           [major, ORM]
```

### Phase 3 — Confirm
Single user confirmation: "Auto-merge the 12 AUTO-MERGE PRs into `release`,
surface the 4 REVIEW for you, leave the 2 HOLD with explanatory comments? (y/N)"

On `n`: STOP and ask which buckets to act on.

### Phase 4 — Auto-merge bucket
For each AUTO-MERGE PR, in parallel batches of 3:
- Verify base branch is `release` (or the configured base)
  - If base is `main`, retarget to `release` via `gh pr edit --base release`
- Invoke `pr-merge-readiness` — must return MERGE
- On MERGE: squash-merge
- On WAIT/FIX: demote to REVIEW bucket, comment on PR with reason

Stop the parallel processing if 3 consecutive merges fail (likely systemic CI
issue) and surface to user.

### Phase 5 — Review bucket
For each REVIEW PR, produce a one-paragraph summary:
- What changed (link to dep changelog if visible)
- Why bumped (security advisory? scheduled?)
- CI status
- Suggested action (merge / wait / close)

Surface as a single decision list. Do NOT auto-merge this bucket.

### Phase 6 — Hold bucket
For each HOLD PR, leave a comment:
> "Held by `/dep-sweep` because: <reason>. Requires manual review before merge."

Apply label `needs-human` if it doesn't already have one.

### Phase 7 — Changelog batch entry
After auto-merges complete, append a single line under `[Unreleased]`:
> `### Changed`
> `- Bumped N dependencies (devDeps + patches). See PRs <list>.`

This collapses 12 individual changelog entries into one. The next `/release-cut`
includes that line as one bullet.

### Phase 8 — Nudge
If `release..main` count is now ≥ 5: print the `/release-cut` nudge.

## Stop / escalation conditions

- 3 consecutive AUTO-MERGE failures → halt and surface (CI may be broken)
- A bot PR has a human review with CHANGES_REQUESTED → skip and treat as HOLD
- Repo has no `release` branch → bail out and recommend `/merge-confidently`
  for direct-to-main flow OR creating the release branch first
- Dependency in any PR matches `always_hold` → force HOLD regardless of other signals

## Reconciliation

```
DEP SWEEP — <repo>
  Enumerated:    18 bot PRs <STATUS>
  Auto-merged:   12 into release (devDeps + patches) <STATUS>
  For review:    4 (next 14.2→14.3, eslint 9.0→9.1, ...) <STATUS>
  Held:          2 (react v19 major, prisma v6 major) <STATUS>
  Changelog:     1 batched line added under [Unreleased] <STATUS>
  Nudge:         release is now 7 commits ahead of main — consider /release-cut <STATUS>
  Snapshot:      <path to state file | (none — task ongoing)>
  Open watch:    <future obligation | (none)>
```

## Outputs / Evidence

- Per-bucket PR list with bump deltas
- Auto-merge SHA list
- Comments left on HOLD PRs
- Single batched CHANGELOG entry

## Configuration

Repo-level overrides live in `.claude/dep-sweep-config.json`:
```json
{
  "base_branch": "release",
  "sensitive": ["@my-org/internal-sdk"],
  "always_hold": ["webpack"],
  "auto_merge_minor": false,
  "auto_merge_dev_deps": true
}
```

## What this composite is NOT

- Not a security-vuln workflow → use `/security-sweep` for advisories
- Not a single-PR review tool → use `/pr-to-release` for one PR at a time
- Not a release cut → use `/release-cut` after sweep accumulates enough

## Pairs with

- `/pr-to-release` — for non-bot PRs that pile up
- `/release-cut` — fires once the sweep has bulked up `release`
- `/security-sweep` — when bumps are security-driven
