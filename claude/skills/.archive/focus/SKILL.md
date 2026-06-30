---
name: focus
description: Focus context on a specific development area. Use when switching between
  features, domains, or subsystems to reduce noise and improve relevance.
argument-hint: <area> (e.g., auth, frontend, backend, database, testing, payments)
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.agents/skills/focus
---














Focus the session on the **$ARGUMENTS** area of the codebase.

## Steps

1. Identify all files, modules, and tests related to `$ARGUMENTS`
2. Summarize the current state of that area (recent changes, open issues, key files)
3. Set mental context: only suggest changes relevant to this area
4. List the top 3-5 files you'd start with for any task in this area

## Area hints

| Area | Key paths / patterns |
|------|---------------------|
| auth | `auth/`, `middleware/`, `session`, `login`, `signup`, JWT, cookies |
| frontend | `components/`, `pages/`, `app/`, hooks, UI, styles, Tailwind |
| backend | `api/`, `routes/`, `services/`, handlers, middleware |
| database | `migrations/`, `schema`, `models/`, queries, RLS policies |
| testing | `__tests__/`, `*.test.*`, `*.spec.*`, fixtures, mocks |
| payments | `billing/`, `stripe`, `subscription`, pricing |
| mcp | `tools/`, `server`, MCP protocol, Zod schemas |

After focusing, confirm what area is active and suggest what to work on.

## Outputs / Evidence

- Return the checks run, evidence captured, blockers found, and the next required action.

## Failure / Stop Conditions

- Stop if required credentials, environment access, or prerequisite context are missing.
- Stop if the workflow would report unverified work as complete.
- Do not bypass required gates or safeguards unless the user explicitly asks for it.

## Memory Hooks

- Read memory when product, repo, or workflow history affects correctness.
- Write memory only if this work establishes a durable policy or convention.
