#!/usr/bin/env bash
# session-token-stop.sh — Stop hook
# Prints a brief token usage summary for the current session when Claude stops.
# Reads the most recently modified JSONL session file.
# Cost: 0 tokens (runs after Claude stops responding).

set -uo pipefail

SESSION_FILE=$(ls -t "$HOME/.claude/projects/"*/*.jsonl 2>/dev/null | head -1)
[ -z "$SESSION_FILE" ] && exit 0

python3 - "$SESSION_FILE" << 'PYEOF'
import sys, json, os
from pathlib import Path

path = Path(sys.argv[1])
turns = []

try:
    with open(path) as f:
        for raw in f:
            raw = raw.strip()
            if not raw:
                continue
            try:
                d = json.loads(raw)
            except json.JSONDecodeError:
                continue
            if d.get("type") != "assistant":
                continue
            u = d.get("message", {}).get("usage", {})
            if not u:
                continue
            turns.append({
                "in":  u.get("input_tokens", 0),
                "cw":  u.get("cache_creation_input_tokens", 0),
                "cr":  u.get("cache_read_input_tokens", 0),
                "out": u.get("output_tokens", 0),
            })
except Exception:
    sys.exit(0)

if not turns:
    sys.exit(0)

total_in  = sum(t["in"]  for t in turns)
total_cw  = sum(t["cw"]  for t in turns)
total_cr  = sum(t["cr"]  for t in turns)
total_out = sum(t["out"] for t in turns)
cache_total = total_cr + total_cw
hit_rate = total_cr / cache_total if cache_total > 0 else 0.0

# API-equivalent weight (Sonnet 4.6 list pricing) — a session-heaviness reference ONLY.
# We're on a usage plan, NOT pay-per-token, so this is NOT a bill. rate-limit-watch.sh
# tracks the real constraint (anthropic-ratelimit-* headers).
cost_usd = (
    total_in  * 3.00 +
    total_cw  * 3.75 +
    total_cr  * 0.30 +
    total_out * 15.0
) / 1_000_000

def fmt(n):
    if n >= 1_000_000: return f"{n/1_000_000:.1f}M"
    if n >= 1_000:     return f"{n/1_000:.0f}K"
    return str(n)

def fmt_cost(usd):
    if usd >= 1.0:    return f"${usd:.2f}"
    return f"${usd*100:.1f}¢"

hit_emoji = "✓" if hit_rate >= 0.60 else ("↗" if hit_rate >= 0.40 else "[WARN]")

print(f"\n── Session token summary ──────────────────────────────")
print(f"  Turns: {len(turns)}  |  Input: {fmt(total_in)}  Output: {fmt(total_out)}")
print(f"  Cache write: {fmt(total_cw)}  Cache read: {fmt(total_cr)}")
print(f"  Cache hit: {hit_rate*100:.0f}%  {hit_emoji}  |  API-equiv: {fmt_cost(cost_usd)} (not billed — usage plan)")
if hit_rate < 0.40:
    print(f"  [WARN] Low cache hits — use /context-pack at task start")
print(f"────────────────────────────────────────────────────────\n")
PYEOF
