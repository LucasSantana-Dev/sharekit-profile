# Handoff: checkout 500s after deploy

## Active Objective
Triage checkout 500s seen after release v2.31.0 in acme/shop-api.

## Incident Flags
- INCIDENT P1 OPEN: checkout returned 500 for 12 min on 2026-10-06 (rollback done at 22:14).
- Root-cause artifact: NONE committed yet (no ADR, no docs/incident-log entry).

## What Remains
- Write docs/incident-log/2026-10-06-checkout-500.md
- Re-land the pricing refactor (PR #212) behind a flag

## ⚡ IMPLEMENT THIS
1. Add root-cause entry to docs/incident-log/.
2. Then rebase feat/pricing-refactor and re-open PR #212.
