"""Refuse to dispatch a visual builder without the owner's anchor, once one is needed.

usage: python3 check_brief.py <brief.md>   -> exit 0 releases, exit 1 blocks

The brief needs these lines (values after the colon):
  ANCHOR: <path(s) to what the owner picked on the recognition board, or "n/a" before the
    first rejection>
  ANCHOR_DATE: YYYY-MM-DD or YYYY-MM-DDTHH:MM, or "n/a" before the first rejection
  ANCHOR_QUOTE: <the owner's own words about the pick, or "n/a" before the first rejection>
  CONSECUTIVE_REJECTIONS: <n>
  LAST_REJECTION: YYYY-MM-DD[THH:MM], or "none"/"n/a" if there has not been one
  RULES_CONSULTED: <design memories and ADRs read before this brief>
  ART_IN_CODE: no   (a character, mascot, or vehicle is never drawn in code; always required)

Below 2 consecutive rejections, ANCHOR / ANCHOR_DATE / ANCHOR_QUOTE may all read "n/a": a
first build on a greenfield project, or one with no reachable owner, does not need a
recognition-board anchor yet. From 2 consecutive rejections on, a real anchor dated strictly
after the last rejection is mandatory. When either date has no time of day, the comparison
falls back to calendar dates only, and a same-day tie still blocks.
"""
import re
import sys
from datetime import datetime

FIELDS = ["ANCHOR", "ANCHOR_DATE", "ANCHOR_QUOTE", "CONSECUTIVE_REJECTIONS",
          "LAST_REJECTION", "RULES_CONSULTED", "ART_IN_CODE"]
ANCHOR_FIELDS = ("ANCHOR", "ANCHOR_DATE", "ANCHOR_QUOTE")
NONE_SENTINELS = {"none", "n/a"}


def main(path):
    text = open(path, encoding="utf-8").read()
    values = {f: (m.group(1).strip() if (m := re.search(rf"^{f}:\s*(.+)$", text, re.M)) else "")
              for f in FIELDS}
    errors = [f"missing {f}" for f, v in values.items() if not v]
    if errors:
        for e in errors:
            print("BLOCKED:", e)
        return 1

    if values["ART_IN_CODE"].lower() != "no":
        errors.append("ART_IN_CODE must be 'no'")

    n = None
    try:
        n = int(values["CONSECUTIVE_REJECTIONS"])
    except (ValueError, TypeError) as e:
        errors.append(f"invalid CONSECUTIVE_REJECTIONS: {e}")

    if n is not None and n >= 2:
        na_fields = [f for f in ANCHOR_FIELDS if values[f].strip().lower() in NONE_SENTINELS]
        if na_fields:
            errors.append(
                f"{n} consecutive rejections but {', '.join(na_fields)} still reads 'n/a': "
                f"go back to the recognition board and record a real anchor, do not dispatch "
                f"a third build"
            )
        else:
            last = values["LAST_REJECTION"].strip()
            if last.lower() not in NONE_SENTINELS:
                try:
                    anchor_raw = values["ANCHOR_DATE"]
                    anchor_dt = datetime.fromisoformat(anchor_raw)
                    last_dt = datetime.fromisoformat(last)
                    tie = anchor_dt.date() == last_dt.date()
                    date_only = "T" not in anchor_raw or "T" not in last
                    newer = (anchor_dt.date() > last_dt.date()) if date_only else (anchor_dt > last_dt)
                    if not newer:
                        hint = (
                            " (add or adjust the time of day so the anchor is recorded after "
                            "the rejection)"
                        ) if tie else ""
                        errors.append(
                            f"{n} consecutive rejections and the anchor ({anchor_raw}) is not "
                            f"newer than the last rejection ({last}): go back to the recognition "
                            f"board, do not dispatch a third build{hint}"
                        )
                except (ValueError, TypeError) as e:
                    errors.append(f"invalid date value: {e}")

    for e in errors:
        print("BLOCKED:", e)
    if not errors:
        print("ok: brief carries what it needs and does not repeat a round blind")
    return 1 if errors else 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: python3 check_brief.py <brief.md>")
    sys.exit(main(sys.argv[1]))
