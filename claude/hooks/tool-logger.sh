#!/usr/bin/env bash
# shellcheck source=py-resolve.sh
. "$(dirname "${BASH_SOURCE[0]}")/py-resolve.sh" 2>/dev/null || PY=""
# tool-logger.sh: PostToolUse hook, async. One logger for three logs (replaces
# trajectory-log.sh, skill-outcome-logger.sh, rtk-miss-detector.sh):
#   every tool call  -> ~/.claude/.harness/runtime/trajectory.jsonl (read by skill-prune.sh)
#   Skill calls      -> harness-evals/metrics/skill_invocations.jsonl (skill_outcomes.py)
#   Bash, >=5KB out, not rtk-wrapped -> ~/.claude/rtk-misses.log
# Pure observation: never blocks, never prints, always exit 0. Schemas unchanged.
set -uo pipefail
[ -n "$PY" ] || exit 0
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$PY" -c '
import json, os, re, sys, time
root = sys.argv[1]
try:
    d = json.loads(sys.stdin.read() or "{}")
except Exception:
    sys.exit(0)
ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
tool = d.get("tool_name") or ""
ti = d.get("tool_input")
tr = d.get("tool_response", d.get("tool_result"))
dump = lambda v: json.dumps(v, ensure_ascii=False, separators=(",", ":")) if v not in (None, "") else "null"
def append(path, rec):
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "a") as f:
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")
    except Exception:
        pass

ti_s, tr_s = dump(ti), dump(tr)
outcome = "success"
if re.search(r"\"is_error\":true|\"error\":|\"stderr\":\"[^\"]*error", tr_s, re.I):
    outcome = "error"
if re.search(r"BLOCKED|exit code 2", tr_s, re.I):
    outcome = "blocked"
append(os.path.join(root, ".harness/runtime/trajectory.jsonl"),
       {"ts": ts, "event": "tool-call", "tool": tool, "outcome": outcome,
        "input": ti_s[:2048], "response": tr_s[:2048]})

ti = ti if isinstance(ti, dict) else {}
if tool == "Skill" and ti.get("skill"):
    append(os.path.join(os.environ.get("DEV_ROOT") or os.path.expanduser("~/dev"), "harness-evals/metrics/skill_invocations.jsonl"),
           {"ts": ts, "skill": ti["skill"], "args": (ti.get("args") or "")[:200],
            "session_id": d.get("session_id", ""), "cwd": d.get("cwd", "")})

cmd = ti.get("command") or ""
if tool == "Bash" and cmd and not re.match(r"rtk |.* \| rtk |.*&& rtk ", cmd) \
        and cmd.split()[0] not in {"true","false",":","pwd","exit","cd","export","unset","alias","unalias",
            "history","hash","builtin","command","type","which","jobs","fg","bg","kill","echo","printf"}:
    r = tr if isinstance(tr, dict) else {}
    out = r.get("stdout") or r.get("output") or ""
    if len(out) >= 5120:
        ec = r.get("exit_code", r.get("exitCode", 0))
        append(os.path.expanduser("~/.claude/rtk-misses.log"),
               {"ts": ts, "cmd": cmd, "bytes": len(out), "exit_code": ec if isinstance(ec, int) else 0})
' "$ROOT" 2>/dev/null
exit 0
