# Skill Auto-Invoke Rules

Workflows that auto-trigger based on task shape, not only on explicit slash commands.

> **Pruned 2026-07-09** (21-day usage audit + T2 critic gate): 26 zero-use trigger rows
> removed here and 17 match branches removed from `composite-router.sh`. Every pruned
> skill remains fully invocable by explicit `/name` — only the auto-advertise is gone.
> Deliberately KEPT despite zero measured use: `incident-response`, `debug-deep`
> (emergency paths; a missed prod-incident route costs more than their token noise) and
> `pr-to-release` (conditional target of the still-used merge intent). 14-day
> false-negative watch: if a real intent stops routing, restore its row from git.

## Composite-first principle

**When multiple skills could fit and one is a composite that chains those skills, ALWAYS prefer the composite.**

Composites enforce auto-chaining (sub-skill A's output feeds B), reconciliation, and stop conditions that individual skills do not. Invoking the composite prevents the bail-out failure mode where individual skills stop at "needs follow-up" and never get chained.

Example: when the user says "the test suite is bad" — invoke `fix-the-suite` (which chains test-health → config-drift-detect → test-cleanup → mutation-test → adr-write), NOT `test-cleanup` alone.

## Composite triggers (auto-invoke when intent matches)

### Per-task composites

| Composite | Trigger phrases / intent |
|---|---|
| `merge-confidently` | "merge this", "ship this PR", "is this ready to merge" — DIRECT-TO-MAIN repos only |
| `pr-to-release` | "open a PR", "merge this", "ship this change" — when a `release` branch exists. Lands the change on `release` with a single `[Unreleased]` changelog line; does NOT cut a version |
| `release-cut` | "cut the release", "promote release branch", "ship the batch", "tag a version" — merges `release` → `main`, tags, cleans up stale branches. MANUAL fire only; auto-nudge when `main..release` ≥ 5 commits |
| `hotfix` | "prod is down", "hotfix", "emergency fix", "P0", "SEV-1/2", "users can't X right now" — bypasses release branch, patches main directly, cherry-picks back to release |
| `ship-it` | "deploy to prod", "release this", "deploy to production" — post-merge deployment workflow. Pair with `/release-cut` Phase 10 for batched flow |
| `debug-deep` | bug user already tried to fix once, "intermittent", "sometimes fails", "in production but not local", recurring CI pattern |
| `research-and-decide` | "should we use X or Y", "is X worth adopting", "evaluate Z", library/framework/SaaS choice |
| `knowledge-loop` | "remember this", "save this", "what did we decide about X", end-of-task checkpoint |
| `incident-response` | "prod is down", "users reporting X", "Sentry firing", post-deploy new errors, intermittent in prod (Phases 1–2: triage + mitigate); OR "postmortem", "incident review", "what did we learn", "write up the incident" (Phase 3) — Phase 3 auto-queued by `/hotfix` Phase 10 and after any production rollback |
| `branch-hygiene` | "branch hygiene", "clean up branches", "prune branches", "stale worktrees", "git is a mess"; auto-suggest when local branch count > 30 at session start; queued weekly per active repo |
| `backlog` | "build a backlog", "generate a backlog", "find gaps", "find opportunities", "what should I work on", "what's missing in this repo", "refactoring opportunities", "audit and plan", "comprehensive backlog", "project audit and plan"; auto-suggest after `/onboard-new-repo` Phase N as the "ok, now populate the work queue" follow-up; produces ranked GitHub issues + Project board cards in one chained workflow |

### Periodic / lifecycle composites

| Composite | Trigger |
|---|---|
| `audit-deep` | "is this project healthy", "audit the repo", weekly per active repo, pre-release |

### Maintenance composites

| Composite | Trigger |
|---|---|
| `docs-sync` | After editing any skill / standard / hook (file in `~/.claude-env`, `~/.claude`, or `~/.agents`) |

## Core skill auto-invocation (single skills, only when no composite matches)

- `route` — when the right workflow is not obvious AND no composite matches
- `next-priority` — when entering a repo or deciding what to do now
- `plan` — for multi-step, risky, or ambiguous work
- `secure` — for config, auth, credentials, tokens, deployment, or dependency security work
- `ci-watch` — for failing checks or repeated CI noise
- `verify` — before merge, release, or handoff
- `ship` — when a branch is merge-ready (use ONLY if merge-confidently doesn't fit better)
- `handoff` — when context is tight or work will switch sessions
- `repaint` (the one frontend skill: register-lock, reference-anchor, token-spec, scaffold, build, slop-audit, verify pipeline in production / art-direction / polish modes) is the route for ANY non-trivial UI work: build, restyle, polish, or audit. Its Phase 4 runs the slop audit inline, so no separate lint chain is needed. Auto-invoke when ANY of these phrases appear:
  - **Personal portfolio register**: "build me a portfolio" / "personal site" / "personal website" / "about me page" / "homepage for me" / "redesign my portfolio" / "improve my portfolio" / "[named person] portfolio"
  - **SaaS landing register**: "landing page" / "homepage for our product" / "pricing page" / "pricing tier visualization" / "convert visitors" / "marketing site" / "make it look like Stripe / Linear / Vercel"
  - **Product-app register**: "dashboard for [tool]" / "admin panel UI" / "in-app workflow design" / "post-login surface"
  - **Marketing register**: "launch page" / "blog post layout" / "campaign page" / "manifesto page" / "release announcement"
  - **Docs register**: "API reference page" / "developer docs design" / "knowledge base UI" / "help center"
  - Gate 0.5 (register lock) handles ambiguous phrases by surfacing a disambiguation question.
  - **Art-direction / immersive**: "bold / editorial / experimental / award-style / immersive / motion-heavy hero or page", "make it unforgettable", "kill the cliche"
  - **Polish / audit**: "audit this UI for slop", "does this look generic", "lint this page", "polish this UI", "accessibility pass" (repaint polish mode / Phase 4 audit replaces the old standalone slop-lint)
- **Observability** (consolidated 2026-06-06 into the single `observe` skill — was a router + 7 fragments):
  - `observe` — one self-contained skill with internal **modes**. Route any observability-or-monitoring intent here; it picks the mode:
    - **Implement**: "instrument <service>" / "add logging / metrics / traces" / "wire up Sentry / OTEL / Prometheus" / "this service has no observability"
    - **Debug**: "alert flapping" / "metric missing" / "no data in dashboard" / "logs not arriving" / "drain not delivering" / "monitoring went silent"
    - **Tune**: "metrics bill too high" / "cardinality explosion" / "retention" / "sample rate too high" / "drop labels"
    - **Analyze**: "what happened at <time>" / "why did p95 spike" / "build a PromQL/LogQL/SQL for" / "correlate logs with traces" / "investigate this anomaly"
    - **Monitor** (practice layer): "we have metrics but no alerts" / "set up SLOs / SLIs / error budgets" / "create on-call rotation" / "add synthetic / uptime checks" / "build a Grafana dashboard for <service>"
    - **Bootstrap** (greenfield, full stack in one pass): "set up observability and monitoring for <new service>" / "this service is going to prod next week"
    - **Audit** (existing-service health review): "audit observability for <service>" / "quarterly monitoring review" / "post-incident observability review"
  - **Distinct from:** `/debug-deep` (generic app-bug tracing), `/incident-response` (live incident handling), `/sentry` (Sentry-specific MCP-driven workflow), `/langfuse-observe` (LLM-app tracing specifically), Vercel plugin's `/observability` (Vercel-platform-specific).
  - **Pre-condition:** don't wire the full stack on local-only / hobby code with no production-shaped target. One invocation = one mode.

## Individual skill triggers (hook-routed)

These single skills are pattern-matched by the `composite-router` hook, which emits a
` Skill match: /<name>` systemMessage. They fire **only when no composite matches first**
(composite-first principle) — the hook evaluates every composite before this cluster, and
the broad `scope-and-execute` / `parallel-phases` catch-alls last. When you see the hint,
invoke that skill. Triggers are high-precision to avoid false positives.

| Skill | Trigger intent (examples) |
|---|---|
| `code-review` | "review this PR/diff/code", "code review", "critique this code", "look over my diff". Default = chat report; posts to a PR only with explicit `--pr N --comment` |
| `adr-write` | "write an ADR", "document/record this decision", "capture the decision" |
| `performance-audit` | "performance audit", "profile this function/endpoint/query", "why is X slow", "find the bottleneck" |
| `config-drift-detect` | "config drift", "gate mismatch/conflict", "coverage threshold drift" |
| `handoff` | "hand off", "wrap up this session", "save context for next session" |

To add another individual skill: append a matcher in `composite-router.sh` (after the
composite block, before the `scope-and-execute` catch-all) and add its name to the
non-composite `case` in the emit at the bottom of that hook, then mirror + commit.

## Auto-chain pairs (when one fires, queue the next)

- `test-cleanup` outputs → ALWAYS chain `mutation-test` to validate survivors
- Any skill edit → ALWAYS chain `docs-sync` to mirror across roots
- Pre-`ship` → ALWAYS chain `pr-merge-readiness` (or invoke `merge-confidently` instead)
- Pre-`refactor` → ALWAYS chain `config-drift-detect` to surface gate conflicts first
- After hook wiring → ALWAYS queue `hook-effectiveness` for next session
- Bail-out from any skill → ALWAYS queue `skill-effectiveness-audit` for next scheduled run
- Major decision made → ALWAYS chain `adr-write` to capture rationale
- After every `pr-to-release` merge → check `main..release` commit count; if ≥ 5, surface `/release-cut` nudge in the reconciliation block
- After `dep-sweep` auto-merges → check `main..release` count; same nudge applies
- After `hotfix` merges to main → ALWAYS cherry-pick back to `release` (Phase 10 of hotfix) so the next `/release-cut` does not re-introduce the regression
- After `hotfix` Phase 10 completes → ALWAYS auto-queue `/incident-response` Phase 3 (post-mortem: adr-write → generate-tests → security-sweep conditional → knowledge-loop → handoff). Defer if <6h since incident.
- After any revert/rollback to main → ALWAYS queue `/incident-response` Phase 3 (post-mortem) for the next session
- `repaint` runs its slop + experience + accessibility audit inline as Phase 4 (its last pipeline step); do not declare UI done while criticals remain. No separate audit-skill chain is needed. When a project has no `DESIGN.md`, repaint authors one during its token-spec phase.

## Release-branch model (when applicable)

When a repo has a long-lived `release` branch on origin, route PR/merge intent
through this chain instead of direct-to-main:

- New work / fixes → `/pr-to-release` (lands on `release`, no version cut)
- Bot PRs piled up → `/dep-sweep` (batches into `release`)
- Enough on `release` → `/release-cut` (one promotion → main, one tag, one release)
- Production breakage that cannot wait → `/hotfix` (only acceptable bypass)
- First contribution to a new repo → `/onboard-new-repo` then `/pr-to-release` (lands the first change on `release` if that branch exists)

The whole point is to STOP shipping a new version for every small fix.
`/pr-to-release` does NOT call `version-bump` or `ship`. Only `/release-cut`
and `/hotfix` create tags.

## Negative rules

- Do NOT auto-invoke specialized domain skills unless the task clearly matches them
- Do NOT auto-invoke expensive workflows (mega-composites like `feature-from-zero`) for trivial one-file edits
- Do NOT invoke `session-bootstrap` mid-session — only on first non-trivial prompt
- Do NOT invoke `incident-response` for dev-time bugs — use `debug-deep` instead
- Do NOT invoke individual sub-skills when their composite covers the same intent (composite-first principle)

## Precedence when multiple match

If two composites both match the user's intent:
1. Prefer the more specific (`incident-response` over `debug-deep` if production-impacting)
2. Prefer the more contained scope (`scope-and-execute` over `feature-from-zero` if not greenfield)
3. Prefer the read-only diagnostic before the action (`test-health` before `fix-the-suite` if state is unknown)

If unsure, invoke `route` to decide.
