#!/usr/bin/env bash
# rag-usage-tracker.sh — PostToolUse. Touches a marker whenever a retrieval tool runs, so the
# grep-before-rag nudge knows RAG/graph was consulted recently and stays quiet. Companion to
# grep-before-rag-nudge.sh. Never blocks (exit 0).
set -uo pipefail
HOOK_JSON=$(cat); [ -n "$HOOK_JSON" ] || exit 0   # robust to no-trailing-newline stdin
MARK="$HOME/.claude/.rag-recent"

read TOOL CMD < <(printf '%s' "$HOOK_JSON" | python3 -c "
import sys,json
try: d=json.load(sys.stdin)
except: print(' '); sys.exit()
t=d.get('tool_name','')
c=d.get('tool_input',{}).get('command','') if isinstance(d.get('tool_input'),dict) else ''
print(t, c.replace(chr(10),' ')[:300])
" 2>/dev/null)

case "$TOOL" in
  *rag_query*|*search_knowledge*|*recall*|*query_graph*|*search_graph*|*search_code*) touch "$MARK" 2>/dev/null ;;
  Bash)
    case "$CMD" in
      *rag-index/query.py*|*"graphify query"*|*recall*) touch "$MARK" 2>/dev/null ;;
    esac ;;
esac
exit 0
