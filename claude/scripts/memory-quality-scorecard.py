#!/usr/bin/env python3
"""memory-quality-scorecard.py — objective quality metric for the memory corpus, so "memory quality"
has a NUMBER you can track over time and regression-gate (the sibling of harness-skill-scorecard.py).

  HARD (a memory is BROKEN — won't load/retrieve well): no frontmatter, invalid YAML, no name, no description.
  SOFT (quality nudges): thin description (<40 chars), thin body (<2 lines), no type tag, orphan
    [[wikilinks]], likely-stale (cites a merged PR / 'fixed'/'shipped' with a # ref — review),
    duplicate description (near-dup memories dilute retrieval).

Usage:
  memory-quality-scorecard.py                # human table
  memory-quality-scorecard.py --json         # machine JSON (baseline / time-series)
  memory-quality-scorecard.py --root <dir>   # override memory dir
  memory-quality-scorecard.py --stale        # list staleness-candidate files for a prune pass
"""
import os, re, sys, json, glob
from collections import Counter

ROOT = os.path.expanduser("~/.claude/projects/-Users-<github-user>/memory")
if "--root" in sys.argv:
    _ri = sys.argv.index("--root")
    if _ri + 1 >= len(sys.argv):
        raise SystemExit("error: --root requires a value")
    ROOT = sys.argv[_ri + 1]
AS_JSON = "--json" in sys.argv
LIST_STALE = "--stale" in sys.argv

try:
    import yaml
except Exception:
    yaml = None

STALE_RE = re.compile(r"\b(merged|fixed|shipped|closed|deployed|resolved)\b.{0,40}#\d+|\bPR #\d+\b.{0,20}\b(merged|landed)\b", re.I)
WIKILINK_RE = re.compile(r"\[\[([a-z0-9][a-z0-9_-]+)\]\]", re.I)

def parse(path):
    text = open(path, encoding="utf-8", errors="replace").read()
    m = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.S)
    if not m:
        return None, None, text
    fm_raw, body = m.group(1), m.group(2)
    if yaml is None:
        return {}, body, text
    try:
        return (yaml.safe_load(fm_raw) or {}), body, text
    except Exception:
        return "INVALID", body, text

def check(path, names):
    name = os.path.basename(path)[:-3]
    hard, soft, stale = [], [], False
    fm, body, text = parse(path)
    if fm is None:
        hard.append("no-frontmatter"); return name, hard, soft, stale
    if fm == "INVALID":
        hard.append("invalid-yaml"); return name, hard, soft, stale
    if not (fm.get("name") or "").strip():
        hard.append("no-name")
    desc = (fm.get("description") or "").strip()
    if not desc:
        hard.append("no-description")
    elif len(desc) < 40:
        soft.append("thin-description")
    # type tag (node_type / metadata.type / tags type/*)
    md = fm.get("metadata") or {}
    has_type = bool(md.get("type") or md.get("node_type")) or any(
        str(t).startswith("type/") for t in (fm.get("tags") or []))
    if not has_type:
        soft.append("no-type")
    if len([l for l in (body or "").splitlines() if l.strip()]) < 2:
        soft.append("thin-body")
    # orphan wikilinks
    for target in WIKILINK_RE.findall(body or ""):
        if target.lower() not in names:
            soft.append("orphan-link"); break
    if STALE_RE.search(text):
        soft.append("stale-candidate"); stale = True
    return name, hard, soft, stale

def main():
    paths = sorted(p for p in glob.glob(os.path.join(ROOT, "*.md"))
                   if os.path.basename(p) != "MEMORY.md")
    names = {os.path.basename(p)[:-3].lower() for p in paths}
    rows, descs = [], Counter()
    for p in paths:
        r = check(p, names); rows.append(r)
        fm, _, _ = parse(p)
        if isinstance(fm, dict):
            d = (fm.get("description") or "").strip().lower()
            if d:
                descs[d] += 1
    dups = sum(1 for d, n in descs.items() if n > 1)
    total = len(rows)
    hard_fail = [r for r in rows if r[1]]
    clean = [r for r in rows if not r[1] and not r[2]]
    hc, sc = Counter(), Counter()
    for _, h, s, _ in rows:
        for x in h: hc[x] += 1
        for x in s: sc[x] += 1
    stale_files = [r[0] for r in rows if r[3]]
    score = round(100 * (total - len(hard_fail)) / total, 1) if total else 0.0
    summary = {
        "root": ROOT, "total_memories": total,
        "hard_clean": total - len(hard_fail), "hard_fail": len(hard_fail),
        "memory_quality_pct": score, "fully_clean": len(clean),
        "duplicate_descriptions": dups,
        "hard_breakdown": dict(hc), "soft_breakdown": dict(sc),
        "stale_candidates": len(stale_files),
        "hard_fail_files": sorted(r[0] + ":" + ",".join(r[1]) for r in hard_fail),
    }
    if LIST_STALE:
        print("\n".join(stale_files)); return
    if AS_JSON:
        print(json.dumps(summary, indent=2)); return
    print(f"MEMORY QUALITY SCORECARD — {ROOT}")
    print(f"  memories:            {total}")
    print(f"  quality score:       {score}%  ({summary['hard_clean']}/{total} zero-HARD)")
    print(f"  fully clean (0 soft):{len(clean)}")
    print(f"  duplicate descs:     {dups}")
    print(f"  stale candidates:    {len(stale_files)}  (run --stale to list; feed to /memory-prune)")
    print(f"  HARD defects:        {dict(hc) or 'none'}")
    print(f"  SOFT nudges:         {dict(sc)}")
    if hard_fail:
        print("  --- HARD-fail ---")
        for r in hard_fail[:20]:
            print(f"    {r[0]}: {', '.join(r[1])}")

if __name__ == "__main__":
    main()
