# Scan Commands

Use these commands to gather ranking signals.

## Workspace detection

```bash
python3 -c "
import json, os, subprocess, glob
root = subprocess.run(['git', 'rev-parse', '--show-toplevel'], capture_output=True, text=True).stdout.strip()
packages = []
pkg_json = os.path.join(root, 'package.json')
if os.path.exists(pkg_json):
    with open(pkg_json) as f:
        ws = json.load(f).get('workspaces', [])
    if isinstance(ws, dict):
        ws = ws.get('packages', [])
    for pattern in ws:
        for path in glob.glob(os.path.join(root, pattern)):
            if os.path.isdir(path):
                packages.append(path)
parent = os.path.dirname(root)
siblings = [os.path.join(parent, e) for e in os.listdir(parent) if os.path.isdir(os.path.join(parent, e, '.git'))]
mode = 'monorepo' if packages else 'multi-repo' if len(siblings) > 1 else 'single-repo'
print(json.dumps({'mode': mode, 'root': root, 'packages': packages, 'siblings': siblings}))
"
```

## Repo scan

```bash
git log --oneline -5
git branch --show-current
git status --short
REPO_SLUG=$(git remote get-url origin 2>/dev/null | sed 's/.*github.com[:/]\(.*\)\.git/\1/' | sed 's/.*github.com[:/]\(.*\)/\1/')
[ -n "$REPO_SLUG" ] && gh pr list --repo "$REPO_SLUG" --state open --limit 10
[ -n "$REPO_SLUG" ] && gh issue list --repo "$REPO_SLUG" --state open --limit 10
ls .agents/plans/ .claude/plans/ 2>/dev/null
[ -n "$REPO_SLUG" ] && gh api repos/"$REPO_SLUG"/rulesets 2>/dev/null
```

## Required checks

```bash
DEFAULT_BRANCH=$(gh repo view "$REPO_SLUG" --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null)
[ -n "$DEFAULT_BRANCH" ] && gh api repos/"$REPO_SLUG"/rulesets \
  --jq '.[] | select(.enforcement=="active") | .rules[]? | select(.type=="required_status_checks") | .parameters.required_status_checks[].context' \
  2>/dev/null

gh pr list --repo "$REPO_SLUG" --state open --limit 20 --json number,title,mergeStateStatus,statusCheckRollup
```

## Quick health check (for forge-space Node.js repos)

Run from the repo root to gather all quality signals in one pass:

```bash
npm run build 2>&1 | tail -2            # tsc compilation
npm test 2>&1 | tail -5                 # test count + pass/fail
npm run validate 2>&1 | tail -5         # lint + format + validation
npm audit --audit-level=moderate 2>&1 | tail -3   # security
npm run knip 2>&1 | grep -v "Configuration hints" | grep -v "Remove from\|Refine" | head -10
npm run lint:check 2>&1 | grep -c "error\b"        # error count
npm run check:cycles 2>&1 | tail -3    # circular deps
```

## Documentation & test gap scan (forge-space/core)

```bash
# Pattern directories missing READMEs
for d in patterns/*/; do
  name=$(basename "$d")
  [ ! -f "${d}README.md" ] && echo "MISSING README: $name"
done

# TypeScript sources with zero test files
for d in patterns/*/; do
  name=$(basename "$d")
  tests=$(find "$d" -name "*.test.ts" -o -name "*.test.js" 2>/dev/null | wc -l | tr -d ' ')
  tsfiles=$(find "$d" -name "*.ts" ! -name "*.test.ts" ! -name "*.d.ts" 2>/dev/null | wc -l | tr -d ' ')
  [ "$tsfiles" -gt "0" ] && [ "$tests" -eq "0" ] && echo "UNTESTED: $name ($tsfiles TS)"
done
```

## Stale-base detection

PRs targeting a base branch that has been merged into the default branch represent
`UNKNOWN` or stale merge state. Detect them with:

```bash
# For each open PR, check if its base branch is already merged into default
DEFAULT_BRANCH=$(gh repo view "$REPO_SLUG" --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null)
gh pr list --repo "$REPO_SLUG" --state open --json number,title,baseRefName --limit 20 | python3 -c "
import json, sys, subprocess
prs = json.load(sys.stdin)
default = '${DEFAULT_BRANCH}'
for pr in prs:
    base = pr['baseRefName']
    if base == default:
        continue
    # Check if the base branch is merged into default
    result = subprocess.run(
        ['gh', 'api', f'repos/${REPO_SLUG}/compare/{default}...{base}'],
        capture_output=True, text=True
    )
    if result.returncode == 0:
        data = json.loads(result.stdout)
        status = data.get('status', '')  # 'behind', 'ahead', 'identical', 'diverged'
        ahead = data.get('ahead_by', 0)
        behind = data.get('behind_by', 0)
        if behind > 0 and ahead == 0:
            print(f'PR #{pr[\"number\"]} ({pr[\"title\"]}) targets stale base: {base} (merged into {default})')
        elif status == 'identical':
            print(f'PR #{pr[\"number\"]} ({pr[\"title\"]}) targets identical base: {base}')
"
```

### Stale-base remediation

When a PR targets a merged base branch:
1. Identify which commits on the head branch are not yet on the default branch
2. Rebase those commits onto the default branch: `git rebase --onto <default> <old-base> <head>`
3. Force-push: `git push --force-with-lease`
4. If the PR is already closed/merged into the old base, create a new PR targeting default

**Common pitfall:** When the old base was squash-merged, the cherry-pick patch-id may match
commits already on default, causing `git rebase` to silently skip them. Always verify with
`git log origin/<default>..<head>` after rebase and use `git cherry-pick <sha>` if needed.
