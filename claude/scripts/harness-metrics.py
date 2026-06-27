#!/usr/bin/env python3
"""harness-metrics.py — the "improvement over time" engine. Aggregates every harness quality signal
into ONE dated row appended to a JSONL time-series, then prints the trend (latest vs prior) so
improvement or regression is VISIBLE, not point-in-time. Run weekly by the diagnostic; run ad-hoc to
see where things stand.

Signals: skill structural score, memory quality score, self-test pass/fail, catalog sizes, plus any
token/cost rows already captured in metrics/sessions.jsonl (rolling 7-day spend — cost lever).

Usage:
  harness-metrics.py            # append today's row + print trend
  harness-metrics.py --trend    # print trend only (no append)
  harness-metrics.py --json     # latest row as JSON
  harness-metrics.py --date YYYY-MM-DD   # stamp the appended row (scripts can't call date())
"""
import os, sys, json, subprocess, glob, time

HOME = os.path.expanduser("~")
SCRIPTS = f"{HOME}/.claude/scripts"
METRICS_DIR = f"{HOME}/.claude/metrics"
SERIES = f"{METRICS_DIR}/harness-metrics.jsonl"
SESSIONS = f"{METRICS_DIR}/sessions.jsonl"
APPEND = "--trend" not in sys.argv and "--json" not in sys.argv
DATE = None
if "--date" in sys.argv:
    _di = sys.argv.index("--date")
    if _di + 1 >= len(sys.argv):
        raise SystemExit("error: --date requires a value")
    DATE = sys.argv[_di + 1]

def run_json(script, *args):
    try:
        out = subprocess.run([sys.executable, f"{SCRIPTS}/{script}", "--json", *args],
                             capture_output=True, text=True, timeout=60).stdout
        return json.loads(out)
    except Exception:
        return {}

def selftest_pass():
    # Guard against recursion: the self-test itself invokes harness-metrics --json; without this,
    # selftest → metrics → selftest loops until timeout. The self-test sets HARNESS_SELFTEST=1.
    if os.environ.get("HARNESS_SELFTEST"):
        return None
    st = f"{HOME}/.claude/test/harness-selftest.sh"
    if not os.path.exists(st):
        return None
    try:
        r = subprocess.run(["bash", st], capture_output=True, text=True, timeout=120)
        return r.returncode == 0
    except Exception:
        return None

def rolling_token_cost():
    """Sum est_cost_usd + tokens over sessions.jsonl rows in the last 7 days (cost lever)."""
    if not os.path.exists(SESSIONS):
        return None
    cutoff = time.time() - 7 * 86400
    cost, toks, n = 0.0, 0, 0
    for line in open(SESSIONS, errors="ignore"):
        try:
            d = json.loads(line)
        except Exception:
            continue
        if float(d.get("ts", 0)) < cutoff:
            continue
        cost += float(d.get("est_cost_usd", 0) or 0)
        toks += int(d.get("total_tokens", 0) or 0)
        n += 1
    return {"sessions_7d": n, "tokens_7d": toks, "est_cost_usd_7d": round(cost, 2)} if n else None

def collect():
    skill = run_json("harness-skill-scorecard.py")
    mem = run_json("memory-quality-scorecard.py")
    row = {
        "date": DATE or "unset",
        "skill_structural_pct": skill.get("structural_score_pct"),
        "skill_hard_fail": skill.get("hard_fail"),
        "skill_count": skill.get("total_skills"),
        "skill_soft_done_when": (skill.get("soft_breakdown") or {}).get("no-done-when"),
        "memory_quality_pct": mem.get("memory_quality_pct"),
        "memory_hard_fail": mem.get("hard_fail"),
        "memory_count": mem.get("total_memories"),
        "memory_stale_candidates": mem.get("stale_candidates"),
        "selftest_pass": selftest_pass(),
    }
    tc = rolling_token_cost()
    if tc:
        row.update(tc)
    return row

def fmt(v):
    return "—" if v is None else (f"{v}" if not isinstance(v, float) else f"{v:g}")

def trend():
    if not os.path.exists(SERIES):
        print("(no metrics history yet)"); return
    rows = [json.loads(l) for l in open(SERIES) if l.strip()]
    if not rows:
        print("(empty)"); return
    keys = ["date", "skill_structural_pct", "memory_quality_pct", "selftest_pass",
            "skill_count", "memory_count", "memory_stale_candidates", "est_cost_usd_7d"]
    last = rows[-6:]
    print("HARNESS METRICS — trend (last %d points)" % len(last))
    print("  " + " | ".join(f"{k.replace('_',' ')[:16]:>16}" for k in keys))
    for r in last:
        print("  " + " | ".join(f"{fmt(r.get(k)):>16}" for k in keys))
    if len(rows) >= 2:
        a, b = rows[-2], rows[-1]
        for k in ("skill_structural_pct", "memory_quality_pct"):
            if a.get(k) is not None and b.get(k) is not None:
                d = round(b[k] - a[k], 1)
                arrow = "↑" if d > 0 else ("↓ REGRESSION" if d < 0 else "·")
                print(f"  Δ {k}: {d:+} {arrow}")

def main():
    os.makedirs(METRICS_DIR, exist_ok=True)
    row = collect()
    if "--json" in sys.argv:
        print(json.dumps(row, indent=2)); return
    if APPEND:
        with open(SERIES, "a") as f:
            f.write(json.dumps(row) + "\n")
    trend()

if __name__ == "__main__":
    main()
