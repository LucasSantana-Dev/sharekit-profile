---
name: ci-watch
description: "Diagnose failing CI checks, isolate the first real blocker (vs. noise), and surface the smallest viable fix. Use when a PR has failing checks, the pipeline is broken, CI is red before merge/release, or you need to understand why tests are failing."
metadata:
  tier: sonnet
  owner: core-infra
triggers:
  - ci watch
  - failing checks
  - check the pipeline
  - why is CI red
  - diagnose test failures
---

# ci-watch

Diagnose broken checks, flaky tests, or merge-blocking pipeline noise. Isolate the first real blocker from noise, then surface the smallest viable fix.

## Steps

1. **Query prior CI failures** — Mount guard + RAG pre-check for similar failures on this repo before diagnosing fresh.
   - Done when: mount verified OR fallback logged; RAG query returned ≥1 prior incident OR "no prior similar failures"

2. **Identify the active PR or HEAD commit** — Read current branch/commit SHA.
   - Done when: PR number or commit SHA confirmed

3. **List non-passing checks** — Run `gh pr view N --json statusCheckRollup` (or HEAD if not PR context).
   - Done when: ≥1 failing check listed with full name and status

4. **Separate required vs. advisory** — Filter checks against branch protection rules (`gh repo view --json defaultBranchRef`); required failures block merge, advisory do not.
   - Done when: required failures isolated; advisory listed separately

5. **Inspect first failing job deeply** — Read full job logs, extract error snippet, name root cause (syntax, missing dep, timeout, flakiness, unrelated test).
   - Done when: error message quoted; suspected root cause named

6. **Surface smallest viable fix** — Propose the one-line or minimal change that unblocks CI, or confirm failure is unrelated.
   - Done when: fix specified OR blocklist rule named (e.g., "unrelated flake; merge after rerun")

## Output format

Emit reconciliation wrapper with signal-first summary:

```
CI-WATCH — [PR#N or HEAD] — [BLOCKED | READY | NEEDS_RERUN]

**First blocker:** [job name + error snippet (1–2 lines)]
**Root cause:** [specific reason]
**Owner surface:** [file/module affected]
**Smallest fix:** [exact change or rerun reason]
**Shipping status:** [yes/poll-rerun/no + reason]
```

## Pre-check: RAG + mount guard

Before diagnosing from scratch, check prior incidents (speeds diagnosis by ≥60% on recurring gotchas):

```bash
# Mount guard (External HD holds RAG index & embedder cache)
mount | grep -q "${DEV_ROOT}" || { echo "BLOCKED: External HD unmounted — RAG unreachable"; exit 1; }

# Query prior CI failures on this repo
python3 ~/.claude/rag-index/query.py "CI failures on this repo" --top 5 --fast
```

If RAG unavailable, fall through to grep + log inspection. If found prior incident, check whether same root cause.

## PR state machine

Read `gh pr view N --json mergeable,mergeStateStatus,reviewDecision` first, then:

| mergeable / state | Action |
|---|---|
| `MERGEABLE` + `CLEAN` | proceed to merge |
| `MERGEABLE` + `UNSTABLE` | non-required check failing or pending; poll required-only checks |
| `MERGEABLE` + `BEHIND` | `gh pr update-branch` or local rebase + force-push |
| `MERGEABLE` + `BLOCKED` | check `reviewDecision` and branch protection; if self-PR → enforce_admins toggle pattern |
| `CONFLICTING` + `DIRTY` | local rebase first; if `git merge-tree` reports clean but GH disagrees → webhook desync, close+recreate PR |
| `UNKNOWN` + `UNKNOWN` | GitHub still computing — wait 15s, recheck once; if STILL UNKNOWN, try `gh pr merge` directly (may already be merged) |

## Polling with Monitor

For checks that take >1 min to settle, use the `Monitor` tool with an until-loop instead of busy-waiting (see standards/workflow.md § durable-execution):

```bash
until s=$(gh pr view N --json statusCheckRollup); \
  pend=$(echo "$s" | python3 -c "..."); [ "$pend" = "0" ]; do sleep 15; done
```

Don't issue a single long `sleep` — the harness blocks chained sleeps.

## Common gotchas

- `UNKNOWN` often means the PR was already merged in another window. Verify with `gh pr view N --json state` before re-arming a monitor.
- `mergeStateStatus: BLOCKED` with no failing checks = review or branch protection. Look at `requiredStatusChecks` + `requiredApprovingReviewCount`.
- `BLOCKED` + all green + bot review threads (CodeQL, CodeRabbit, Greptile) = unresolved conversation. Bots are not "another person" — auto-resolve via `resolveReviewThread` GraphQL mutation.
- A PR head SHA that disagrees with `git ls-remote` for its branch ref = webhook desync. Close + recreate, don't try to nudge.

---

## Mode B: Design CI Pipelines

To add, fix, or restructure a pipeline (not just diagnose a failure), see `references/ci-design.md`.
