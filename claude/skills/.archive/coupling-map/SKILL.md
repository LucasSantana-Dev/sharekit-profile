---
name: coupling-map
description: Generates a coupling map showing which modules depend on which, highlighting hotspots that resist safe refactoring.
  Map module coupling via import graph analysis. Identifies high fan-in (many callers) and high fan-out (many dependencies) nodes, and surfaces cycles. Use when planning a refactor, evaluating testability, or identifying brittle modules. Triggers: "coupling map", "module coupling", "dependency map", "fan-in fan-out", "import graph", "find tightly coupled code".
metadata:
  owner: global-agents
  tier: ephemeral
  canonical_source: ~/.claude/skills/coupling-map
---

# Coupling Map

Find which modules are hardest to change and why.

## Workflow

1. **Build the import graph** — for each source file, extract its direct imports:
   ```bash
   # Example for any language: find import/require/use/include statements
   grep -r "^import\|^from\|^require\|^use " src/ --include="*.{ts,js,py,go,rs}"
   ```

2. **Calculate fan-in** (how many other modules import this module) — sort descending. High fan-in = high blast radius when changed.

3. **Calculate fan-out** (how many modules this module imports) — sort descending. High fan-out = many dependencies = harder to test in isolation.

4. **Find cycles** — any module chain where A → B → ... → A. Use a simple DFS or existing tool:
   - JS/TS: `npx madge --circular src/`
   - Python: `pydeps --noshow src/`
   - Go: `go list -f '{{.ImportPath}} {{.Imports}}' ./...`

5. **Identify coupling hotspots** — modules that appear in BOTH top-10 fan-in AND top-10 fan-out lists. These are the highest-risk modules.

## Output

```
Coupling Map
────────────
High Fan-In (most depended-on):
  1. utils/logger — imported by 42 modules
  2. core/config — imported by 38 modules

High Fan-Out (most dependencies):
  1. services/orchestrator — imports 18 modules
  2. api/router — imports 14 modules

Cycles detected: 3
  - auth/session → user/store → auth/session
  - ...

Hotspots (high fan-in AND fan-out):
  - core/db — 29 importers, 11 imports (refactor candidate)
```

## Rules

- Report only; do not refactor. Hotspots are candidates, not mandates.
- Cycles are always flagged regardless of size.
- A module with fan-in > 20 should be treated as a public API — any change needs extra review.
