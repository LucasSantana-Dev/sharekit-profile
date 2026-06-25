# Performance & Cost Skills

`token-audit` for a weekly spend review. `smart-model-select` before starting a long or expensive task. `mac-optimize` when Claude Code feels slow or the machine is under pressure. `rate-limit-watch` fires automatically — no manual invoke needed.

---

## /mac-optimize

Diagnose and fix macOS resource pressure for Claude Code workflows — CPU, swap, zombie processes, Node heap.

**Diagnoses:**
- CPU usage (high CPU = expensive operations)
- Memory pressure (swap usage indicates memory pressure)
- Zombie processes (hanging Node processes)
- Node heap size (memory leaks)

**Fixes:**
- Restart Claude Code
- Kill zombie processes
- Clear Node cache
- Optimize context usage

**When to use:** Claude Code feels sluggish or hangs

**Output:** Diagnostics + suggested fixes

---

## /performance-audit

Audit MCP Gateway performance across system health, routing, caching, and latency.

**Metrics:**
- Request latency (p50, p95, p99)
- Cache hit rates
- Routing efficiency
- System resource usage

**When to use:** MCP performance tuning; slow requests

**Output:** Performance audit report

---

## /token-audit

Analyze historical Claude Code token usage from session JSONL files — spend, cache hit rates, weekly trends.

**Metrics:**
- Tokens spent per session
- Cache hit rates
- Trends (increasing? decreasing?)
- Cost estimate
- Top token-burning sessions

**When to use:** Weekly spend review; optimize budget

**Output:** Token usage report + trends

---

## /adt-cost

Track and report token usage and estimated cost per session, agent, and phase.

**Reports:**
- Session cost breakdown
- Agent cost ranking (which agents most expensive?)
- Phase cost (which phase spent most?)
- Budget tracking (vs. allocation)

**When to use:** Cost accounting + budget tracking

**Output:** Cost report + recommendations

---

## /insights

Generate a productivity or usage insights report for Claude Code sessions.

**Insights:**
- Tasks completed per week
- Avg session length + duration
- Skills used most frequently
- Agents used most frequently
- Blockers + stuck patterns

**When to use:** Productivity self-assessment; identify improvement areas

**Output:** Insights report

---

## /metrics

Show concrete productivity metrics and session analytics — tokens, tasks, time, and PR throughput.

**Metrics:**
- PR throughput (PRs merged per week)
- Session frequency (sessions per week)
- Task completion rate
- Token efficiency (tokens per task)
- Blockers resolved vs. created

**When to use:** Measuring productivity over time

**Output:** Metrics dashboard + trends

---

## /rate-limit-watch

Track Anthropic API rate limit headers in real time and warn when approaching the limit.

**Auto-fires:** Runs automatically during session (no manual invoke needed)

**Warns when:**
- Approaching request rate limit
- Approaching token rate limit
- Budget exhausted

**Output:** Real-time rate limit alerts

---

## /smart-commands

Decision guide for when to proactively use Claude Code slash commands — /think, /model, /compact, /clear.

**Commands:**
- **/think** — Extended thinking for complex reasoning
- **/model** — Override model tier (use sparingly)
- **/compact** — Compress context (saves ~30-40% tokens)
- **/clear** — Clear session history

**When to use:** Understanding when to use advanced commands

**Output:** Command decision guide

---

**Last updated:** 2026-06-25
