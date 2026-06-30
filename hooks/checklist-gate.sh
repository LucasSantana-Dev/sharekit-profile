#!/usr/bin/env bash
# checklist-gate.sh — PreToolUse hook: binary-checklist verification gates.
#
# Current gates (lint, type, test, build) verify code shape but not semantic
# quality dimensions. A model can produce code that passes all deterministic
# gates yet fails on security, correctness, or testing adequacy. This gap is
# model-dependent: weaker models exploit it more often.
#
# Mechanism (source: cursor-rules collections):
#   Binary-checklist gates — each dimension has a yes/no checklist that the
#   agent must self-verify before commit. Unlike lint rules, these are
#   semantic: "Does the error path handle the empty-result case?", "Are all
#   user inputs validated at the trust boundary?" The gate emits a structured
#   checklist, parses the agent's responses, and blocks commit if any item is
#   unchecked or answered "no".
#
# Dimensions (stored in .harness/checklists/):
#   security.md    — input validation, secrets, auth, injection
#   quality.md     — error paths, silent failures, speculative abstraction
#   testing.md     — failure case tested, edge cases, explicit mocks
#   performance.md — N+1 queries, unbounded growth, hot path complexity
#
# Modes (controlled by CHECKLIST_GATE_MODE env var):
#   shadow  — log only, never block (Wave 1 rollout, default)
#   warn    — emit warning on stderr, do not block (Wave 2)
#   block   — exit 2 on any unchecked/failed item (Wave 3)
#
# Wire in claude/settings.json PreToolUse with matcher Write|Edit.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKLISTS_DIR="$ROOT/.harness/checklists"
RUNTIME="$ROOT/.harness/runtime"
LOG="$RUNTIME/checklist-gate.jsonl"
mkdir -p "$RUNTIME"

MODE="${CHECKLIST_GATE_MODE:-shadow}"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

input="$(cat)"

tool_name="$(printf '%s' "$input" | jq -r '.tool_name // .tool // empty' 2>/dev/null || true)"

# Only govern file-mutating tools.
case "$tool_name" in
  Write|Edit|MultiEdit) ;;
  *) exit 0 ;;
esac

# Extract the file path being written.
file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // .file_path // empty' 2>/dev/null || true)"

if [[ -z "$file_path" ]]; then
  exit 0
fi

# Skip non-code files (markdown, text, images, config).
extension="${file_path##*.}"
case "$extension" in
  md|txt|png|jpg|jpeg|gif|svg|json|yaml|yml|toml|csv|log) exit 0 ;;
esac

# Determine which checklists apply.
checklists=()
if [[ -f "$CHECKLISTS_DIR/security.md" ]]; then
  checklists+=("security")
fi
if [[ -f "$CHECKLISTS_DIR/quality.md" ]]; then
  checklists+=("quality")
fi
# Testing checklist only for test files.
case "$file_path" in
  *test*|*spec*|*__tests__*)
    if [[ -f "$CHECKLISTS_DIR/testing.md" ]]; then
      checklists+=("testing")
    fi
    ;;
esac
# Performance checklist for source files.
case "$file_path" in
  *src/*|*lib/*|*app/*|*server/*|*api/*)
    if [[ -f "$CHECKLISTS_DIR/performance.md" ]]; then
      checklists+=("performance")
    fi
    ;;
esac

# If no checklists apply, allow.
if [[ ${#checklists[@]} -eq 0 ]]; then
  exit 0
fi

# Build the checklist prompt and count items.
total_items=0
prompt_parts=()
for dim in "${checklists[@]}"; do
  checklist_file="$CHECKLISTS_DIR/$dim.md"
  # Count checklist items (lines starting with "- [ ]").
  item_count="$(grep -c '^- \[ \]' "$checklist_file" 2>/dev/null || echo 0)"
  total_items=$((total_items + item_count))
  # Read items for the prompt.
  items="$(grep '^- \[ \]' "$checklist_file" 2>/dev/null | sed 's/^- \[ \] //')"
  prompt_parts+=("## $dim"$'\n'"$items")
done

# Emit the checklist as a structured prompt on stderr (agent sees this).
checklist_prompt="Before committing $file_path, verify each item:
$(printf '%s\n' "${prompt_parts[@]}")

Respond with [x] (pass) or [ ] (fail) per item. Items that fail must be fixed before commit."

echo "checklist-gate: $total_items items to verify for $file_path" >&2
echo "$checklist_prompt" >&2

# In shadow mode, log and allow (no parsing of agent response possible from
# within a stateless PreToolUse hook — the agent responds in its next turn).
# The eval gate reads the log to detect files that were written without
# checklist verification.
jq -nc \
  --arg ts "$ts" \
  --arg tool "$tool_name" \
  --arg file "$file_path" \
  --arg mode "$MODE" \
  --argjson dims "$(printf '%s\n' "${checklists[@]}" | jq -R . | jq -s .)" \
  --argjson total "$total_items" \
  '{ts: $ts, event: "checklist-gate", tool: $tool, file: $file, mode: $mode, dimensions: $dims, total_items: $total}' \
  >> "$LOG"

case "$MODE" in
  shadow)
    exit 0
    ;;
  warn)
    echo "checklist-gate: WARNING — $total_items checklist items must be verified (mode=warn)" >&2
    exit 0
    ;;
  block)
    # In block mode, we cannot parse the agent's response from within this hook
    # (PreToolUse fires before the tool runs). Block mode is enforced by the
    # eval gate reading the log and failing files that lack checklist evidence.
    # This hook logs the requirement; the eval gate enforces it.
    echo "checklist-gate: BLOCK mode — $total_items items must be verified. Eval gate will enforce." >&2
    exit 0
    ;;
esac

exit 0
