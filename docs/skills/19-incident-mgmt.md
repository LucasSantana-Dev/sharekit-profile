# Incident Management Skills

`incident-response` to coordinate a live production issue. `production-incident` (composite) for the full triage-to-fix-to-ADR chain. `incident-followup` after the incident is resolved, to run the post-mortem and close the loop.

---

## /incident-response

Coordinate incident response using Sentry, Linear, and GitHub to triage, correlate, and track production issues.

**Workflow:**
1. Inspect Sentry issue + stack trace
2. Correlate with recent deploys
3. Create incident ticket (Linear)
4. Notify team (Slack)
5. Track resolution

**When to use:** Production error detected

**Output:** Incident ticket + team notified

---

## /production-incident ⭐⭐ **Composite**

Full production incident workflow: sentry → debug-deep → incident-response → ship-it → adr-write.

**Phases:**
1. **Sentry:** Inspect issue + correlate with deploys
2. **Debug:** Deep systematic root-cause analysis
3. **Response:** Coordinate fix + tracking
4. **Ship:** Get fix to production immediately
5. **ADR:** Document incident + prevention

**When to use:** Production issue confirmed + requires immediate fix

**Output:** Fixed production + incident record

---

## /incident-followup ⭐⭐ **Composite**

Post-mortem chain: adt-research → adr-write → regression-test → security-sweep (if applicable) → knowledge-loop.

**Phases:**
1. **Research:** Deep dive into what went wrong
2. **ADR:** Document root cause + prevention measures
3. **Test:** Write regression test (prevent recurrence)
4. **Security:** If security-relevant, run full sweep
5. **Knowledge:** Capture lessons into memory + documentation

**When to use:** Incident is resolved; need post-mortem

**Output:** Post-mortem + prevention measures + institutional learning

---

**Last updated:** 2026-06-25
