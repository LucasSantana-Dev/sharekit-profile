# CI/CD Skills

`ci-watch` when a PR's checks are red and you need to understand and unblock them. `dep-sweep` (composite) to batch-process Dependabot/Renovate PRs safely. `adt-schedule` to define recurring automated runs.

---

## /ci-watch

Inspect current CI state, identify the first real blocker, and monitor until checks are green or understood.

**Process:**
1. Fetch Actions workflow status
2. Identify first failing step
3. Read step logs + failure message
4. Determine if blocker or flake
5. Monitor until resolved

**When to use:** PR checks red; need root-cause + monitoring

**Output:** CI status + blockers identified

---

## /dep-sweep ⭐⭐ **Composite**

Batch-process open Dependabot/Renovate PRs: group by risk → auto-merge safe → flag risky.

**Phases:**
1. **Discover:** Fetch all open dep PRs
2. **Group:** By risk (major, minor, patch, dev-only)
3. **Auto-merge:** Safe PRs (patches, dev deps)
4. **Flag:** Risky PRs (majors that need review)
5. **Monitor:** Verify merged PRs don't break CI

**When to use:** Dependency PRs accumulating; bulk dependency updates

**Output:** Merged safe deps + flagged risky deps

---

## /adt-schedule

Define and manage recurring automated agent runs — CI monitoring, dep updates, security scans.

**Defines:**
- Cron schedule (daily, weekly, etc.)
- Task (which skill/agent to run)
- Parameters (repo, scope)
- Notifications (Slack alert, email summary)

**When to use:** Setting up recurring automation

**Output:** Scheduled task configuration

---

**Last updated:** 2026-06-25
