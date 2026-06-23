---
name: scope-it
description: Map the blast radius of a task before writing any code. Identifies affected files, downstream dependencies, and likely test surface. Use before starting implementation to avoid scope creep or missed impact. Triggers: "scope this", "what will this touch", "how big is this change", "before I start".
metadata:
  owner: global-agents
  tier: ephemeral
  canonical_source: ~/.claude/skills/scope-it
---

# Scope It

Map what the task will actually touch before writing a single line.

## Workflow

1. **Read the task** — extract the specific function, module, or behavior being changed
2. **Find entry points** — locate the files and symbols directly involved
3. **Trace dependencies** — find callers of changed functions, importers of changed modules
4. **Identify test surface** — which test files cover the affected code?
5. **Estimate size** — count files likely to change (S: 1-3, M: 4-10, L: 11+)

## Output

```
Scope: <task summary>
────────────────────
Core files:     [files directly changed]
Dependents:     [files that import/call changed code]
Tests affected: [test files covering the scope]
Size:           S | M | L
Edge cases:     [behaviors to watch for during implementation]
Blind spots:    [areas that might be affected but need investigation]
```

## Rules

- Run before implementing, not after
- If size is L, stop and ask: can this be split?
- List blind spots explicitly — unknown dependencies are higher risk than known ones
