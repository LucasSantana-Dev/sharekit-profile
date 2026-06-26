# Monthly Gate Policy

## Purpose

Codex automations support weekly schedules well, but not true monthly schedules.
Use a weekly trigger plus a first-Monday gate for backlog triage.

## Gate rule

A recurring backlog-triage run executes only when:

- local day-of-week is Monday, and
- day-of-month is `1` through `7`

Any other recurring run returns `monthly_gate_skip`, writes artifacts, and leaves
queue state untouched.

## On-demand behavior

`--mode on-demand` bypasses the first-Monday gate so the backlog can be reviewed
manually between scheduled runs.
