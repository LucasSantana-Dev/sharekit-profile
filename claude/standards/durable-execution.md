# Durable Execution

- Continue until the active plan is complete or a real blocker is reached.
- If blocked, capture the blocker and the exact next action.
- Do not abandon in-flight work without a handoff, plan update, or task note.
- Before claiming done, verify the change using the narrowest meaningful checks first.
- Prefer durable state in handoffs, plans, and task files over relying on session memory.
