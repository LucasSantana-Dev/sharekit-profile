#!/bin/bash
# Push to knowledge-brain after memory or graph change (phase5-routing.md)

set -e  # fail loud

# Default DEV_ROOT when unset (same rationale as mount-guard.sh):
# an unset env var is not an unmounted disk; the reachability test is the guard.
if [ -z "$DEV_ROOT" ]; then
  DEV_ROOT="${DEV_ROOT:-$HOME/dev}"
fi

BRAIN="${DEV_ROOT}/knowledge-brain"

# Mount guard (standards/knowledge-brain.md §1) — fail loud, never silent.
# Directory reachability is the real signal: `mount` lists mount points only
# (e.g. ${DEV_ROOT:-$HOME/dev}), never nested paths like $DEV_ROOT, so grepping
# it for $DEV_ROOT false-positives as "unmounted" (same fix as mount-guard.sh).
if [ ! -d "$BRAIN/.git" ]; then
  echo "BLOCKED: External HD not mounted — knowledge-brain unreachable. Skip push." >&2
  exit 1
fi

# Stage one pathspec at a time, and only the ones that exist.
#
# `git add memory/ graphs/` is all-or-nothing: if ANY pathspec is missing, git
# fails with "did not match any files" and stages NOTHING. With `2>/dev/null` on
# top, the error is invisible and the script goes on to report "nothing to push":
# uma captura real perdida em silencio, com cara de sucesso (medido 2026-09-16, a
# mesma linha copiada na antiga skill session-close). Never swallow git's stderr here.
staged_algo=0
for alvo in memory graphs; do
  [ -e "$BRAIN/$alvo" ] || continue
  git -C "$BRAIN" add "$alvo" || {
    echo "BLOCKED: git add falhou em $alvo, nada foi enviado." >&2
    exit 1
  }
  staged_algo=1
done

if [ "$staged_algo" -eq 0 ]; then
  echo "BLOCKED: nem memory/ nem graphs/ existem em $BRAIN, nada a enviar." >&2
  exit 1
fi

if git -C "$BRAIN" diff --cached --quiet; then
  echo "knowledge-brain: nothing to push"
else
  n=$(git -C "$BRAIN" diff --cached --name-only | wc -l | tr -d ' ')
  git -C "$BRAIN" commit -q -m "chore: knowledge-brain sync from session"
  git -C "$BRAIN" push -q
  echo "knowledge-brain pushed: $n arquivo(s), commit $(git -C "$BRAIN" rev-parse --short HEAD)"
fi
