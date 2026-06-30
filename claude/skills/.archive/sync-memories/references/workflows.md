# Reference: Workflows for Specific Repo Types

Extended workflows for specialized project structures. Use these when the generic 5-step flow doesn't fit your project shape.

## Forge-Space Repos (forge-patterns, mcp-gateway, uiforge-mcp, webapp)

Quick-sync workflow for Forge Space ecosystem projects:

### Gather Current State (Parallel)

```bash
# Version and test counts
node -p "require('./package.json').version" 2>/dev/null
npm test 2>&1 | grep "Tests:" | tail -1
npm test 2>&1 | grep "Test Suites:" | tail -1

# Recent work
git log --oneline -8
gh pr list --repo Forge-Space/$(basename $(pwd)) --state closed --limit 5

# Quality state
npm audit --audit-level=moderate 2>&1 | tail -2
npm run knip 2>&1 | grep -v "Configuration hints\|Remove from\|Refine" | head -3
npm run lint:check 2>&1 | tail -2
```

### Forge-Space Standard Memories

| Memory | Update Trigger |
|--------|---|
| `project_overview` | Version bump, test count change, new feature, PR status |
| `mcp_context_server_architecture` | MCP server changes, handler additions |
| `feature_toggle_system` | Toggle schema/namespace changes, CLI updates |
| `security_compliance_standards` | New security rules, validator additions |
| `development_workflow` | Script additions, CI/branch convention changes |
| `cross_project_integration` | Cross-repo dep updates, API contract changes |

Update `project_overview` with:
- Current version (from `package.json`)
- Test count and suite count
- Recent PRs merged
- New features, deprecated items
- Open/blocked PRs

### Verify After Update

```bash
serena.read_memory("project_overview")
# Check: version matches package.json, test count matches npm test output, recent work documented
```

---

## Monorepo Workspaces (pnpm, npm/yarn workspaces)

Use the root `package.json` for version + workspace list; update per-workspace memories independently.

```bash
# List workspaces
jq '.workspaces' package.json 2>/dev/null || cat pnpm-workspace.yaml | grep "  - " | cut -d' ' -f4

# For each workspace: gather state, update memory
for ws in packages/*; do
  cd "$ws"
  VERSION=$(node -p "require('./package.json').version" 2>/dev/null)
  TESTS=$(npm test 2>&1 | grep "Tests:" | tail -1)
  echo "$ws: v$VERSION, $TESTS"
  cd - >/dev/null
done
```

Update a separate memory per workspace (e.g., `ws_core_overview`, `ws_ui_overview`) to avoid mixing state.

---

## Python / Non-Node Projects

Adapt the patterns for your build system:

```bash
# Version (from setup.py, pyproject.toml, __init__.py, or VERSION file)
grep -E "^version|^__version__" setup.py pyproject.toml __init__.py 2>/dev/null | head -1

# Tests (pytest, unittest, etc.)
pytest 2>&1 | tail -3  # or: python -m unittest discover 2>&1 | tail -2

# Recent work
git log --oneline -8
git status
```

Memory categories remain the same; only command syntax changes.

---

## Static / Non-Code Projects (docs, design, content)

Skip test/version steps; focus on gotchas, decision state, and last-modified dates:

```bash
# Last meaningful change
git log --oneline -5 -- . | head -3

# File structure / organization
find . -type f -name "*.md" | head -10

# TODO / open items
grep -r "TODO\|FIXME\|XXX" . 2>/dev/null | head -3
```

Memory: document what changed this session, what's blocked, what decisions are pending.
