# Generic Gate Sequence (non-Forge repos)

## 1. Code quality

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

**Done when:** eslint warnings = 0, tsc errors = 0, prettier formatting clean, ruff checks pass.

## 2. Tests

```bash
if [ -f package.json ]; then
  npm test 2>&1 | tail -10
fi
if [ -f pyproject.toml ]; then
  pytest --tb=short 2>&1 | tail -10
fi
```

**Done when:** all test suites pass with no skipped tests.

## 2.5 CI Contract Snapshot (recommended before merge)

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

**Done when:** mergeStateStatus shows CLEAN or UNSTABLE (with required checks passing).

## 3. Security

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

**Done when:** no secrets found, no high-severity audit vulnerabilities, .env files not staged.

## 4. Documentation

- Verify CHANGELOG.md is updated (if code changes)
- Verify README.md reflects current state

**Done when:** CHANGELOG.md has entry for current changes, README.md is current.

## 5. Build

```bash
if [ -f package.json ]; then npm run build 2>&1 | tail -5; fi
```

**Done when:** build completes successfully with exit code 0.
