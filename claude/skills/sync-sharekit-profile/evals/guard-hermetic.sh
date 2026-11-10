#!/usr/bin/env bash
# Hermetic tests for the Phase 3b.1 repo-edit revert guard in ../SKILL.md.
# Builds throwaway git repos under a temp dir; touches nothing else.
# Run: bash evals/guard-hermetic.sh   (exit 0 = all pass)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# Extract the guard block (the bash fence that greps for sync commits) into guard().
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
bash -n "$TMP/guard.sh" || { echo "FAIL guard block does not parse"; exit 1; }
. "$TMP/guard.sh"

pass=0; fail=0
check() { if eval "$2"; then echo "PASS $1"; pass=$((pass+1)); else echo "FAIL $1"; fail=$((fail+1)); fi; }
R="$TMP/repo"; PROFILE_REPO="$R"
g() { git -C "$R" -c user.email=t@example.com -c user.name=t "$@"; }
fresh() {
  rm -rf "$R"; mkdir -p "$R/claude/skills/x"; git -C "$R" init -q -b main
  printf 'a\nb\nc\n' > "$R/claude/f.md"; printf 'g1\n' > "$R/claude/g.md"
  printf 'p\nq\n' > "$R/claude/skills/x/café.md"; printf 'keep\n' > "$R/claude/del-ok.md"
  printf 'r\n' > "$R/claude/del-edited.md"
  g add -A; g commit -qm "chore(profile): sync base (#1)"
}

# Stale base: repo fix, then a sync that skips f, then live edits the same region on top of the fix.
fresh
printf 'a\nB-fix\nc\n' > "$R/claude/f.md"; g commit -qam "fix(hooks): repo-side fix"
printf 'g2\n' > "$R/claude/g.md"; g commit -qam "chore(profile): sync second (#3)"
printf 'a\nB-fix plus live edit\nc\n' > "$R/claude/f.md"
out="$(guard 2>&1)"
check "stale base: live edit published" 'grep -q "plus live edit" "$R/claude/f.md"'
check "stale base: no warning" '[ -z "$out" ]'

# Repo-owned file (added after the last sync) clobbered by the new copy: restored.
fresh
printf 'owned\n' > "$R/claude/owned.sh"; g add -A; g commit -qm "feat(hooks): repo-owned file"
printf 'live clobber\n' > "$R/claude/owned.sh"
out="$(guard 2>&1)"
check "no base: repo version kept" 'git -C "$R" diff --quiet HEAD -- claude/owned.sh'
check "no base: warns" '[[ "$out" == *"kept repo version of claude/owned.sh"* ]]'

# Non-ASCII path edited in the repo, new copy lacks the edit: restored, readable path in warning.
fresh
printf 'p\nq-fix\n' > "$R/claude/skills/x/café.md"; g commit -qam "fix: repo edit"
printf 'p\nq\n' > "$R/claude/skills/x/café.md"
out="$(guard 2>&1)"
check "non-ASCII: repo version kept" 'grep -q "q-fix" "$R/claude/skills/x/café.md"'
check "non-ASCII: warns with readable path" '[[ "$out" == *"café.md"* ]]'

# Deletions: a repo-edited file comes back; an unedited one stays deleted (intended unpublish).
fresh
printf 'r-fix\n' > "$R/claude/del-edited.md"; g commit -qam "fix: repo edit"
rm "$R/claude/del-edited.md" "$R/claude/del-ok.md"
out="$(guard 2>&1)"
check "deleted+edited: restored" '[ -f "$R/claude/del-edited.md" ]'
check "deleted unedited: stays deleted" '[ ! -f "$R/claude/del-ok.md" ]'

# Repo edit already carried by the new copy: published silently.
fresh
printf 'a\nb-fix\nc\n' > "$R/claude/f.md"; g commit -qam "fix: repo edit"
printf 'a\nb-fix\nc\nlive-only\n' > "$R/claude/f.md"
out="$(guard 2>&1)"
check "edit carried: published" 'grep -q live-only "$R/claude/f.md" && grep -q b-fix "$R/claude/f.md"'
check "edit carried: silent" '[ -z "$out" ]'

# Override publishes over repo edits, with a warning.
fresh
printf 'a\nb-fix\nc\n' > "$R/claude/f.md"; g commit -qam "fix: repo edit"
printf 'a\nb\nc\n' > "$R/claude/f.md"
out="$(SHAREKIT_ALLOW_REVERT=1 guard 2>&1)"
check "override: new copy published" '! grep -q b-fix "$R/claude/f.md"'
check "override: warns" '[[ "$out" == *"SHAREKIT_ALLOW_REVERT=1"* ]]'

# No sync history at all: BLOCKED, non-zero.
rm -rf "$R"; mkdir -p "$R/claude"; git -C "$R" init -q -b main; printf 'x\n' > "$R/claude/f.md"
g add -A; g commit -qm "init"; printf 'y\n' > "$R/claude/f.md"
out="$(guard 2>&1)"; rc=$?
check "no sync commit: BLOCKED" '[ "$rc" -ne 0 ] && [[ "$out" == *BLOCKED* ]]'

# Bad repo path: BLOCKED, non-zero.
PROFILE_REPO="$TMP/does-not-exist"; out="$(guard 2>&1)"; rc=$?; PROFILE_REPO="$R"
check "bad path: BLOCKED" '[ "$rc" -ne 0 ] && [[ "$out" == *BLOCKED* ]]'

echo "== $pass passed, $fail failed"
[ "$fail" -eq 0 ]
