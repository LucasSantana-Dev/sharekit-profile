# Scoring Model

Weighted 0–100 health score per platform, blended into one account score. Synthesized from claude-ads' weighted-check approach and NotFair's 7-dimension rubric — original weighting and wording, not copied verbatim.

## Dimensions (weight)

1. **Account structure** (15%) — campaign/ad-group hierarchy matches intent; no orphaned or overlapping campaigns; naming convention consistent.
2. **Targeting & audience** (15%) — audience overlap <20% across active campaigns; exclusions in place (branded terms, past converters where relevant); geo/device targeting matches business reality.
3. **Budget & bid health** (15%) — spend paced to budget (not over/under >15% by mid-period); bid strategy matches funnel stage; no campaigns limited-by-budget with headroom elsewhere.
4. **Creative health** (15%) — see `creative-fatigue.md`; diversity across active creatives; no single creative >50% of a campaign's spend without a fatigue check.
5. **Tracking & measurement** (15%) — conversion tracking verified firing (not just "installed"); server-side/CAPI where the platform supports it; attribution window matches sales cycle.
6. **Performance vs. goal** (15%) — CPA/ROAS/MER against the stated target from business-context preflight; trend direction (7d vs. 28d) not just point-in-time.
7. **Learning-phase & experimentation** (10%) — campaigns not stuck in learning-phase churn (frequent edits resetting learning); active test roadmap or explicit "no test running" acknowledgment.

Score = weighted sum of per-dimension 0–100 sub-scores. Blended account score = spend-weighted average across connected platforms (a platform with 5% of spend shouldn't move the blended score as much as one with 60%).

## Severity tiers

- **Critical** — actively wasting spend or blocking measurement (tracking broken, budget capped mid-funnel, duplicate/competing campaigns). Fix this week.
- **High** — meaningfully underperforming vs. stated goal or a structural risk (audience overlap >40%, single creative carrying a campaign). Fix this month.
- **Medium** — inefficiency without immediate risk (naming drift, mild overlap, stale-but-not-fatigued creative). Fix when convenient.
- **Low** — polish/hygiene (labeling, minor budget imbalance <10%). Backlog.

## Reporting the score

Always show: per-dimension sub-score, weight, and the specific evidence that produced it — never a bare number. A dimension with no data available is `insufficient-data`, not a guessed midpoint (e.g., 50).
