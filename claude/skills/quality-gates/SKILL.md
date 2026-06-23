---
name: quality-gates
description: |
  Run the repository-native verification gates (lint, type-check, tests, coverage, build, security, docs).
  Consults repo-native verify command first; falls back to Forge Space repo-specific or generic gate sequences.
  Use when (1) before commit to verify no regressions, (2) before PR merge to confirm CI alignment, 
  (3) before release to ensure all gates pass, (4) to inspect CI state snapshot + required status checks.
disable-model-invocation: true
context: fork
allowed-tools: Bash(*)
argument-hint: "[all|code|test|security|docs|build]"
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.agents/skills/quality-gates
triggers:
  - quality gates
  - verify all gates
  - before commit
  - before merge
  - run all tests
  - check security
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

When inside a Forge Space repo, use these exact commands:

### core (@forgespace/core)

```bash
npm run build                    # tsc compilation
npm run lint:check               # ESLint (7 warnings acceptable: magic-numbers in scripts)
npm run format:check             # Prettier
npm run test:coverage            # Jest with 80% coverage threshold
npm run test:validation          # Plugin, feature toggle, shared constants
npm run check:tenant-decoupling  # Tenant-agnostic guardrails
# Full validation shortcut:
npm run validate                 # lint:check + format:check + test:validation + tenant-decoupling
```

### siza-gen (@forgespace/siza-gen)

```bash
npm run build && npm test        # TS build + 465 tests
python -m pytest                 # Python sidecar tests
```

### mcp-gateway

```bash
npm run build && npm test        # 1567 tests, 91%+ coverage
python -m pytest                 # Python components
```

### ui-mcp (@forgespace/ui-mcp)

```bash
NODE_OPTIONS=--experimental-vm-modules npm run build  # tsup ESM bundle
NODE_OPTIONS=--experimental-vm-modules npm test       # 55+ suites, 638+ tests, 81%+ coverage
npm run lint                                          # ESLint — must be 0 warnings
npx tsc --noEmit                                      # strictNullChecks + noUncheckedIndexedAccess
npm run registry:check                                # server.json ↔ package.json alignment
npm run validate:all                                  # lint + format + tsc + test + build (full)
```

Key gotchas:

- `NODE_OPTIONS=--experimental-vm-modules` required for Jest (ESM modules)
- Coverage threshold: branches 55%, functions 55%, lines 60%
- Bump BOTH `package.json` AND `server.json` when releasing
- Zero lint warnings is the target (run `npm run lint` not just `npm run lint:check`)

### branding-mcp

```bash
npm run build && npm test        # Standard TS pipeline
```

### siza

```bash
npm run build && npm test        # Next.js build
npm run lint                     # Next.js ESLint
```

## Generic Gate Sequence (non-Forge repos)

### 1. Code quality

```bash
if [ -f package.json ]; then
  npx eslint . --max-warnings 0 2>&1 | tail -5
  npx tsc --noEmit 2>&1 | tail -5
  npx prettier --check . 2>&1 | tail -3
fi
if [ -f pyproject.toml ] || [ -f setup.py ]; then
  ruff check . 2>&1 | tail -5
  ruff format --check . 2>&1 | tail -3
fi
```

### 2. Tests

```bash
if [ -f package.json ]; then
  npm test 2>&1 | tail -10
fi
if [ -f pyproject.toml ]; then
  pytest --tb=short 2>&1 | tail -10
fi
```

### 2.5 CI Contract Snapshot (recommended before merge)

```bash
REPO_SLUG=$(git remote get-url origin 2>/dev/null | sed 's#.*github.com[:/]\(.*\)\.git#\1#' | sed 's#.*github.com[:/]\(.*\)#\1#')
PR=$(gh pr view --json number --jq '.number' 2>/dev/null)
if [ -n "$PR" ]; then
  # Check merge state (CLEAN = ready, BLOCKED = fix needed, DIRTY = conflict, UNSTABLE = advisory noise only)
  gh pr view "$PR" --repo "$REPO_SLUG" --json mergeStateStatus,reviewDecision
  # Identify required vs advisory failing checks
  echo "=== Non-passing checks ==="
  gh pr checks "$PR" --repo "$REPO_SLUG" 2>/dev/null | grep -v "pass\|skipping"
  echo "=== Required status checks ==="
  gh api repos/"$REPO_SLUG"/rulesets 2>/dev/null | python3 -c "
import json,sys
for rs in json.load(sys.stdin):
    if rs.get('enforcement')=='active':
        for r in rs.get('rules',[]):
            if r.get('type')=='required_status_checks':
                ctx=[c['context'] for c in r.get('parameters',{}).get('required_status_checks',[])]
                if ctx: print('required:', ctx)
"
fi
```

**Merge state guide:** CLEAN = merge; BLOCKED = required check failed OR CHANGES_REQUESTED; DIRTY = rebase needed; UNSTABLE = advisory noise only (SonarCloud, Test Autogen Warn) — safe to merge if required checks green.

### 3. Security

```bash
# Forge Space specific
if [ -f scripts/security/scan-for-secrets.sh ]; then
  bash scripts/security/scan-for-secrets.sh
  bash scripts/security/validate-no-secrets.sh
  bash scripts/security/validate-placeholders.sh
fi
# Generic fallback
git diff --cached --name-only 2>/dev/null | grep -i "\.env" && echo "WARNING: .env file staged!"
if [ -f package.json ]; then npm audit --audit-level=high 2>&1 | tail -5; fi
```

### 4. Documentation

- Verify CHANGELOG.md is updated (if code changes)
- Verify README.md reflects current state

### 5. Build

```bash
if [ -f package.json ]; then npm run build 2>&1 | tail -5; fi
```

## Report format

```
Quality Gates Report
════════════════════
Code:     [PASS/FAIL] — lint, types, format
Tests:    [PASS/FAIL] — [N] passed, [N] failed
Coverage: [PASS/FAIL] — [N]% (threshold: 80%)
Security: [PASS/FAIL] — secrets, vulnerabilities
Docs:     [PASS/WARN] — changelog, readme
Build:    [PASS/FAIL] — compilation

Overall:  [READY / NOT READY]
```

If any gate fails, list the specific errors and suggest fixes.

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
