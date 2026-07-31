#!/usr/bin/env python3
"""build_dataset.py — distill episodes.jsonl into the frozen routing eval dataset.

Filters non-routing noise (explicit slash invocations already tagged, plus
continuation replies, image-only messages, tool-output echoes), then applies a
hand-reviewed exclusion list. Output: dataset/routing_v0.jsonl with
{"id", "prompt", "expected"} per line.
"""
from __future__ import annotations

import json
import os
import re
import sys

HERE = os.path.dirname(__file__)
EPISODES = os.path.join(HERE, "dataset", "episodes.jsonl")
OUT = os.path.join(HERE, "dataset", "routing_v0.jsonl")

# Prompt shapes that carry no routing signal.
_NOISE_RX = re.compile(
    r"^(\[Image|<bash-stdout|<command-message|UserPromptSubmit hook|"
    r"This session is being continued|Stop hook feedback|"
    r"\[Request interrupted|yes\b|continue\b|wait for\b)",
    re.IGNORECASE,
)

# Hand-reviewed exclusions: sha1(skill|prompt[:80])[:8] of episodes whose pairing
# is wrong or whose prompt only makes sense with prior conversation context.
# Content-hashed so they survive extractor changes. Reviewed 2026-07-28.
EXCLUDE_HASHES = {
    "8562b35c",  # update-config: wrong pairing (skill-creation request)
    "83f5d8c6",  # plan: compaction request, dubious pairing
    "bccd62d8",  # artifact-design: cloudflare audit request, dubious
    "6f588324",  # shorts-edit: token-tracking request, dubious
    "456adc4f",  # deep-audit: names /efficiency-advisor inline
    "5ec6baf2",  # hook-effectiveness: gh pr checks/merge, dubious
    "90e86daa",  # artifact-design: mid-conversation tools discussion
    "ea339816",  # backlog: PR-list check, dubious
    "aa84b36f",  # sync-memories: backlog-addition request
    "449ba252",  # adt-research: names /deep-research /recall inline
    "38358b77",  # sync-memories: "It's WIP, leave it" reply
    "bfa4a3f2",  # code-review: "do both" reply
    "a9841bcd",  # artifact-design: mid-conversation metrics
    "c5ba54c8",  # tdd: mid-conversation report environment
    "48f27fe1",  # artifact-design: graphics request, mid-conversation
    "07adc520",  # knowledge-loop: hardware-naming request, dubious
    "78b64f91",  # knowledge-loop: "commit, it's perfect" reply
    "a7bef19c",  # debate: release-cut request, dubious
    "ae6d8b37",  # github-actions-hardening: vague "use them", dubious
    "386b5b53",  # artifact-design: figma motion, mid-conversation
    "45664ca1",  # artifact-design: design-variations reply
    "5eec8c31",  # research-and-decide: merge-PRs request, dubious
}


def main() -> int:
    import argparse
    import hashlib
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="inp", default=EPISODES)
    ap.add_argument("--out", dest="out", default=OUT)
    ap.add_argument("--id-prefix", default="rt")
    args = ap.parse_args()
    eps = [json.loads(l) for l in open(args.inp)]
    auto = [e for e in eps if not e["explicit"]]
    kept: list[dict] = []
    for e in auto:
        prompt = " ".join(e["prompt"].split())
        if len(prompt) < 40 or _NOISE_RX.match(prompt):
            continue
        h = hashlib.sha1((e["skill"] + "|" + prompt[:80]).encode()).hexdigest()[:8]
        if h in EXCLUDE_HASHES:
            continue
        kept.append({
            "id": f"{args.id_prefix}-{len(kept):03d}",
            "prompt": prompt,
            "expected": e["skill"],
            "ts": e.get("ts"),
        })
    with open(args.out, "w") as f:
        for k in kept:
            f.write(json.dumps(k, ensure_ascii=False) + "\n")
    from collections import Counter
    dist = Counter(k["expected"] for k in kept)
    print(f"{len(kept)} routing tasks -> {args.out}")
    print("distribution:", dist.most_common())
    return 0


if __name__ == "__main__":
    sys.exit(main())
