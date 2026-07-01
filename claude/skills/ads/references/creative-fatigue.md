# Creative Fatigue Detection

Goal: catch fatigue *before* CTR drops, not after — the ColdIQ ad-ops pattern this skill borrows from treats fatigue as a leading-indicator problem, not a post-mortem.

## Signals (check all available; report insufficient-data for any missing)

1. **Frequency** — average impressions per unique user over the lookback window (7d and 28d). Platform-reported "frequency" metric where available (Meta/LinkedIn expose it directly; TikTok/Google require impressions ÷ reach approximation).
2. **Days-live** — how long the current creative has been running unchanged. A creative can be low-frequency but stale if it's been live for months in a small audience.
3. **CTR trend** — CTR over the last 3 periods (e.g., week-over-week for 3 weeks), not a single snapshot. A flat or declining trend against stable spend is the actual signal; a single bad day is noise.
4. **Diversity-similarity** — how visually/textually similar the active creative set is (same template, same hook, same color palette repeated). Low diversity means the whole set fatigues together.

## Thresholds (starting points — recalibrate per account/industry, cite when overridden)

| Signal | Fresh | Watch | Fatigued |
|---|---|---|---|
| Frequency (7d) | <2.5 | 2.5–4 | >4 (Meta/LinkedIn); >3 (TikTok — fatigues faster) |
| Days-live (no refresh) | <14 days | 14–30 days | >30 days |
| CTR trend (3-period) | flat or rising | -1 to -15% per period | >-15% per period, 2+ consecutive periods |
| Diversity-similarity | ≥3 distinct concepts active | 2 distinct concepts | 1 concept, multiple crops/variants only |

## Verdict rule

- **Fresh** — no signal in Watch/Fatigued range.
- **Watch** — 1 signal in Watch range, none in Fatigued.
- **Fatigued** — ≥1 signal in Fatigued range, OR ≥2 signals in Watch range simultaneously.
- **Insufficient-data** — fewer than 2 of the 4 signals available (e.g., no CTR history, no frequency exposed). Never guess a verdict from partial data; say what's missing.

Always cite the specific numbers behind a verdict (e.g., "frequency 4.8 over 7d, CTR down 22% over 3 weeks → fatigued") — a verdict without cited evidence is a Stop/Failure condition per SKILL.md.

## Kill / refresh rule

When a creative crosses into Fatigued: recommend refresh (new hook/visual, not just re-uploading the same asset) or pause, prioritized by spend share — a fatigued creative carrying <10% of ad-set spend is lower priority than one carrying >50%.
