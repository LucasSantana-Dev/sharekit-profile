---
name: quality-gates
description: Defines binary quality gates (lint-pass, tests-green, no-secret-leaks) that must all pass before a PR is mergeable.
  Run the repository-native verification gates such as lint, type-check,
  tests, docs, build, and security checks. Use when the user wants confidence before
  a commit, PR, merge, or release.
disable-model-invocation: true
context: fork
allowed-tools: Bash(*)
argument-hint: "[all|code|test|security|docs|build]"
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.agents/skills/quality-gates
---

Run quality gates for the current project. Scope: `$ARGUMENTS` (default: all).

## Native Gate Preference

Use repository-native verification first when available. This keeps local runs
aligned with CI contracts.

```bash
if [ -f package.json ]; then
  if npm run | rg -q " verify$"; then
    npm run verify
    exit $?
  fi
fi
```

If no native verify command exists, continue with the fallback sequence below.

## Forge Space Repo-Specific Gates

See [references/forge-space-gates.md](references/forge-space-gates.md) for repo-specific commands:

- **core** (@forgespace/core) — lint:check + format:check + test:coverage + test:validation + tenant-decoupling
- **siza-gen** (@forgespace/siza-gen) — TS build + 465 tests + Python sidecar
- **mcp-gateway** — 1567 tests + Python components
- **ui-mcp** (@forgespace/ui-mcp) — ESM build + 638+ tests + 0 lint warnings + registry check
- **branding-mcp** — TS build + tests
- **siza** — Next.js build + tests + lint

## Generic Gate Sequence (non-Forge repos)

See [references/generic-gates.md](references/generic-gates.md) for scripts and detailed completion criteria:

1. **Code quality** — eslint (0 warnings), tsc (0 errors), prettier (clean)
2. **Tests** — npm test or pytest (all pass, no skipped)
3. **CI Contract Snapshot** — merge state, required status checks (CLEAN or UNSTABLE with required green)
4. **Security** — secrets scan, npm audit (no high-severity)
5. **Documentation** — CHANGELOG.md and README.md updated
6. **Build** — npm run build (exit code 0)

## Report Format

See [references/output-patterns.md](references/output-patterns.md) for detailed report templates and examples.

**Key:** Lead with `Overall: [READY / NOT READY]`, then list each gate's result and blockers.

Example:
```
Quality Gates Report
════════════════════
Overall:  READY

Gates:
  Code:     PASS — eslint (0 warn), tsc (0 err), prettier (clean)
  Tests:    PASS — 287 passed
  Coverage: PASS — 84% (threshold: 80%)
  Security: PASS — no secrets, no high-severity audits
  Docs:     PASS — CHANGELOG.md updated
  Build:    PASS — npm run build (0 err)
```

## MCP Fallback Policy

If GitHub MCP is unavailable (transport/auth failure), explicitly fall back to
`gh` CLI for checks/workflow/ruleset evidence:

- `gh pr checks <PR#> --required`
- `gh run list --limit 20`
- `gh api repos/<owner>/<repo>/rulesets`

## Outputs / Evidence

- Return the checks run, evidence captured, blockers found, and the next required action.

## Failure / Stop Conditions

- Stop if required credentials, environment access, or prerequisite context are missing.
- Stop if the workflow would report unverified work as complete.
- Do not bypass required gates or safeguards unless the user explicitly asks for it.

## Memory Hooks

- Read memory when product, repo, or workflow history affects correctness.
- Write memory only if this work establishes a durable policy or convention.
