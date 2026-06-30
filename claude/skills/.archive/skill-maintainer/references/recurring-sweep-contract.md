# Recurring Sweep Contract

## Purpose

Run a weekly skill-platform maintenance sweep that combines the maintainer audit,
curated routing-smoke checks, safe self-heal, and delta reporting.

## Weekly contract

- Cadence: Monday 09:00 America/Sao_Paulo
- Mode: `weekly`
- Scope: `full`
- Self-heal policy: `safe`
- State path: automation-owned directory under `$CODEX_HOME/automations/<id>/state`
- Artifacts: timestamped JSON and Markdown reports in `/tmp`

## Required outputs

- before audit counts
- safe fixes applied
- after audit counts
- manual follow-up categories
- curated routing-smoke status
- delta from previous successful weekly run

## Input gate policy

If any future extension of the sweep reaches sign-in, sign-up, or personal-data
steps, stop and ask for user input instead of continuing unattended.

## On-demand contract

Use `--mode on-demand` for focused review paths such as `aliases`, `wrappers`,
`routing`, or `backlog`. On-demand runs default to `self-heal=none` and should
not update weekly comparison state unless explicitly requested.
