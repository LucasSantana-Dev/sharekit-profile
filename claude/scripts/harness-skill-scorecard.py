#!/usr/bin/env python3
"""harness-skill-scorecard.py — objective, model-independent quality scorecard for the skill catalog.

Runs the same structural checks as the skill-quality-gate hook across EVERY skill (not just on edit),
so harness quality has a NUMBER you can regression-test. Re-run after changes to prove a delta.

  HARD (a skill is BROKEN): invalid YAML frontmatter, no frontmatter, unclosed code fence.
  SOFT (quality nudge):     name != dir (intentional for adt-*/plugin-* namespaces), under 30 lines,
                            no 'Done when', no Hard/Stop section, no workflow structure.
  Classification mirrors the skill-quality-gate.sh hook exactly (gate = source of truth): name!=dir
  is SOFT there because plugin-namespaced + adt-* dirs legitimately differ from their invocation name.

Usage:
  harness-skill-scorecard.py                 # human table over ~/.agents/skills
  harness-skill-scorecard.py --json          # machine JSON (for CI/regression baselines)
  harness-skill-scorecard.py --root <dir>    # override skills root
"""
import os, re, sys, json, glob

ROOT = os.path.expanduser("~/.agents/skills")
if "--root" in sys.argv:
    _ri = sys.argv.index("--root")
    if _ri + 1 >= len(sys.argv):
        raise SystemExit("error: --root requires a value")
    ROOT = sys.argv[_ri + 1]
AS_JSON = "--json" in sys.argv

try:
    import yaml
except Exception:
    yaml = None

def frontmatter(text):
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        return None, "no-frontmatter"
    if yaml is None:
        return {}, None
    try:
        return (yaml.safe_load(m.group(1)) or {}), None
    except Exception as e:
        return None, f"invalid-yaml:{type(e).__name__}"

def check(path):
    name = os.path.basename(os.path.dirname(path))
    try:
        text = open(path, encoding="utf-8", errors="replace").read()
    except Exception as e:
        return {"name": name, "hard": ["unreadable"], "soft": []}
    hard, soft = [], []
    fm, err = frontmatter(text)
    if err and err.startswith("invalid-yaml"):
        hard.append("invalid-yaml")
    elif err == "no-frontmatter":
        hard.append("no-frontmatter")
    # unclosed fence
    if len(re.findall(r"^```", text, re.M)) % 2 != 0:
        hard.append("unclosed-fence")
    # soft
    # name != dir — SOFT (mirrors gate): adt-* and plugin-* dirs legitimately differ from invocation name
    if isinstance(fm, dict):
        fn = (fm.get("name") or "").strip()
        if fn and fn != name:
            soft.append(f"name!=dir({fn})")
    if len(text.splitlines()) <= 30:
        soft.append("under-30-lines")
    # Broadened 2026-06-26: composites encode completion in a "## Reconciliation" block (their
    # output contract) — counts as a checkable done-state. Old narrow literal false-flagged 28.
    if not re.search(r"done when|^##+ .*(reconciliation|completion criteria|success criteria|definition of done|exit criteria|acceptance criteria)|^##+ .*\bdone\b", text, re.I | re.M):
        soft.append("no-done-when")
    # Broadened 2026-06-26: real composites use "Stop / escalation conditions", "Preconditions
    # (hard-fail ...)", "bail out", etc. The old narrow "stop condition" literal false-flagged ~7
    # composites that DO halt. Metric must be honest or it mis-guides every quality pass.
    if not re.search(r"^##+ .*(stop|halt|escalat|precondition|hard.?fail|hard rule|negative rule|rationaliz|bail|abort|failure mode)", text, re.I | re.M):
        soft.append("no-stop-conditions")
    if not re.search(r"^##+ .*(Phase|Step|Process|Workflow|Mode|Cycle|Recipe|Pipeline)|^\*\*Step|^[0-9]+\. ", text, re.M):
        soft.append("no-workflow")
    return {"name": name, "hard": hard, "soft": soft}

def main():
    paths = sorted(glob.glob(os.path.join(ROOT, "*", "SKILL.md")))
    rows = [check(p) for p in paths]
    total = len(rows)
    hard_fail = [r for r in rows if r["hard"]]
    clean = [r for r in rows if not r["hard"] and not r["soft"]]
    from collections import Counter
    hc, sc = Counter(), Counter()
    for r in rows:
        for h in r["hard"]:
            hc[re.sub(r"\(.*\)", "", h)] += 1
        for s in r["soft"]:
            sc[s] += 1
    score = round(100 * (total - len(hard_fail)) / total, 1) if total else 0.0
    summary = {
        "root": ROOT, "total_skills": total,
        "hard_clean": total - len(hard_fail), "hard_fail": len(hard_fail),
        "structural_score_pct": score,
        "fully_clean": len(clean),
        "hard_breakdown": dict(hc), "soft_breakdown": dict(sc),
        "hard_fail_skills": sorted(r["name"] + ":" + ",".join(r["hard"]) for r in hard_fail),
    }
    if AS_JSON:
        print(json.dumps(summary, indent=2))
        return
    print(f"HARNESS SKILL SCORECARD — {ROOT}")
    print(f"  skills:               {total}")
    print(f"  structural score:     {score}%  ({summary['hard_clean']}/{total} with zero HARD defects)")
    print(f"  fully clean (0 soft): {len(clean)}")
    print(f"  HARD defects:         {dict(hc) or 'none'}")
    print(f"  SOFT nudges:          {dict(sc)}")
    if hard_fail:
        print("  --- HARD-fail skills ---")
        for r in hard_fail:
            print(f"    {r['name']}: {', '.join(r['hard'])}")

if __name__ == "__main__":
    main()
