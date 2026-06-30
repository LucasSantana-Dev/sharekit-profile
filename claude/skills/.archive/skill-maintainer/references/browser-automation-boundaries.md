# Browser Automation Boundaries

Use this policy when maintaining browser-facing skills.

## browser-use

Choose `browser-use` when the workflow depends on:
- persistent browser sessions across commands,
- real Chrome profiles,
- remote browser-use tasks,
- browser-use-specific CLI commands and state model.

## agent-browser

Choose `agent-browser` when the workflow is:
- quick ref-based interaction,
- local scripted automation,
- element-reference navigation and capture,
- lighter than a Playwright test harness.

## webapp-testing

Choose `webapp-testing` when the workflow needs:
- Playwright-based reproducible checks,
- local server lifecycle handling,
- console logs, page errors, or route evidence,
- browser verification rather than browser automation alone.

## Maintenance rule

Do not let the three skills silently converge. Each one must state why it exists and where it should route away.
