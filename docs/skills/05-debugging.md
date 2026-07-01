# Debugging Skills

Start with `debug` for bugs, test failures, CI failures, production errors, and unexpected behavior. The archived `debug-deep` and `systematic-debugging` details are now folded into `debug`.

---

## /debug

Systematic root-cause analysis. Do not guess; reproduce, trace, compare, test one hypothesis, then fix.

**Method:**
1. Reproduce reliably or gather more data.
2. Locate the failing file, line, call path, and boundary.
3. Inspect recent code, dependency, config, and environment changes.
4. Compare working vs. broken examples.
5. Form competing hypotheses with evidence tests.
6. Instrument boundary inputs/outputs when evidence is thin.
7. Fix only the proven cause.
8. Verify with the smallest failing check plus relevant gates.

**Stop conditions:**
- After two failed fixes, return to investigation.
- After three failed fixes, question the architecture or original assumption.
- Never bundle unrelated improvements into a bug fix.

**When to add external evidence:** CI logs, Sentry/production traces, browser/network traces, or dependency/config diffs when they are part of the failure surface.

**Output:** root cause, location, fix, verification evidence, and remaining risk.

**Last updated:** 2026-07-01
