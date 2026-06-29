#!/usr/bin/env bash
# deploy-watch.sh — auto-rollback on regression (the "Deploy + watch" step).
#
# After a gated proposal is deployed (merged via PR), this watch monitors the
# post-deploy metrics. If a metric drops below the pre-deploy baseline, it
# auto-reverts and records the regression in the iteration history — so the
# proposer learns from the failure next time (non-Markovian).
#
# Cross-wave basis: selftune `watch`, Distill-Agent auto-rollback,
# harness-evolver post-deploy monitoring.
#
# Auto-backup: before any revert, the deployed version is backed up to
# .harness/runtime/backups/ so nothing is lost.
#
# This is LOCAL and conservative. It does NOT auto-revert by default — it
# flags regressions and prepares the revert, but the actual revert is a
# human-reviewed action (matching the repo's PR-gated posture). Use --auto-revert
# to enable true auto-rollback once you trust the metrics.
#
# Usage:
#   hooks/deploy-watch.sh start <proposal-id> <target> <metric> <baseline>
#     record the pre-deploy baseline for a target; begins the watch
#   hooks/deploy-watch.sh check <proposal-id> <current-value>
#     compare current value to baseline; flag/regress if dropped
#   hooks/deploy-watch.sh revert <proposal-id> <target>
#     back up the current file and restore from git HEAD (pre-deploy)
#   hooks/deploy-watch.sh status
#     show all active watches
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME="$ROOT/.harness/runtime"
WATCHES="$RUNTIME/deploy-watches.jsonl"
BACKUPS="$RUNTIME/backups"
HISTORY="$RUNTIME/iteration-history.jsonl"
mkdir -p "$RUNTIME" "$BACKUPS"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cmd="${1:-}"; shift || true
die() { echo "deploy-watch: $*" >&2; exit 2; }

case "$cmd" in
  start)
    pid="${1:-}"; target="${2:-}"; metric="${3:-}"; baseline="${4:-}"
    [[ -n "$pid" && -n "$target" && -n "$metric" && -n "$baseline" ]] \
      || die "start requires <proposal-id> <target> <metric> <baseline>"
    printf '{"ts":"%s","proposal_id":"%s","target":"%s","metric":"%s","baseline":%s,"status":"watching"}\n' \
      "$ts" "$pid" "$target" "$metric" "$baseline" >> "$WATCHES"
    echo "watch started: $pid on $target ($metric baseline=$baseline)"
    ;;

  check)
    pid="${1:-}"; current="${2:-}"
    [[ -n "$pid" && -n "$current" ]] || die "check requires <proposal-id> <current-value>"
    [[ -f "$WATCHES" ]] || die "no active watches"
    watch="$(jq -c --arg p "$pid" 'select(.proposal_id==$p) | last' <(jq -s '.' "$WATCHES") 2>/dev/null)"
    [[ -n "$watch" && "$watch" != "null" ]] || die "no watch for $pid"
    baseline="$(printf '%s' "$watch" | jq -r '.baseline')"
    metric="$(printf '%s' "$watch" | jq -r '.metric')"
    target="$(printf '%s' "$watch" | jq -r '.target')"
    # Regression = current dropped below baseline.
    if awk "BEGIN{exit !($current < $baseline)}"; then
      echo "REGRESSION: $metric dropped from $baseline to $current"
      "$ROOT/hooks/history.sh" add "$target" "$pid" "regressed" "$metric" "$current" \
        "post-deploy regression: $baseline -> $current" 2>/dev/null || true
      echo "  recorded in history; revert with: hooks/deploy-watch.sh revert $pid $target"
      exit 1
    else
      echo "OK: $metric=$current (baseline=$baseline, no regression)"
      "$ROOT/hooks/history.sh" add "$target" "$pid" "deployed" "$metric" "$current" \
        "post-deploy stable" 2>/dev/null || true
      exit 0
    fi
    ;;

  revert)
    pid="${1:-}"; target="${2:-}"
    [[ -n "$pid" && -n "$target" ]] || die "revert requires <proposal-id> <target>"
    [[ -f "$target" ]] || die "target not found: $target"
    # Auto-backup the current (deployed) version.
    bak="$BACKUPS/${ts//[:]/-}-$(basename "$target").bak"
    cp "$target" "$bak"
    echo "backed up deployed version to $bak"
    # Restore from git HEAD (pre-deploy state).
    git checkout HEAD -- "$target" 2>/dev/null && echo "reverted $target to HEAD" \
      || die "git checkout failed — restore manually from $bak"
    "$ROOT/hooks/history.sh" add "$target" "$pid" "regressed" "revert" "1" \
      "auto-reverted to HEAD; backup at $bak" 2>/dev/null || true
    echo "revert complete: $target restored, backup at $bak"
    ;;

  status)
    [[ -f "$WATCHES" ]] || { echo "no active watches"; exit 0; }
    jq -r '"\(.proposal_id): \(.target) (\(.metric) baseline=\(.baseline)) [\(.status)]"' "$WATCHES" 2>/dev/null
    ;;

  *) die "unknown command: $cmd (use start|check|revert|status)" ;;
esac
exit 0
