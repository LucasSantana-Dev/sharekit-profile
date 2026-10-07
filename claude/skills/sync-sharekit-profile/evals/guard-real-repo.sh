#!/usr/bin/env bash
# Regression test for the Phase 3b.1 revert guard against real sharekit-profile history:
# PR #201 fixed hooks/tool-logger.sh in the repo, and sync #223 silently reverted it.
# Uses a detached throwaway worktree of the profile clone; never touches its checkout.
# Run: SHAREKIT_PROFILE_REPO=<clone> bash evals/guard-real-repo.sh   (exit 0 = pass, 0 also when skipped)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLONE="${SHAREKIT_PROFILE_REPO:-}"
[ -n "$CLONE" ] && [ -e "$CLONE/.git" ] || { echo "SKIP: set SHAREKIT_PROFILE_REPO to a sharekit-profile clone"; exit 0; }

# Immutable public history this test replays (verify with git log if it ever skips):
PRE_223=a704738   # main just before sync #223: tool-logger.sh carries the #201 fix
OLD_LIVE=f7a7751  # latest sync before that (#184): tool-logger.sh as live had it, without #201
POST_223=488f1ed  # sync #223 itself: last commit on computer-use-guard.sh
for c in "$PRE_223" "$OLD_LIVE" "$POST_223"; do
  git -C "$CLONE" cat-file -e "$c^{commit}" 2>/dev/null || { echo "SKIP: commit $c not in clone (shallow?)"; exit 0; }
done

TMP="$(mktemp -d)"
WT="${SHAREKIT_WT_ROOT:-${DEV_ROOT:-$HOME/dev}/.worktrees}/sharekit-guard-eval-$$"
cleanup() { git -C "$CLONE" worktree remove --force "$WT" 2>/dev/null; rm -rf "$TMP"; }
trap cleanup EXIT

python3 - "$HERE/../SKILL.md" > "$TMP/guard.sh" <<'PY'
import sys
lines = open(sys.argv[1]).read().splitlines()
blocks, cur = [], None
for l in lines:
    if cur is None and l == "```bash": cur = []
    elif cur is not None and l == "```": blocks.append(cur); cur = None
    elif cur is not None: cur.append(l)
g = [b for b in blocks if any("--grep='^chore(profile): sync'" in x for x in b)]
if len(g) != 1: sys.exit(f"expected 1 guard block, found {len(g)}")
print("guard() {\n" + "\n".join(g[0]) + "\n}")
PY
. "$TMP/guard.sh"
PROFILE_REPO="$WT"

pass=0; fail=0
check() { if eval "$2"; then echo "PASS $1"; pass=$((pass+1)); else echo "FAIL $1"; fail=$((fail+1)); fi; }
at() { git -C "$CLONE" worktree remove --force "$WT" 2>/dev/null; mkdir -p "$(dirname "$WT")"; git -C "$CLONE" worktree add -q --detach "$WT" "$1"; }
F=claude/hooks/tool-logger.sh

# The #223 regression: live copy without #201 over a repo that has it -> repo fix kept.
at "$PRE_223"
git -C "$CLONE" show "$OLD_LIVE:$F" > "$WT/$F"
out="$(guard 2>&1)"
check "old live: repo version kept" 'git -C "$WT" diff --quiet HEAD -- "$F"'
check "old live: warning names file" '[[ "$out" == *"kept repo version of $F"* ]]'

# Live already ported #201 and changed more -> published, fix intact.
at "$PRE_223"
printf '\n# newer live-only change\n' >> "$WT/$F"
out="$(guard 2>&1)"
check "ported live: new copy published" 'grep -q "newer live-only change" "$WT/$F"'
check "ported live: keeps #201 py-resolve" 'grep -q "py-resolve.sh" "$WT/$F"'
check "ported live: no kept-repo warning" '[[ "$out" != *"kept repo version"* ]]'

# Override publishes the old live copy anyway.
at "$PRE_223"
git -C "$CLONE" show "$OLD_LIVE:$F" > "$WT/$F"
out="$(SHAREKIT_ALLOW_REVERT=1 guard 2>&1)"
check "override: old copy published" '! git -C "$WT" diff --quiet HEAD -- "$F"'
check "override: warns" '[[ "$out" == *"SHAREKIT_ALLOW_REVERT=1"* ]]'

# File whose last commit is the sync itself: no repo-side edits, new copy wins.
at "$POST_223"
G=claude/hooks/computer-use-guard.sh
printf '\n# local change\n' >> "$WT/$G"
out="$(guard 2>&1)"
check "unedited since sync: new copy published" 'grep -q "local change" "$WT/$G"'

echo "== $pass passed, $fail failed"
[ "$fail" -eq 0 ]
