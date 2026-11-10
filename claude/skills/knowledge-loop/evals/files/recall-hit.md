# rag_query output for "what did we decide about the retry policy for webhook delivery" (top=5)

{"hit_count": 3, "results": [
 {"source": {"type": "memory", "repo": "orbit-api", "path": "memory/decision_webhook_retry_2026-08-12.md"},
  "score": 0.81,
  "text": "Decision: webhook delivery retries 5 times with exponential backoff (30s, 2m, 10m, 1h, 6h), then moves to dead-letter table. Rejected: infinite retry (hides broken customer endpoints)."},
 {"source": {"type": "handoff", "repo": "orbit-api", "path": "handoffs/orbit-api/2026-08-12.md"},
  "score": 0.64,
  "text": "Next: wire dead-letter table into the admin UI."},
 {"source": {"type": "commit", "repo": "orbit-api", "path": "b17f0de"}, "score": 0.52, "text": "chore: bump axios"}
]}

The user's question was a recall question only. They did not ask to capture anything.
