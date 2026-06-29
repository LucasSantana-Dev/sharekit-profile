#!/usr/bin/env bash
#
# check-harness-drift.sh — Detect drift between the live Claude harness
# (~/.claude/) and its tracked source mirror (~/.claude-env/).
#
# The sharekit-profile keeps runtime files under ~/.claude/ and a tracked
# copy under ~/.claude-env/. This script compares the `agents/` and `hooks/`
# subtrees of the two trees using `diff -rq` and reports any files that were
# added, removed, or had their content changed in either location.
#
# Exit codes:
#   0 — no drift detected (or ~/.claude-env does not exist)
#   1 — drift detected between the two trees
#
# Usage: hooks/check-harness-drift.sh

set -u

LIVE_DIR="${HOME}/.claude"
ENV_DIR="${HOME}/.claude-env"

# If the tracked source mirror does not exist, there is nothing to compare
# against. Warn the operator and exit cleanly so CI/cron invocations do not
# fail purely because the mirror has not been cloned yet.
if [ ! -d "${ENV_DIR}" ]; then
    echo "warn: ${ENV_DIR} does not exist — nothing to diff, skipping drift check." >&2
    exit 0
fi

drift=0

for subtree in agents hooks; do
    live_path="${LIVE_DIR}/${subtree}"
    env_path="${ENV_DIR}/${subtree}"

    # If neither side has the subtree, there is nothing to compare.
    if [ ! -d "${live_path}" ] && [ ! -d "${env_path}" ]; then
        continue
    fi

    # If only one side has the subtree, the entire directory is drift.
    if [ ! -d "${live_path}" ]; then
        echo "drift: ${live_path} missing (only present in ${env_path})"
        drift=1
        continue
    fi
    if [ ! -d "${env_path}" ]; then
        echo "drift: ${env_path} missing (only present in ${live_path})"
        drift=1
        continue
    fi

    # `diff -rq` recurses, reports only differences (quiet), and compares
    # file contents rather than just metadata.
    if ! diff -rq "${live_path}" "${env_path}" >/tmp/harness-drift.$$ 2>&1; then
        echo "drift detected in ${subtree}/:"
        sed "s|^|  |" /tmp/harness-drift.$$
        drift=1
    fi
    rm -f /tmp/harness-drift.$$
done

if [ "${drift}" -eq 0 ]; then
    echo "ok: no harness drift between ${LIVE_DIR} and ${ENV_DIR}"
fi

exit "${drift}"
