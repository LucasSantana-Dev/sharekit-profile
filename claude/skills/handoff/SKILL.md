---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
argument-hint: "What will the next session be used for?"
triggers:
  - handoff
  - hand off
  - resume from handoff
  - transfer context
---

Write a handoff document summarising the current conversation so a fresh agent can continue the work. Save to `$(~/.claude/bin/handoffs dir)/<YYYY-MM-DD>-<slug>-<HHMM>.md` (one file per session topic; several open handoffs per repo is normal). First line: `# <repo>, <dd/mm/yyyy>: <the topic in one line>`; the list shown to the next session uses it. Never write `latest.md` (single slot, clobbered by concurrent sessions). When a topic is finished, `~/.claude/bin/handoffs done <part-of-name>` (never by number) archives its handoff.

Include a "suggested skills" section in the document, which suggests skills that the agent should invoke.

Do not duplicate content already captured in other artifacts (PRDs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

If the user passed arguments, treat them as a description of what the next session will focus on and tailor the doc accordingly.

## Post-incident capture gate

Before writing the handoff, check if the session encountered any failures:

- **P0/P1 failures** (production incident, data loss, security failure, broken CI gate): if a committed root-cause artifact (ADR or incident-log entry) does not yet exist, flag it as an open action in the handoff: "OPEN: incident capture required before next task — root cause, fix applied, preventive action."
- **P2/P3 failures** (CI flake, test regression): write a brief memory note (if not already done) and include it in the handoff context.
- **Repeat root cause** (same failure ≥2× in 14 days): flag as requiring an ADR + prevention rule, not just a memory note.
