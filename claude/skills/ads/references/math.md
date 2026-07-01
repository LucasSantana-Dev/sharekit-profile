# PPC Math

Standard formulas for `budget`/`math` mode. Always show the formula and the exact inputs used — a metric without its inputs is not usable output.

## Core formulas

- **CPA (Cost Per Acquisition)** = Total Spend ÷ Conversions
- **ROAS (Return on Ad Spend)** = Revenue Attributed ÷ Total Spend (unitless ratio, e.g., 4.2 = $4.20 back per $1 spent)
- **MER (Marketing Efficiency Ratio / blended ROAS)** = Total Revenue (all channels) ÷ Total Ad Spend (all channels) — use when attribution is fragmented across platforms and per-platform ROAS double-counts
- **LTV:CAC** = Customer Lifetime Value ÷ Customer Acquisition Cost — healthy is generally ≥3:1; <1:1 means acquisition costs exceed lifetime return
- **Break-even ROAS** = 1 ÷ Gross Margin % (e.g., 40% margin → break-even ROAS is 2.5)
- **Break-even CPA** = Average Order Value × Gross Margin %
- **CPM (Cost Per Mille)** = (Spend ÷ Impressions) × 1000
- **CPC (Cost Per Click)** = Spend ÷ Clicks
- **CTR (Click-Through Rate)** = (Clicks ÷ Impressions) × 100
- **CVR (Conversion Rate)** = (Conversions ÷ Clicks) × 100

## Budget-scaling caps

Bid/budget scaling review should recommend changes within safe percent-change caps, not arbitrary jumps — large single-step changes reset learning phase (Google/Meta both re-enter learning above certain change thresholds):

- **Budget increases:** cap at +20–30% per change, spaced ≥3-5 days apart, to avoid learning-phase reset and let the algorithm re-stabilize.
- **Budget decreases:** less risky for learning phase but still cap at -20% per change if the goal is to avoid destabilizing delivery pacing.
- **Bid changes (manual bidding):** cap at ±15-20% per change; larger swings warrant a new campaign/ad-set rather than an edit to a learning one.
- **Frequency of edits:** avoid daily bid/budget edits on the same campaign — each edit can reset or extend learning phase; batch changes on a weekly cadence unless there's a clear crisis (tracking broken, budget exhausted mid-day).

## When math alone isn't enough

If CPA/ROAS look fine in isolation but MER is declining, the issue is likely cross-channel attribution overlap (two platforms claiming the same conversion) — flag this as a measurement issue, not a performance issue, and route to the tracking dimension in `scoring.md` rather than recommending a budget cut.
