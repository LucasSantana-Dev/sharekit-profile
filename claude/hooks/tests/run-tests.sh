#!/usr/bin/env bash
# Runs every test-*.sh in this dir, aggregates results, exits non-zero on any
# failure. Wire into CI / pre-push to guard the security-critical blocking hooks
# (block-secret-reads.sh, protect-files.sh) against silent regressions.
#
#   bash hooks/tests/run-tests.sh
#
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
rc=0
for t in "$DIR"/test-*.sh; do
  [ -f "$t" ] || continue
  echo "▶ $(basename "$t")"
  bash "$t" || rc=1
done
echo ""
if [ "$rc" -eq 0 ]; then echo "✓ ALL HOOK TESTS PASS"; else echo "✗ HOOK TESTS FAILED"; fi
exit "$rc"
