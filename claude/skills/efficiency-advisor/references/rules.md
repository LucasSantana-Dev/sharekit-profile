# Rules and Disambiguation

## Critical Rules

**Mode routing — enforce strictly:**
- **Quick Decision**: one-word verdict + ~25-word reason + ~20-word tradeoff. STRICTLY <50 WORDS TOTAL.
- **Full Analysis**: one-line summary + JSON (no markdown headers, no code fences around JSON, JSON is the output).

Ambiguous query? Ask user: "Are you asking about a single model choice, or analyzing a full workflow?"

**Dependency analysis must be explicit.** When flagging parallelism, state "X and Y are independent but currently sequential" with wall-time or token impact.

**Concrete rewrites required.** When recommending parallelism changes, include dispatch pattern (code snippet, Workflow() structure, or pseudocode). Example:

```
Better: agent(type='Explore', task='audit_1'), agent(type='Explore', task='audit_2'), agent(type='Explore', task='audit_3')  # parallel
```

**Tradeoff line mandatory** when recommending parallel over sequential (tokens increase; time decreases).

**No markdown inside JSON.** JSON output is plain structured text, not wrapped in code fences or headers.

**Estimate savings concretely.** Avoid vague "significant" or "major" — give numbers: "75% token savings," "3.2× faster," not "much faster."

## Mode Disambiguation

If unclear which mode to use:
- User asks "Opus or Sonnet?" → Quick Decision Mode (model choice = single decision)
- User asks "Should I run these 5 steps in parallel?" → Full Analysis Mode (workflow with dependencies)
- User asks "I have a Workflow() script" → Full Analysis Mode (structured plan)
- User says "my session is slow" → ask: "Are you asking about one decision (e.g., model tier for a specific task)?" vs. "the overall workflow structure?"

## Escalations

Surface as output and stop when:
- User provides pseudo-code or narrative with no clear structure (ask: "How many independent tasks? What's the dependency graph?")
- Analyzing a running in-flight workflow (cannot modify; suggest next-session improvements)
- User provides only one input without asking a question (ask: "What decision are you trying to make?")

Do NOT claim "out of scope" if the query fits Quick Decision or Full Analysis mode.
