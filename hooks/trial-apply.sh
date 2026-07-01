#!/usr/bin/env bash
# trial-apply.sh — materialize a proposed edit into a trial copy of the target.
#
# The gate must validate a PROPOSED edit, not the live hook (close-the-loop).
# This script reads a proposal .md file, extracts the fenced `diff` block from
# its "## 6. Proposed edit" section, applies it to a COPY of the target hook at
# .harness/forge/trial/<proposal-id>/<hook-basename>, and emits the candidate
# path on stdout (so gate.sh can pass it to eval-run.sh --candidate).
#
# Contract:
#   - NEVER touches the live hook. Only the trial copy under forge/trial/.
#   - Idempotent per proposal-id: re-running overwrites the same trial dir.
#   - Backs up the pristine target copy alongside the candidate so the
#     deploy-watch revert semantics are preserved if the proposal is later
#     promoted and regresses.
#   - Rejects a malformed diff or a leftover "FILL IN" placeholder (exit 2).
#
# The diff must be a unified diff against the current file content shown in the
# proposal's section 5 (produce by `propose.sh`). Lines must be context (` `),
# removed (`-`), or added (`+`); hunk headers (`@@`) are supported.
#
# Usage:
#   hooks/trial-apply.sh <proposal-file.md>
#     emits the candidate path on stdout; exits 0 on success.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORGE="$ROOT/.harness/forge"
TRIAL="$FORGE/trial"
mkdir -p "$TRIAL"

die() { echo "trial-apply: $*" >&2; exit 2; }

proposal="${1:-}"
[[ -n "$proposal" ]] || die "usage: trial-apply.sh <proposal-file.md>"
[[ -f "$proposal" ]] || die "proposal file not found: $proposal"

# --- Extract proposal_id + target from the proposal frontmatter ----------------
pid="$(rg -m 1 '^proposal_id:' "$proposal" | sed -E 's/^proposal_id:[[:space:]]*//')"
[[ -n "$pid" ]] || die "proposal_id field missing in $proposal"

# The target is encoded in the "# Proposal: <target>" heading.
target="$(rg -m 1 '^# Proposal: ' "$proposal" | sed -E 's/^# Proposal:[[:space:]]*//')"
[[ -n "$target" ]] || die "Proposal heading (target) missing in $proposal"
[[ -f "$target" ]] || die "target file not found: $target (run from repo root)"

# --- Guard: refuse a leftover FILL IN in section 6 ---------------------------
# Section 7 (predicted impact) legitimately keeps its own FILL IN; only section
# 6's diff must be filled. Scope the check to section 6 only (python, quote-safe).
command -v python3 >/dev/null 2>&1 || { echo "trial-apply: python3 not found — skipping" >&2; exit 2; }

if python3 - "$proposal" <<'PY'
import sys, re
text = open(sys.argv[1]).read()
m = re.search(r'^## 6\..*?(?=^## 7\.)', text, re.S | re.M)
sys.exit(0 if (m and 'FILL IN' in m.group(0)) else 1)
PY
then
  die "section 6 still has a 'FILL IN' placeholder -- the proposing model has not written the edit. Fill the diff block first."
fi

# --- Extract the fenced diff block from section 6 -----------------------------
# Use python to extract the diff: awk breaks on single quotes / backticks inside
# the diff content (jq expressions, shell substitutions). Python handles
# arbitrary content safely and extracts exactly the fenced diff block in
# section 6 (between "## 6." and "## 7.").
diff_file="$(mktemp -t trial-diff.XXXXXX)"
trap 'rm -f "$diff_file"' EXIT

python3 - "$proposal" "$diff_file" <<'PY'
import sys, re
proposal, out = sys.argv[1], sys.argv[2]
text = open(proposal).read()
# Slice section 6 only (between "## 6." and "## 7.").
m = re.search(r'^## 6\..*?(?=^## 7\.)', text, re.S | re.M)
sec = m.group(0) if m else ''
# Find the first ```diff ... ``` fenced block.
m2 = re.search(r'```diff\n(.*?)```', sec, re.S)
if not m2:
    sys.exit(1)
lines = m2.group(1).splitlines()
# Keep only real diff lines: hunk headers (@@), context (leading space),
# removed (leading -), added (leading +), and no-newline markers.
kept = [l for l in lines if re.match(r'^(@@| |\-|\+|\\)', l)]
open(out, 'w').write('\n'.join(kept) + '\n')
PY
[[ -s "$diff_file" ]] || die "no diff found in section 6 of $proposal (expected a fenced diff block)"

# --- Set up the trial dir + pristine backup -----------------------------------
trial_dir="$TRIAL/$pid"
mkdir -p "$trial_dir"
basename_target="$(basename "$target")"
candidate="$trial_dir/$basename_target"
pristine="$trial_dir/${basename_target}.pristine.bak"

# Copy the current (live) target as both the candidate base and the pristine backup.
cp "$target" "$candidate"
cp "$target" "$pristine"

# --- Apply the diff to the candidate (trial copy only) ------------------------
# patch applies unified diffs against a single file. We feed the diff on stdin
# and name the target file explicitly, so no ---/+++ path headers are required
# in the diff (only @@ hunk headers + context/+/- lines). --fuzz=3 lets patch
# adjust line-number offsets when the @@ header doesn't exactly match (the
# proposer may have miscounted); --forward rejects already-applied patches.
# The candidate is a fresh copy of the current target, so context lines match
# the state the proposer saw in section 5.
if ! patch --quiet --forward --fuzz=3 "$candidate" < "$diff_file" 2>/dev/null; then
  die "diff did not apply cleanly to a copy of $target -- check the diff is against the current file content (section 5)"
fi

# --- Emit the candidate path on stdout ----------------------------------------
echo "$candidate"
exit 0
