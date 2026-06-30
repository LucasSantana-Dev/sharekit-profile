#!/usr/bin/env python3
"""Token usage audit for Claude Code sessions.

Parses ~/.claude/projects/*/  *.jsonl and reports token spend,
cache efficiency, trends, and top costly sessions.

Usage:
  python3 audit.py               # last 30 days
  python3 audit.py --days 7      # last 7 days
  python3 audit.py --today       # today only
  python3 audit.py --session ID  # single session detail
  python3 audit.py --json        # machine-readable output
"""
import argparse
import json
import os
import sys
from collections import defaultdict
from datetime import datetime, timezone, timedelta
from pathlib import Path


# Pricing per 1M tokens (USD) — Anthropic 2025/2026 rates
PRICING = {
    "sonnet": {"input": 3.00, "cache_write": 3.75, "cache_read": 0.30, "output": 15.00},
    "haiku":  {"input": 0.80, "cache_write": 1.00, "cache_read": 0.08, "output": 4.00},
    "opus":   {"input": 15.0, "cache_write": 18.75,"cache_read": 1.50, "output": 75.00},
}


def infer_model(model_str: str | None) -> str:
    if not model_str:
        return "sonnet"
    m = (model_str or "").lower()
    if "haiku" in m:
        return "haiku"
    if "opus" in m:
        return "opus"
    return "sonnet"


def cost(tokens: dict, model: str) -> float:
    p = PRICING.get(model, PRICING["sonnet"])
    return (
        tokens.get("input", 0) * p["input"] +
        tokens.get("cache_write", 0) * p["cache_write"] +
        tokens.get("cache_read", 0) * p["cache_read"] +
        tokens.get("output", 0) * p["output"]
    ) / 1_000_000


def parse_session(path: Path) -> dict | None:
    turns = []
    dominant_model = None
    model_turn_counts: dict[str, int] = defaultdict(int)
    first_ts = None
    last_ts = None

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

                ts = d.get("timestamp")
                if ts:
                    if first_ts is None:
                        first_ts = ts
                    last_ts = ts

                if d.get("type") != "assistant":
                    continue

                msg = d.get("message", {})
                usage = msg.get("usage", {})
                if not usage:
                    continue

                # Per-turn model for accurate cost on mixed-model sessions
                turn_model_str = msg.get("model") or d.get("model")
                turn_model = infer_model(turn_model_str)
                model_turn_counts[turn_model] += 1

                # Cache creation detail
                cc = usage.get("cache_creation", {}) or {}
                cache_write = (
                    usage.get("cache_creation_input_tokens", 0) or
                    cc.get("ephemeral_5m_input_tokens", 0) + cc.get("ephemeral_1h_input_tokens", 0)
                )
                turns.append({
                    "input":       usage.get("input_tokens", 0),
                    "cache_write": cache_write,
                    "cache_read":  usage.get("cache_read_input_tokens", 0),
                    "output":      usage.get("output_tokens", 0),
                    "_model":      turn_model,
                })
    except (OSError, PermissionError):
        return None

    if not turns:
        return None

    totals = {k: sum(t[k] for t in turns) for k in ("input", "cache_write", "cache_read", "output")}

    # Cost per turn using its own model (fixes mixed-model session overcharging)
    net_cost = sum(cost({k: t[k] for k in ("input", "cache_write", "cache_read", "output")}, t["_model"]) for t in turns)

    # Dominant model = whichever had the most turns
    dominant_model = max(model_turn_counts, key=model_turn_counts.get) if model_turn_counts else "sonnet"

    # Cache hit rate: cache_read / (cache_read + cache_write), if any cache activity
    cache_total = totals["cache_read"] + totals["cache_write"]
    cache_hit_rate = totals["cache_read"] / cache_total if cache_total > 0 else 0.0

    # Effective savings vs no-cache baseline using dominant model pricing
    p = PRICING.get(dominant_model, PRICING["sonnet"])
    savings_usd = totals["cache_read"] * (p["input"] - p["cache_read"]) / 1_000_000

    return {
        "session_id": path.stem,
        "path": str(path),
        "model": dominant_model,
        "turns": len(turns),
        "first_ts": first_ts,
        "last_ts": last_ts,
        "tokens": totals,
        "cache_hit_rate": cache_hit_rate,
        "net_cost_usd": net_cost,
        "cache_savings_usd": savings_usd,
    }


PROJECT_DIR_LABELS = {
    "-Users-lucassantana": "home",
    "-Volumes-External-HD-Desenvolvimento-Lucky": "Lucky",
    "-Volumes-External-HD-Desenvolvimento-ai-dev-toolkit": "ai-dev-toolkit",
    "-Volumes-External-HD-Desenvolvimento-networking-linkedin-engage": "linkedin-engage",
    "-Volumes-External-HD-Desenvolvimento-networking": "networking",
    "-Volumes-External-HD-Clone-Hero": "clone-hero",
}


