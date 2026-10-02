#!/usr/bin/env bash
# py-resolve.sh: sourced by hooks. Sets PY to a working Python interpreter, or "" if none.
# On Windows `python3` is often the Microsoft Store alias stub (prints "Python was not
# found", exits 49) while the real interpreter is `python`, so each candidate is verified
# by actually running it. Callers degrade silently when PY is empty:
#   . "$(dirname "${BASH_SOURCE[0]}")/py-resolve.sh" 2>/dev/null || PY=""
#   [ -n "${PY:-}" ] || exit 0
PY=""
for _py_cand in python3 python; do
  if command -v "$_py_cand" >/dev/null 2>&1 && "$_py_cand" -c '' >/dev/null 2>&1; then
    PY="$_py_cand"
    break
  fi
done
unset _py_cand
export PY
