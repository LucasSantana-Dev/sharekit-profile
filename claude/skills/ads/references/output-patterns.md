# Output Patterns

Signal-first templates per mode. Verdict + top-3 findings lead; remaining findings gated behind "ask for full list" per the repo's signal-first rule.

## `audit` template

```
ADS AUDIT — <account/client name>
Blended score: <0-100> (<verdict: HEALTHY ≥80 | NEEDS WORK 60-79 | AT RISK <60>)

Google: <score>/100 | Meta: <score>/100 | LinkedIn: <score>/100 | TikTok: <score>/100

Top findings:
1. [CRITICAL] <finding> — <evidence> — <fix>
2. [HIGH] <finding> — <evidence> — <fix>
3. [HIGH] <finding> — <evidence> — <fix>

Quick wins (do this week):
- <win 1, expected impact>
- <win 2, expected impact>
- <win 3, expected impact>

N more findings — ask for full list.
```

## `creative` template

```
CREATIVE FATIGUE — <account/campaign>

Fatigued (act now):
- <ad/ad-set name>: frequency <X> (7d), CTR down <Y>% (3-period), days-live <Z> → refresh/pause, <spend share>% of budget

Watch:
- <ad/ad-set name>: <signal in watch range>

Fresh: <count> ads, no action needed.
Insufficient data: <count> ads — missing <which signal>.
```

## `budget`/`math` template

```
BUDGET & MATH REVIEW — <account>

CPA: $<x> (target $<y>) | ROAS: <x> (target <y>) | MER: <x> | LTV:CAC: <x>:1

Scaling recommendation: <+/-N%> on <campaign>, within cap (see math.md), spaced <N> days
Formula basis: <formula used> = <inputs>
```

## `competitor` template

```
COMPETITOR AD SCAN — <account> vs. <competitor(s)>

<Competitor name>: running <N> active ads, angle = "<observed positioning>", gap vs. our account: <specific gap>
```

## `plan` template

```
PAID MEDIA PLAN — <account>

Goal: <stated goal from business-context preflight>
Channel mix: <platforms + rationale>
Budget split: <%/platform>
Test roadmap: <test 1 → success criteria>, <test 2 → success criteria>
```

## `report` (stakeholder handoff)

Condense whichever mode ran most recently into this shape — verdict first, methodology last:

```
<Client/account> — Ad Performance Report — <date range>

Verdict: <one line>
Key numbers: <2-4 metrics with formula/source>
What changed: <if this is a follow-up report>
Recommended next steps: <top 3, ranked>

Methodology: <which mode/checklist was used, what data tier (manual/MCP)>
```
