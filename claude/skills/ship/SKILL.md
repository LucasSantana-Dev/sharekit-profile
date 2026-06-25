---
name: ship
description: Merge a ready PR or cut a release without skipping CI or review gates. Use for ready-to-merge work, release preparation, or merge-readiness checks. Refuses `--admin`, `--no-verify`, `--force-with-lease` against main.
triggers:
  - ship
  - merge this PR
  - prepare to merge
  - release-ready check
  - cut a release
  - prepare release
metadata:
  tier: execution
  owner: lucas
  canonical_source: standards/pr-conventions.md, standards/release-cadence.md
---

# ship

Merge a ready PR or cut a release—without skipping CI or review gates.

## Preconditions (all required)

- Goal is clear (title + body in PR, or release intent stated)
- Diff is understood (no surprises in file changes)
- Required checks green **or** failure proven unrelated (ref: `standards/pr-conventions.md §82`)
- No blocking review comments (CodeRabbit, Sonar, human reviewers all resolved)
- No obvious security or migration risk

**Done when:** all five preconditions confirmed.

## Step 1: Optional — Pre-ship history lookup

If this is a release-cut, query prior incidents or releases (fail-loud if External HD unmounted):

```bash
mount | grep -q "${DEV_ROOT}" || { echo "BLOCKED: External HD unmounted — release history inaccessible"; exit 1; }
rag_query(query="releases and incidents in last 14 days", top=3)
```

**Done when:** prior issues surfaced or no prior context found.

## Step 2: Validate merge readiness

Run `/pr-merge-readiness` for combined verdict (all gates). Surface verdict clearly:
- `✓ MERGE` — proceed to step 3
- `[WARN] WAIT` — blocker present; surface and halt
- `✗ FIX` — red CI or conflicts; fix first via `/ci-watch` or `/next-priority`, then re-check

**Done when:** verdict is MERGE.

## Step 3: Update docs / CHANGELOG if needed

If release: confirm CHANGELOG entry matches PR body `## Changelog` field (ref: `standards/pr-conventions.md §74–75`).

**Done when:** CHANGELOG updated or confirmed current.

## Step 4: Merge or release

- **Merge:** `gh pr merge --squash` (or merge-commit if documented in PR body)
- **Release:** `/release-cut` (handles version + tag + verification)

**Done when:** PR merged or release tagged + pushed.

## Stop conditions (surface and halt)

- Another user has blocking comments on the PR → surface blocker; do NOT merge
- CI red with unknown signal → surface cause; do NOT merge (use `/ci-watch` to triage)
- WIP work or not-ready state → surface precondition gap; do NOT merge

## Safety gates (non-overridable)

- **Never** use `gh pr merge --admin`, `--no-verify`, or `--force-with-lease` against `main`
- **Never** automate merge/release when PR has comments from another person (CLAUDE.md hard rule)
- **Never** cut release when `main..release` ≤ 1 commit (batch of 1 defeats purpose)
- See `standards/release-cadence.md` for full policy

## Output format

```
<VERDICT: MERGE | WAIT | FIX>

Findings:
- <top blocker or readiness signal>
- <second signal>
- <third signal>

Next: [merge now | fix X first | escalate to user]
```
