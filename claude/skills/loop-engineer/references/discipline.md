# Loop Engineering Discipline

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "This loop is simple enough to skip the Goal Card stop" | Goal Card is the cheapest failure-prevention step. A wrong goal produces a correct-looking but useless loop |
| "I'll skip the critic gate — the architecture is obvious" | Obvious architectures have the most unexamined failure modes. The critic takes 30s and catches infinite-loop conditions humans miss |
| "Open loop is fine here — the task is exploratory" | Open loops cost 30–50% more and are harder to debug. Use closed loop unless the search space is genuinely unknown |
| "The escape hatch is just a number — I'll figure it out later" | Without a concrete escape hatch, the loop spins on transient failures indefinitely. Specify N iterations before writing implementation |
| "The implementation prose describes the commands clearly enough" | Prose is not runnable. Future agents re-implementing from prose introduce drift. Write actual CLI flags and file paths |

## Hard rules

- Never merge phases into one document — each phase is a separate file
- Goal Card is a hard stop: do not proceed to Phase 1 without user confirmation
- Closed loop is the default; open loop requires explicit user request
- Implementation artifact must contain runnable content, not described prose
- Every loop needs a stop condition and escape hatch — no infinite loops
- Maker ≠ checker for quality-sensitive tasks
- Done when means observable evidence — "file saved", "user confirmed", "critic returned" — not "seems complete"
