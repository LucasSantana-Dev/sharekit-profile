---
name: webapp-testing
description: Test a local web application with Playwright-based scripts, screenshots,
  browser logs, and reproducible checks. Use when the task is browser-level verification
  of a web UI rather than quick CLI automation or profile-driven browsing.
license: Complete terms in LICENSE.txt
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.agents/skills/webapp-testing
---









# Web Application Testing

Use this skill for Playwright-based verification of local or controlled web applications.

## Use When

- The task needs reproducible browser assertions, screenshots, console logs, or page-error capture.
- You need to run a local server and verify routes or flows end to end.
- The deliverable is evidence about webapp behavior, not just one-off interaction.

## Do Not Use When

- Use `agent-browser` for quick ref-based interaction loops.
- Use `browser-use` when the work depends on browser-use CLI sessions, real Chrome profiles, or remote browser-use tasks.

## Inputs / Prereqs

- Confirm the target URL or startup command.
- Check whether `scripts/with_server.py` can manage the required servers.
- Decide what evidence bundle is required per route or flow.

## Workflow

1. Start the app or review the existing running target.
2. Wait for `networkidle` before inspecting dynamic pages.
3. Write the smallest Playwright script that proves the requested behavior.
4. Capture screenshots, console logs, page errors, and route assertions.
5. Return the evidence bundle and any blockers.

## Outputs / Evidence

- The checks run, screenshots or logs captured, and the final pass or fail result.
- The route or selector assumptions used.
- Any missing env, auth, or startup prerequisite that blocked verification.

## Failure / Stop Conditions

- Stop if the local app cannot be started or reached.
- Stop if the task really belongs to `agent-browser` or `browser-use` instead of Playwright verification.
- Stop if the workflow would claim verification without waiting for the page to become stable.

## Load These Resources

- `scripts/with_server.py --help`
- example scripts in `examples/` only when the helper is not enough

## Memory Hooks

- Read memory when product, repo, or workflow history affects correctness.
- Write memory only if this work establishes a durable policy or convention.
