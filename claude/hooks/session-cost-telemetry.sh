#!/usr/bin/env bash
# session-cost-telemetry.sh — SessionEnd. Captures THIS session's real token usage + estimated cost
# from the transcript and appends one row to ~/.claude/metrics/sessions.jsonl (the cost time-series
# harness-metrics.py rolls up into 7-day spend). You can't optimize cost you don't measure — this is
# the measurement. Silent, never blocks (exit 0). Per-model breakdown so down-tiering shows up as $.
set -uo pipefail
HOOK_JSON=$(cat); [ -n "$HOOK_JSON" ] || exit 0   # robust to no-trailing-newline stdin
OUT="$HOME/.claude/metrics/sessions.jsonl"
mkdir -p "$HOME/.claude/metrics"

printf '%s' "$HOOK_JSON" | python3 -c '
import sys, json, os, time
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
tp = d.get("transcript_path") or ""
sid = d.get("session_id") or ""
cwd = d.get("cwd") or ""
if not tp or not os.path.exists(tp):
    sys.exit(0)

# price per 1M tokens (USD): [input, output, cache_write, cache_read]. Update as pricing changes.
PRICES = {
    "opus":   [15.0, 75.0, 18.75, 1.50],
    "sonnet": [ 3.0, 15.0,  3.75, 0.30],
    "haiku":  [ 1.0,  5.0,  1.25, 0.10],
}
def tier(model):
    m = (model or "").lower()
    for k in PRICES:
        if k in m: return k
    return None

per_model = {}   # model -> [in, out, cwrite, cread]
for line in open(tp, errors="ignore"):
    try: r = json.loads(line)
    except Exception: continue
    msg = r.get("message")
    if not isinstance(msg, dict): continue
    u = msg.get("usage")
    if not isinstance(u, dict): continue
    model = msg.get("model") or "unknown"
    if model == "<synthetic>": continue
    a = per_model.setdefault(model, [0,0,0,0])
    a[0] += int(u.get("input_tokens",0) or 0)
    a[1] += int(u.get("output_tokens",0) or 0)
    a[2] += int(u.get("cache_creation_input_tokens",0) or 0)
    a[3] += int(u.get("cache_read_input_tokens",0) or 0)

if not per_model:
    sys.exit(0)

tot_in=tot_out=tot_cw=tot_cr=0
cost=0.0; by_model={}
for model,(i,o,cw,cr) in per_model.items():
    tot_in+=i; tot_out+=o; tot_cw+=cw; tot_cr+=cr
    t = tier(model)
    c = 0.0
    if t:
        p = PRICES[t]
        c = (i*p[0] + o*p[1] + cw*p[2] + cr*p[3]) / 1_000_000
    cost += c
    by_model[model] = {"in":i,"out":o,"cache_write":cw,"cache_read":cr,"est_cost_usd":round(c,4)}

row = {
    "ts": time.time(),
    "session_id": sid[:12],
    "cwd": cwd,
    "input_tokens": tot_in, "output_tokens": tot_out,
    "cache_write_tokens": tot_cw, "cache_read_tokens": tot_cr,
    "total_tokens": tot_in+tot_out+tot_cw+tot_cr,
    "est_cost_usd": round(cost,4),
    "by_model": by_model,
}
with open(os.path.expanduser("~/.claude/metrics/sessions.jsonl"), "a") as f:
    f.write(json.dumps(row) + "\n")
' 2>/dev/null
exit 0
