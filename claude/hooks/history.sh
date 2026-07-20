#!/usr/bin/env bash
# history.sh — non-Markovian iteration history store.
#
# THE #1 LEVER. Stanford's Meta-Harness result: non-Markovian full-history
# search (reading WHY things failed, not just that they failed) beats
# best-of-N sampling AND model hopping. This store is what makes the proposer
# non-Markovian — every proposal, its eval result, and its trace is preserved
# so the next proposer run reads the full history before writing anything.
#
# This is the "optimize" half's fuel. Without it, the proposer is just guessing.
# With it, the proposer can see "I tried X, it regressed on latency because Y"
# and avoid repeating the same dead end.
#
# Zero-dep local. Append-only JSONL keyed by target file. NEVER auto-deletes —
# history is the whole point (the meta-harness showed pruning history to recent-
# only drops performance to best-of-N levels).
#
# Usage:
#   hooks/history.sh add <target> <proposal-id> <status> <metric> <value> [note]
#     record an iteration: target file, proposal id, status (proposed|gated|
#     deployed|regressed|rejected), metric name, value, optional note
#   hooks/history.sh show <target>          # print full history for a target
#   hooks/history.sh last <target>          # print only the most recent iteration
#   hooks/history.sh regressions <target>   # print iterations that regressed
#   hooks/history.sh summary                # per-target counts + last status
#   hooks/history.sh why <target>           # human-readable "why did X fail" digest
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME="$ROOT/.harness/runtime"
HISTORY="$RUNTIME/iteration-history.jsonl"
mkdir -p "$RUNTIME"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cmd="${1:-}"; shift || true
die() { echo "history: $*" >&2; exit 2; }

case "$cmd" in
  add)
    target="${1:-}"; pid="${2:-}"; status="${3:-}"; metric="${4:-}"; value="${5:-}"; note="${6:-}"
    [[ -n "$target" && -n "$pid" && -n "$status" ]] \
      || die "add requires <target> <proposal-id> <status> [metric] [value] [note]"
    printf '{"ts":"%s","target":"%s","proposal_id":"%s","status":"%s","metric":"%s","value":"%s","note":"%s"}\n' \
      "$ts" "$target" "$pid" "$status" "$metric" "$value" "$note" >> "$HISTORY"
    echo "recorded: $target $pid $status"
    ;;

  show)
    target="${1:-}"; [[ -n "$target" ]] || die "show requires <target>"
    [[ -f "$HISTORY" ]] || { echo "no history yet"; exit 0; }
    jq -r --arg t "$target" 'select(.target==$t)' "$HISTORY" 2>/dev/null || true
    ;;

  last)
    target="${1:-}"; [[ -n "$target" ]] || die "last requires <target>"
    [[ -f "$HISTORY" ]] || { echo "no history yet"; exit 0; }
    jq -s --arg t "$target" '[.[] | select(.target==$t)] | last' "$HISTORY" 2>/dev/null
    ;;

  regressions)
    target="${1:-}"
    [[ -f "$HISTORY" ]] || { echo "no history yet"; exit 0; }
    if [[ -n "$target" ]]; then
      jq -c --arg t "$target" 'select(.target==$t and .status=="regressed")' "$HISTORY" 2>/dev/null
    else
      jq -c 'select(.status=="regressed")' "$HISTORY" 2>/dev/null
    fi
    ;;

  summary)
    [[ -f "$HISTORY" ]] || { echo "no history yet"; exit 0; }
    jq -s -r 'group_by(.target)[] | "\(.[0].target): \(length) iterations, last=\(.[-1].status) (\(.[-1].metric // "?")=\(.[-1].value // "?"))"' "$HISTORY" 2>/dev/null
    ;;

  why)
    target="${1:-}"; [[ -n "$target" ]] || die "why requires <target>"
    [[ -f "$HISTORY" ]] || { echo "no history yet"; exit 0; }
    echo "## Why-did-it-fail digest: $target"
    echo
    # Show regressions + rejections with their notes — the "why".
    jq -r --arg t "$target" 'select(.target==$t and (.status=="regressed" or .status=="rejected")) | "- [\(.ts)] \(.status): \(.metric // "?")=\(.value // "?") — \(.note // "no note")"' "$HISTORY" 2>/dev/null
    echo
    echo "## Successful iterations (to preserve)"
    jq -r --arg t "$target" 'select(.target==$t and .status=="deployed") | "- [\(.ts)] \(.metric // "?")=\(.value // "?") — \(.note // "no note")"' "$HISTORY" 2>/dev/null
    ;;

  *) die "unknown command: $cmd (use add|show|last|regressions|summary|why)" ;;
esac
exit 0