def project_label(jsonl_path: Path) -> str:
    proj = jsonl_path.parent.name
    for key, label in PROJECT_DIR_LABELS.items():
        if proj.startswith(key):
            return label
    # Generic: strip common prefix and truncate
    return proj.replace("-Volumes-External-HD-Desenvolvimento-", "").replace("-Users-lucassantana-Desenvolvimento-", "")[:30]


def load_sessions(
    projects_dir: Path,
    since: datetime | None = None,
    session_id: str | None = None,
    project_filter: str | None = None,
) -> list[dict]:
    sessions = []
    pattern = f"{session_id}.jsonl" if session_id else "*.jsonl"

    for jsonl in projects_dir.rglob(pattern):
        label = project_label(jsonl)
        if project_filter and project_filter.lower() not in label.lower():
            continue
        s = parse_session(jsonl)
        if s is None:
            continue
        s["project"] = label
        if since and s["first_ts"]:
            try:
                ts = datetime.fromisoformat(s["first_ts"].replace("Z", "+00:00"))
                if ts < since:
                    continue
            except ValueError:
                pass
        sessions.append(s)

    sessions.sort(key=lambda s: s["first_ts"] or "", reverse=True)
    return sessions


def fmt_tokens(n: int) -> str:
    if n >= 1_000_000:
        return f"{n/1_000_000:.1f}M"
    if n >= 1_000:
        return f"{n/1_000:.0f}K"
    return str(n)


def fmt_cost(usd: float) -> str:
    if usd >= 1.0:
        return f"${usd:.2f}"
    return f"${usd*100:.1f}¢"


def bar(ratio: float, width: int = 20) -> str:
    filled = int(ratio * width)
    return "█" * filled + "░" * (width - filled)


def print_report(sessions: list[dict], title: str = "Token Audit") -> None:
    if not sessions:
        print("No sessions found.")
        return

    # Aggregate
    total_in    = sum(s["tokens"]["input"] for s in sessions)
    total_cw    = sum(s["tokens"]["cache_write"] for s in sessions)
    total_cr    = sum(s["tokens"]["cache_read"] for s in sessions)
    total_out   = sum(s["tokens"]["output"] for s in sessions)
    total_cost  = sum(s["net_cost_usd"] for s in sessions)
    total_saved = sum(s["cache_savings_usd"] for s in sessions)
    total_turns = sum(s["turns"] for s in sessions)

    cache_total = total_cr + total_cw
    hit_rate = total_cr / cache_total if cache_total > 0 else 0.0

    W = 62
    print()
    print("━" * W)
    print(f"  {title}")
    print("━" * W)
    print(f"  Sessions:      {len(sessions):>6,}   Turns:         {total_turns:>8,}")
    print(f"  Input tokens:  {fmt_tokens(total_in):>6}   Cache write:   {fmt_tokens(total_cw):>8}")
    print(f"  Output tokens: {fmt_tokens(total_out):>6}   Cache read:    {fmt_tokens(total_cr):>8}")
    print()
    print(f"  Cache hit rate: {hit_rate*100:.1f}%  {bar(hit_rate)}")
    print(f"  Net cost est:  {fmt_cost(total_cost):>8}   Cache saved:   {fmt_cost(total_saved)}")
    print()

    # Cache guidance
    if hit_rate < 0.40:
        print("  ⚠ Cache hit rate < 40% — many cold starts detected.")
        print("    Use /context-pack before new tasks. Avoid /clear mid-session.")
    elif hit_rate < 0.60:
        print("  ↗ Cache hit rate OK. Target 60%+ by using context-pack.")
    else:
        print("  ✓ Cache hit rate healthy (≥ 60%).")

    # Top 10 by cost
    top = sorted(sessions, key=lambda s: s["net_cost_usd"], reverse=True)[:10]
    if len(top) > 1:
        print()
        print(f"  {'Top sessions by cost':40} {'turns':>5}  {'cost':>6}  {'hit%':>5}")
        print(f"  {'─'*40} {'─'*5}  {'─'*6}  {'─'*5}")
        for s in top:
            sid = s["session_id"][:8]
            ts = (s["first_ts"] or "")[:10]
            label = f"{sid}  {ts}"
            turns = s["turns"]
            c = fmt_cost(s["net_cost_usd"])
            hr = f"{s['cache_hit_rate']*100:.0f}%"
            print(f"  {label:40} {turns:>5}  {c:>6}  {hr:>5}")

    # Per-project breakdown
    by_proj: dict[str, dict] = defaultdict(lambda: {"cost": 0.0, "turns": 0, "sessions": 0, "cache_read": 0, "cache_write": 0})
    for s in sessions:
        proj = s.get("project", "unknown")
        by_proj[proj]["cost"] += s["net_cost_usd"]
        by_proj[proj]["turns"] += s["turns"]
        by_proj[proj]["sessions"] += 1
        by_proj[proj]["cache_read"] += s["tokens"]["cache_read"]
        by_proj[proj]["cache_write"] += s["tokens"]["cache_write"]

    if len(by_proj) > 1:
        proj_list = sorted(by_proj.items(), key=lambda x: -x[1]["cost"])
        print()
        print(f"  {'By project':30} {'sessions':>8} {'turns':>6}  {'cost':>8}  {'hit%':>5}")
        print(f"  {'─'*30} {'─'*8} {'─'*6}  {'─'*8}  {'─'*5}")
        for proj, pd in proj_list:
            ct = pd["cache_read"] + pd["cache_write"]
            hr = f"{pd['cache_read']/ct*100:.0f}%" if ct > 0 else "n/a"
            print(f"  {proj:30} {pd['sessions']:>8} {pd['turns']:>6}  {fmt_cost(pd['cost']):>8}  {hr:>5}")

    # Weekly trend (last 8 weeks)
    by_week: dict[str, dict] = defaultdict(lambda: {"cost": 0.0, "turns": 0, "sessions": 0})
    for s in sessions:
        if not s["first_ts"]:
            continue
        try:
            ts = datetime.fromisoformat(s["first_ts"].replace("Z", "+00:00"))
            week = ts.strftime("%Y-W%V")
            by_week[week]["cost"] += s["net_cost_usd"]
            by_week[week]["turns"] += s["turns"]
            by_week[week]["sessions"] += 1
        except ValueError:
            pass

    if by_week:
        weeks = sorted(by_week.keys())[-8:]
        max_cost = max(by_week[w]["cost"] for w in weeks) or 1
        print()
        print("  Weekly trend")
        print(f"  {'Week':10} {'sessions':>8} {'turns':>6}  {'cost':>6}  bar")
        print(f"  {'─'*10} {'─'*8} {'─'*6}  {'─'*6}  {'─'*20}")
        for week in weeks:
            wd = by_week[week]
            b = bar(wd["cost"] / max_cost, 20)
            print(f"  {week:10} {wd['sessions']:>8} {wd['turns']:>6}  {fmt_cost(wd['cost']):>6}  {b}")

    print()
    print("━" * W)
    print()


