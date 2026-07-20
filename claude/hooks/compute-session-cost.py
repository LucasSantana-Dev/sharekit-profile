#!/usr/bin/env python3
"""
Compute session cost from JSONL log.
Reads lines from JSONL file path passed as argument.
Outputs formatted cost string: $X.XX or Xc
"""

import sys
import json


def compute_cost(jsonl_path):
    """Parse JSONL and compute total session cost."""
    total_cost = 0.0

    try:
        with open(jsonl_path, "r") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                    # Extract cost from entry if present
                    if "cost" in entry and entry["cost"] is not None:
                        total_cost += float(entry["cost"])
                except (json.JSONDecodeError, ValueError, TypeError):
                    continue
    except (IOError, OSError):
        return ""

    # Format: $X.XX if >= $1, otherwise Xc (cents)
    if total_cost >= 1.0:
        return f"${total_cost:.2f}"
    else:
        cents = int(total_cost * 100)
        return f"{cents}c" if cents > 0 else ""


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(1)

    result = compute_cost(sys.argv[1])
    if result:
        print(result, end="")
