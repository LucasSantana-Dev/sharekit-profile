# rag_query output for "why did we choose D1 for the Progress Tracker storage" (top=8)

{"results": [
 {"source": {"type": "memory", "repo": "Orbit", "path": "memory/decision_progress_tracker_d1.md"}, "score": 0.89,
  "text": "Chose Cloudflare D1 over KV for Progress Tracker: needs relational queries (per-user streak joins) and D1 is free at our volume. KV rejected: no secondary indexes."},
 {"source": {"type": "plan", "repo": "Orbit", "path": "docs/plans/progress-tracker.md"}, "score": 0.78,
  "text": "Storage: D1. Tables: users, streaks, events. Migration via wrangler d1 migrations."},
 {"source": {"type": "readme", "repo": "atlas", "path": "README.md"}, "score": 0.58,
  "text": "Atlas uses SQLite for the dashboard."},
 {"source": {"type": "code", "repo": "Orbit", "path": "src/utils/time.ts"}, "score": 0.41,
  "text": "export const nowIso = () => new Date().toISOString();"},
 {"source": {"type": "commit", "repo": "Orbit", "path": "9be1c02"}, "score": 0.33,
  "text": "fix: typo"}
]}
Note: index last rebuilt 4 minutes ago.