def print_session_detail(s: dict) -> None:
    W = 62
    t = s["tokens"]
    print()
    print("━" * W)
    print(f"  Session: {s['session_id']}")
    print(f"  Model:   {s['model']}  |  Turns: {s['turns']}")
    print(f"  From:    {(s['first_ts'] or 'unknown')[:19]}")
    print(f"  To:      {(s['last_ts'] or 'unknown')[:19]}")
    print("━" * W)
    print(f"  Input tokens:      {fmt_tokens(t['input']):>8}")
    print(f"  Cache write:       {fmt_tokens(t['cache_write']):>8}")
    print(f"  Cache read:        {fmt_tokens(t['cache_read']):>8}")
    print(f"  Output tokens:     {fmt_tokens(t['output']):>8}")
    print()
    print(f"  Cache hit rate:    {s['cache_hit_rate']*100:.1f}%")
    print(f"  Net cost estimate: {fmt_cost(s['net_cost_usd'])}")
    print(f"  Cache savings:     {fmt_cost(s['cache_savings_usd'])}")
    print("━" * W)
    print()


def main() -> None:
    p = argparse.ArgumentParser(description="Claude Code token usage audit")
    p.add_argument("--days", type=int, default=30, help="Look back N days (default 30)")
    p.add_argument("--today", action="store_true", help="Today only")
    p.add_argument("--session", metavar="ID", help="Single session detail")
    p.add_argument("--json", action="store_true", help="JSON output")
    p.add_argument("--dir", default=None, help="Override projects directory")
    p.add_argument("--project", metavar="NAME", help="Filter by project name (substring match)")
    args = p.parse_args()

    projects_dir = Path(args.dir) if args.dir else Path.home() / ".claude" / "projects"

    if args.today:
        since = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
        title = f"Token Audit — Today ({since.strftime('%Y-%m-%d')})"
    elif args.session:
        since = None
        title = f"Session {args.session}"
    else:
        since = datetime.now(timezone.utc) - timedelta(days=args.days)
        title = f"Token Audit — Last {args.days} days"

    sessions = load_sessions(projects_dir, since=since, session_id=args.session, project_filter=args.project)
    if args.project:
        title += f" · project:{args.project}"

    if args.json:
        print(json.dumps(sessions, indent=2, default=str))
        return

    if args.session:
        if sessions:
            print_session_detail(sessions[0])
        else:
            print(f"Session '{args.session}' not found.")
    else:
        print_report(sessions, title=title)


if __name__ == "__main__":
    main()
