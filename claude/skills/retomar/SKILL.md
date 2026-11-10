---
name: retomar
description: "Alias for the resume skill that the Claude desktop app does not intercept (its native /resume opens the session picker). Use for /retomar, /retomar N, retomar handoff."
triggers:
  - retomar
  - retomar handoff
user-invocable: true
---

# retomar

The desktop app catches `/resume` and opens its own "Retomar uma sessão" picker, so the
`resume` skill never runs from there. `/retomar` is the same entry point under a name the
app does not own.

Invoke the `resume` skill now with the same arguments (`N`, a handoff slug, or `--brief`)
and follow it exactly. Do not reimplement it here.
