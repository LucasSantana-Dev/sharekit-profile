# Platform Checklists

Condensed per-platform checks feeding the `references/scoring.md` dimensions. Concepts synthesized from claude-ads' 250+-check catalog and current platform documentation — original wording, not a copy of any source's proprietary check list. Treat as a starting checklist, not exhaustive; note anything the account uses that isn't listed here rather than skipping it.

## Google Ads

- **Search:** match-type mix (avoid broad-only without smart bidding + strong negatives); search-term report reviewed in last 30 days; negative-keyword list attached at the right level (campaign vs. shared list); quality score components (ad relevance, landing page experience) not systematically "below average."
- **Performance Max (PMax):** asset group diversity (≥3 headlines/descriptions varied, not near-duplicate); listing group / product feed health if e-commerce; search-term insights checked (PMax hides queries by default — insights report is the workaround); brand exclusion applied if cannibalizing Search.
- **Demand Gen:** creative refresh cadence; audience signal quality (first-party data or lookalike, not just "broad"); placement mix (not 100% on one surface by default).
- **Cross-campaign:** auto-applied recommendations reviewed (not blindly accepted); conversion actions deduped (not double-counting a primary + secondary action as separate conversions); attribution model matches sales cycle length.

## Meta (Facebook/Instagram)

- **Pixel + CAPI:** Pixel firing verified via Events Manager test tool (not just "installed"); Conversions API (CAPI) deployed for at least the primary conversion event to offset iOS/browser signal loss; event match quality score checked, not assumed high.
- **Advantage+ / Andromeda-era targeting:** audience broadening tested deliberately (not accidental from over-narrow exclusions); Advantage+ shopping/App campaigns given enough creative diversity to let the algorithm work (Andromeda favors creative variety over manual audience slicing).
- **Creative diversity:** ≥3 meaningfully distinct creative concepts per active ad set (not 3 crops of the same asset); UGC/native-style creative present alongside polished brand creative where relevant.
- **Placement & delivery:** Advantage+ placements used unless there's a documented reason to restrict; frequency capped or monitored (see `creative-fatigue.md`).

## LinkedIn

- **Campaign structure:** objective matches funnel stage (awareness ≠ conversion campaign structure); campaign groups used to organize by initiative, not ad-hoc.
- **Audience overlap:** overlapping audiences across active campaigns checked via Campaign Manager's audience overlap report; overlap >30% flagged.
- **Bid strategy:** manual vs. automated bidding matches budget size (automated bidding needs enough daily budget/volume to learn); CPL/CPC sanity-checked against B2B benchmarks for the industry.
- **Creative:** document ads / conversation ads / video used where format fits the offer, not defaulting to single-image for every campaign.

## TikTok

- **Smart+ campaigns:** enough creative volume fed in for Smart+ to optimize (starving it with 1-2 assets undermines the automation); conversion event setup verified via Events Manager.
- **Creative-first checks:** hook quality in first 1-3 seconds; native/vertical format (not repurposed square/horizontal creative); trending-audio or platform-native editing patterns used where relevant to the brand.
- **Audience & placement:** Automatic Placement vs. TikTok-only compared if Pangle/News Feed placements are enabled; Spark Ads (boosted organic) considered alongside standard in-feed ads.
- **Frequency & fatigue:** TikTok fatigues creative faster than other platforms — check `creative-fatigue.md` thresholds specifically calibrated tighter for TikTok.

## Not covered

If the account uses a platform not listed here (Pinterest, Snap, Reddit Ads, X/Twitter Ads, programmatic/DSP), say so explicitly in the audit output rather than improvising checks — flag it as "not covered by this skill's checklist" and audit only structure/tracking/budget generically if data is available.
