---
name: example-fact
description: One-line summary used to decide relevance during recall
metadata:
  type: project
  # Staleness fields (see SELF_IMPROVEMENT.md §2). Required for T3+ facts.
  last_verified: 2026-06-29     # date a named file/flag was confirmed to still exist
  change_frequency: low          # low | medium | high — how often the underlying truth shifts
  confidence: 0.8                # 0.0-1.0 — evidence strength (auto: 0.7+ promotes)
---

The fact itself, stated plainly. Keep one fact per file.

**Why:** the reasoning behind it (especially for `feedback` and `project` types).

**How to apply:** what to do differently because of this.

Link related memories like [[another-fact-slug]] — liberally; a link to a not-yet-written memory marks something worth capturing later.
