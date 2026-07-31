#!/usr/bin/env bash
# scan-transcripts.sh — gitleaks over agent session transcripts.
#
# Transcripts accumulate every token the agent sees, including any secret that
# crossed a tool result. Point the repo's .gitleaks.toml rules at them;
# redact-before-retain. Exit 1 when findings exist (CI-gateable).
#
# Usage:
#   bash scripts/scan-transcripts.sh [target-dir]
#   default target: ${CLAUDE_PROJECTS_DIR:-~/.claude/projects}

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}}"

if ! command -v gitleaks >/dev/null 2>&1; then
  echo "scan-transcripts: gitleaks not installed (brew install gitleaks) - skip" >&2
  exit 0
fi

if [ ! -d "$TARGET" ]; then
  echo "scan-transcripts: target $TARGET does not exist - skip" >&2
  exit 0
fi

# --redact: findings print without the secret material. --exit-code 1 on leaks.
gitleaks dir "$TARGET" \
  --config "$ROOT/.gitleaks.toml" \
  --redact \
  --exit-code 1 \
  --no-banner
