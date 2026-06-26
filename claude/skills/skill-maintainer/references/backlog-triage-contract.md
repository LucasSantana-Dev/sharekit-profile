# Backlog Triage Contract

## Purpose

Run a monthly-gated backlog review for missing skill capabilities without creating
skills or rewriting routing automatically.

## Recurring contract

- Trigger cadence: weekly schedule with a first-Monday gate
- Mode: `recurring`
- Default scope: `full`
- State path: automation-owned directory under `$CODEX_HOME/automations/<id>/state`
- Artifacts: timestamped JSON and Markdown reports in `/tmp`
- Outputs: per-candidate classification, evidence summary, queue actions, and delta
  from the previous successful triage run

## On-demand contract

Use `--mode on-demand` for manual checks between scheduled runs.

- `--scope full`: evaluate all backlog candidates and update queue tasks if warranted
- `--scope candidate --candidate <name>`: evaluate one capability only
- `--scope report-only`: produce artifacts without mutating the queue

## Queue contract

- Only create or update deterministic queue tasks named `skill-backlog-triage-<capability>`.
- Never create duplicate open tasks for the same capability.
- Do not edit skills, backlog files, or canonical routing from this automation.
