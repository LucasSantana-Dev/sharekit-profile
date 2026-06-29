---
name: token-audit
description: Analyze historical Claude Code token usage from session JSONL files. Shows total spend, cache hit rates, top costly sessions, weekly trends, and recommendations. Use when you want to understand where tokens are going or measure optimization progress.
argument-hint: "[--days N | --today | --session ID | --json]"
triggers:
  - token audit
  - token usage report
  - how many tokens
  - cache hit rate
  - session cost
  - token spend
---

# token-audit

Run the token usage audit script against all local session files.

## Usage

```bash
python3 ~/.claude/skills/token-audit/audit.py              # last 30 days
python3 ~/.claude/skills/token-audit/audit.py --days 7     # last 7 days
python3 ~/.claude/skills/token-audit/audit.py --today      # today only
python3 ~/.claude/skills/token-audit/audit.py --session ID # single session
python3 ~/.claude/skills/token-audit/audit.py --json       # JSON output
```

## What it reports

- Total sessions, turns, input/output/cache tokens
- Cache hit rate (cache_read / total cache activity)
- Net cost estimate (Sonnet/Haiku/Opus pricing)
- Cache savings vs no-cache baseline
- Top 10 sessions by cost
- Weekly trend (last 8 weeks)
- Guidance if cache hit rate is below target (60%)

## Interpreting results

| Cache hit rate | Status |
|---------------|--------|
| < 40% | Many cold starts — use `/context-pack` before new tasks |
| 40–60% | OK but improvable — compact at task boundaries |
| ≥ 60% | Healthy |

## Execute

Run: `python3 ~/.claude/skills/token-audit/audit.py $ARGUMENTS`
