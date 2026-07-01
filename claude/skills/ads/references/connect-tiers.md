# Data Connection Tiers

Three tiers, cheapest-first — mirrors claude-ads' tiered data-connection pattern. This skill never installs or assumes a paid integration; it always works at Tier 1.

## Tier 1 — Manual (always free, always works)

User pastes exported data: CSV/XLSX export from the ad platform, a screenshot of the dashboard, or a copy-pasted report table. No setup required. This is the default assumption for every mode in `SKILL.md` unless a connected source is confirmed present.

Ask for exactly what a mode needs (e.g., `creative` mode needs frequency + CTR history + days-live per creative — ask for those columns specifically, not "send me everything").

## Tier 2 — Community / self-hosted adapter (opt-in, free/low-cost)

A community-maintained MCP server or self-hosted API adapter for the platform. If the user has one configured and connected, use it via its tools instead of asking for manual paste. Check `ToolSearch`/MCP server list for a platform-specific server before assuming Tier 1 is the only option.

Do not suggest installing a new Tier 2 server mid-audit — flag it as a follow-up ("connecting a Google Ads MCP would let future audits skip manual export") rather than pausing the current task to set one up.

### Named options (verified against GitHub API, as of 2026-07-01 — reverify before hard-relying on any of these; the MCP ecosystem for ad platforms is new and moves fast)

| Platform | Option | Scope | Auth | License | Last push | Confidence |
|---|---|---|---|---|---|---|
| Google Ads | **This ecosystem's own `google-ads-mcp`** (`/Volumes/External HD/Desenvolvimento/google-ads-mcp`) | 31 tools, read+write, ±20-25% change caps, allowlist/preview/audit-log gates | OAuth2 desktop app + developer token | — (local) | 2026-06-26 | **High — prefer this over any external option** |
| Google Ads | [googleads/google-ads-mcp](https://github.com/googleads/google-ads-mcp) — Google's own official server | 3 tools, **read-only** (`list_accessible_customers`, `search`/GAQL, `get_resource_metadata`) | OAuth2 or service account | Apache-2.0 | 2026-06-30 | High (official, confirmed via developers.google.com) |
| Google Ads | [cohnen/mcp-google-ads](https://github.com/cohnen/mcp-google-ads) | ~5 GAQL tools, read-only | OAuth2 + service account | MIT | **2025-10-16 — stale, ~8.5mo old** | Medium — verify it still works before recommending |
| Meta Ads | [mikusnuz/meta-ads-mcp](https://github.com/mikusnuz/meta-ads-mcp) | Full read/write, Marketing API v25.0 | System user / OAuth token | MIT | 2026-04-12 | High |
| Meta Ads | [pipeboard-co/meta-ads-mcp](https://github.com/pipeboard-co/meta-ads-mcp) | Read+write with safety guards (writes require confirmation, new campaigns default paused) | Meta Business OAuth | Custom (shows as `NOASSERTION` on GitHub — read the repo's LICENSE file directly, don't assume terms) | 2026-07-01 | High (1,037★, actively developed) |
| Meta Ads (competitor mode only) | [RamsesAguirre777/facebook-ads-library-mcp](https://github.com/RamsesAguirre777/facebook-ads-library-mcp) | Read-only, public Ad Library (political/social-issue ads only per Meta's API scope) | `ads_read` token, identity verification (~1-2wk approval) | MIT | unverified | Medium |
| LinkedIn Ads | [danielpopamd/linkedin-ads-mcp](https://github.com/danielpopamd/linkedin-ads-mcp) | 25 tools, full read/write | OAuth2 (requires LinkedIn Marketing API partner approval — **unpredictable timeline, can take weeks/months**) | MIT | 2026-03-06 | Medium — best available, but LinkedIn API access itself is the bottleneck, not the MCP |
| LinkedIn Ads | [CDataSoftware/linkedin-ads-mcp-server-by-cdata](https://github.com/CDataSoftware/linkedin-ads-mcp-server-by-cdata) | Read-only, SQL-relational view via JDBC | CData driver + LinkedIn creds | MIT | unverified | Medium |
| TikTok Ads | [AdsMCP/tiktok-ads-mcp-server](https://github.com/AdsMCP/tiktok-ads-mcp-server) | Campaign mgmt + analytics, read/write | OAuth2 (requires verified TikTok **Business Account**, 3-7 day app approval typical) | MIT | 2026-06-21 | High |
| Multi-platform | [amekala/ads-mcp](https://github.com/amekala/ads-mcp) | Google+Meta+LinkedIn+TikTok, 100+ tools combined | Per-platform | unverified | unverified | Medium — one-stop option if you don't want 4 separate servers |

**Not yet real / don't recommend installing today:** Meta announced an official hosted MCP (`mcp.facebook.com/ads`, ~29 tools) and TikTok announced one at TikTok World '26 — both surfaced by research but **not independently verified by direct fetch**; TikTok's was explicitly reported as "not yet GA." Treat as "coming soon," not as a Tier-2 option to configure now.

**Platforms outside this skill's checklist scope (Google/Meta/LinkedIn/TikTok) with their own official/community MCP options, if a future audit needs them:** Amazon Ads/DSP (official, open beta), Pinterest Ads (official, read-only), Snap Ads (official), Reddit Ads (Synter, Pipeboard), Microsoft Ads (official, read-only). None of these are checklisted in `platform-checks.md` — if a user needs one, say so explicitly and treat it as a scope-expansion request, not something to audit ad hoc.

## Tier 3 — Paid SaaS integration (never auto-installed)

Commercial ad-management/reporting platforms (e.g., paid dashboarding tools) may already be in the user's stack. If so, treat their exports/API the same as Tier 2 — use what's connected. This skill never recommends purchasing or installing a paid SaaS integration as part of a normal audit; that decision belongs to the user, not this skill.

## Precedence

Prefer whatever is already connected (Tier 2/3) over asking the user to manually paste (Tier 1). But never block on "let's set up an integration first" — if nothing is connected, proceed at Tier 1 immediately.
