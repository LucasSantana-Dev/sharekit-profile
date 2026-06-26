# Demand Evidence Policy

## Allowed local sources

- `post-wave3-gap-backlog.md`
- local memory: `~/Desenvolvimento/forge-space/.agents/memory/forge-space.md`
- local reports under `~/Desenvolvimento/forge-space/.agents/reports/`
- local queue state in `~/Desenvolvimento/forge-space/.agents/task-queue.json`
- installed `SKILL.md` files across the three skill roots
- automation TOML files under `$CODEX_HOME/automations/`

## Explicit exclusions

- `~/.codex/archived_sessions`
- GitHub issues, PRs, Actions, or any other external system
- browser-authenticated or personal-data sources

## Evidence classes

- `backlog_baseline`: candidate is registered in the backlog. This keeps the item in scope but does not count as repeated demand.
- `explicit_token`: candidate appears as an explicit capability token such as `` `email-sequence` `` in memory, reports, or queue artifacts. This counts toward repeated demand.
- `demand_signal`: structured queue or report evidence that clearly names the capability. This counts toward repeated demand.
- `routing_gap`: guidance inside installed skills or automation docs that a capability may be missing. This is recorded for context but does not promote a capability on its own.
- `resolved_alias_or_skill`: the capability already exists as an installed skill. This resolves the backlog item without queue promotion.

## Promotion rule

Promote a capability to the local queue only when at least two distinct demand-bearing
sources exist across `memory`, `reports`, or `queue`.

Backlog registration and routing-gap references are informative, not sufficient.
