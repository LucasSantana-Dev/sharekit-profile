---
name: route
description: Choose the right skill/workflow when intent is ambiguous or spans multiple tools. Use when prompt is broad ("look into X", "what next", "fix this"), spans phases (plan + ship + verify), or could match multiple skills. Composite-first routing per `skill-auto-invoke.md` §Composite-first. Outputs chosen skill + why. Skip if user explicitly named a single skill.
metadata:
  tier: sonnet
  owner: lucas
  canonical_source: ~/.claude/standards/skill-auto-invoke.md
triggers:
  - route
  - which skill should handle this
  - what workflow fits
  - ambiguous task shape
---

# route

Decide which skill, composite, or workflow fits when the right path is not obvious.

**Stop condition:** If intent remains ambiguous after Step 2, ask instead of guessing.

## Decision sequence

**Step 1: Check for composite match.**
Done when: you've scanned `skill-auto-invoke.md` §Composite triggers for the first matching pattern (composite-first principle — composites take precedence over sub-skills).

Scan in order: per-task composites, then periodic/lifecycle, then maintenance. Stop at first match.

**Step 2: Check active in-flight state.**
Done when: you've confirmed open PR, failing CI, active handoff, or active plan — if found, route to resolution skill (ship, ci-watch, resume, etc.) over greenfield work.

**Step 3: Route to smallest fitting single skill.**
Done when: you've selected from `skill-auto-invoke.md` §Core skill auto-invocation the narrowest skill that covers the intent.

If still ambiguous after Step 3 (two skills equally fit), HALT and ask.

## Output format

Lead with verdict:
- **Chosen:** [composite or skill]
- **Why:** [one-sentence rationale] 
- **Evidence:** [which decision step matched]

## RAG note

N/A. Routing is decision-logic not fact-lookup. Do not query RAG/knowledge-brain.

## Failure / Stop Conditions

- If the request maps to two composites with equal weight → surface both and ask; do not pick silently.
- If no skill fits → fall back to `plan` (it handles the general "figure out what to do next" shape).
- Do not route to a composite when a simpler single skill is clearly sufficient — composite overhead is only warranted when the chain is necessary.

## Memory Hooks

- Read memory if the request touches a domain with prior decisions (auth, CI, release pipeline) to confirm the routing is still correct.
- No write — routing decisions are ephemeral and not worth persisting.
