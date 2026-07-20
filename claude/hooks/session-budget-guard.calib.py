#!/usr/bin/env python3
"""Calibrate session-budget-guard constants against the real session-log corpus.

Read-only. For every ~/.claude/projects/*/*.jsonl, reconstruct the main-chain ctx
trajectory and measure the empirical quantities the hook's constants should be fit to:
  - floor (first turn input+cache) distribution, per window-class
  - max-ctx reached (how full sessions actually get)
  - COMPACTION events (sharp ctx drop) -> the occupancy at which compaction actually
    fires = the ceiling the `hard` band must beat
  - subagent dispatch distribution + its correlation with how full the session got
  - post-compaction recovery floor
"""
import json, os, glob, statistics as st

ROOT = os.path.expanduser("~/.claude/projects")
SUB = {"task", "agent", "workflow"}

def window_for(model, maxctx):
    m = (model or "").lower()
    return 1_000_000 if ("1m" in m or "opus" in m or maxctx > 200_000) else 200_000

def ctx_of(u):
    return u.get("input_tokens",0)+u.get("cache_read_input_tokens",0)+u.get("cache_creation_input_tokens",0)

sessions = []   # per-session dicts
comp_events = []  # (trigger_pct, trigger_ctx, window, recovery_ctx, model)

files = glob.glob(os.path.join(ROOT, "*", "*.jsonl"))
parsed = skipped = 0
for fp in files:
    traj = []       # (ctx) main-chain, in order
    model = None
    subagents = 0
    try:
        with open(fp, errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line: continue
                try: e = json.loads(line)
                except Exception: continue
                if e.get("type") != "assistant": continue
                if e.get("isSidechain"): continue
                m = e.get("message", {}) or {}
                for blk in (m.get("content") or []):
                    if isinstance(blk, dict) and blk.get("type")=="tool_use" and str(blk.get("name","")).lower() in SUB:
                        subagents += 1
                u = m.get("usage") or {}
                if not u: continue
                if m.get("model"): model = m.get("model")
                c = ctx_of(u)
                if c > 0: traj.append(c)
    except Exception:
        skipped += 1
        continue
    if not traj:
        continue
    parsed += 1
    maxctx = max(traj)
    win = window_for(model, maxctx)
    floor = traj[0]
    sessions.append(dict(model=(model or "?"), win=win, floor=floor, maxctx=maxctx,
                         turns=len(traj), subagents=subagents, peakpct=maxctx/win))
    # compaction detection: sharp drop from a reasonably-full state
    for i in range(1, len(traj)):
        prev, cur = traj[i-1], traj[i]
        if prev >= 0.30*win and cur < 0.60*prev:
            comp_events.append((prev/win, prev, win, cur, model or "?"))

def pct(vals, p):
    if not vals: return float("nan")
    vals = sorted(vals)
    k = (len(vals)-1)*p/100
    lo = int(k); hi = min(lo+1, len(vals)-1)
    return vals[lo] + (vals[hi]-vals[lo])*(k-lo)

def summ(vals, scale=1, unit=""):
    if not vals: return "n=0"
    return (f"n={len(vals)} min={pct(vals,0)/scale:.1f}{unit} p25={pct(vals,25)/scale:.1f} "
            f"med={pct(vals,50)/scale:.1f} p75={pct(vals,75)/scale:.1f} p90={pct(vals,90)/scale:.1f} "
            f"p95={pct(vals,95)/scale:.1f} max={pct(vals,100)/scale:.1f}{unit}")

print(f"files={len(files)} parsed={parsed} skipped_or_empty={len(files)-parsed}")
print(f"sessions_with_data={len(sessions)} compaction_events={len(comp_events)}\n")

# split by window class
for win in (200_000, 1_000_000):
    grp = [s for s in sessions if s["win"]==win]
    if not grp: continue
    print(f"================ WINDOW {win//1000}K  (n={len(grp)} sessions) ================")
    print("  FLOOR (initial injected ctx):")
    print("    tokens:", summ([s["floor"] for s in grp], 1000, "K"))
    print("    % of win:", summ([100*s["floor"]/win for s in grp], 1, "%"))
    print("  MAX-CTX reached:")
    print("    % of win:", summ([100*s["maxctx"]/win for s in grp], 1, "%"))
    for thr in (70,85,90,92,95):
        n = sum(1 for s in grp if s["peakpct"]*100 >= thr)
        print(f"      sessions peaking >= {thr}%: {n} ({100*n/len(grp):.0f}%)")
    print("  SUBAGENT dispatches/session:", summ([s["subagents"] for s in grp],1,""))
    for thr in (3,6,10,20):
        n = sum(1 for s in grp if s["subagents"]>=thr)
        print(f"      sessions with >= {thr} dispatches: {n} ({100*n/len(grp):.0f}%)")
    # do subagent-heavy sessions reach higher ctx?
    heavy = [s["peakpct"]*100 for s in grp if s["subagents"]>=6]
    light = [s["peakpct"]*100 for s in grp if s["subagents"]<6]
    if heavy and light:
        print(f"      peak% median: subagent>=6 -> {pct(heavy,50):.0f}%   <6 -> {pct(light,50):.0f}%")
    print()

print("================ COMPACTION EVENTS (the empirical ceiling) ================")
if comp_events:
    trig = [c[0]*100 for c in comp_events]
    print("  trigger occupancy %% (ctx just before a sharp drop):")
    print("   ", summ(trig, 1, "%"))
    # the built-in auto-compact clusters HIGH; manual /compact + /clear scatter lower.
    for lo in (70,80,85,90):
        hi = [t for t in trig if t>=lo]
        if hi:
            print(f"    events >= {lo}%: n={len(hi)} median={st.median(hi):.0f}% min={min(hi):.0f}%")
    # recovery floor after compaction
    rec = [c[3] for c in comp_events]
    print("  RECOVERY ctx after compaction (tokens):", summ(rec,1000,"K"))
    # per window
    for win in (200_000,1_000_000):
        wv=[c[0]*100 for c in comp_events if c[2]==win]
        if wv: print(f"    trigger%% @ {win//1000}K window:", summ(wv,1,"%"))
else:
    print("  none detected")
