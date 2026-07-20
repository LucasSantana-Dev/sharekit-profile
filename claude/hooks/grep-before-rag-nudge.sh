#!/usr/bin/env bash
# grep-before-rag-nudge.sh — PreToolUse. Enforces the graph/RAG-first discipline (CLAUDE.md
# graph-first rule + standards/graphify-discipline.md) deterministically instead of relying on the
# model to remember it: when a WIDE content sweep (grep -r / rg / ag over a broad path) runs and no
# retrieval tool was used recently, emit a one-line advisory. HIGH-PRECISION by design — only wide
# recursive content searches, only when RAG/graph wasn't just consulted. Advisory, never blocks (exit 0).
set -uo pipefail
HOOK_JSON=$(cat); [ -n "$HOOK_JSON" ] || exit 0   # robust to no-trailing-newline stdin
MARK="$HOME/.claude/.rag-recent"

read TOOL CMD < <(printf '%s' "$HOOK_JSON" | python3 -c "
import sys,json
try: d=json.load(sys.stdin)
except: print(' '); sys.exit()
t=d.get('tool_name','')
c=d.get('tool_input',{}).get('command','') if isinstance(d.get('tool_input'),dict) else ''
print(t, c.replace(chr(10),' ')[:400])
" 2>/dev/null)

[ "$TOOL" = "Bash" ] || exit 0

# wide recursive content search? (grep -r/-R, rg, ag — excluding narrow single-file greps)
case "$CMD" in
  *"grep -r"*|*"grep -R"*|*"grep -rn"*|*"grep -rl"*|*"rg "*|*"ag "*) : ;;
  *) exit 0 ;;
esac
# skip if it's clearly scoped to one file/dir already, or piped from another command (refinement)
case "$CMD" in
  *"| grep"*|*"git "*) exit 0 ;;   # pipeline refinement / git-grep are fine
esac

# RAG/graph consulted in the last 10 min? then stay quiet.
if [ -f "$MARK" ]; then
  now=$(date +%s); m=$(stat -f %m "$MARK" 2>/dev/null || stat -c %Y "$MARK" 2>/dev/null || echo 0)
  [ $(( now - m )) -lt 600 ] && exit 0
fi

# graph-first is sharper when a graph exists in the cwd
hint="rag_query / recall"
[ -f "graphify-out/graph.json" ] && hint="graphify query (graph.json present) or rag_query"
printf '{"systemMessage": "graph/RAG-first: wide content sweep without a recent retrieval query — %s may answer faster + cheaper (CLAUDE.md graph-first rule). Proceeding."}' "$hint"
exit 0
