# Deferred marketplaces (reference only — NOT auto-loaded)

Third-party skill/plugin sources evaluated and intentionally NOT added to active
`extraKnownMarketplaces`. Grep here if a pull signal fires; do not bulk-install.

| Marketplace | Evaluated | Outcome | Only candidate | Re-eval trigger |
|-------------|-----------|---------|----------------|-----------------|
| `alirezarezvani/claude-skills` | 2026-05-28 | Install nothing — mostly dupes/poor-fit vs mature catalog | `playwright-pro` (skills-only, drop hooks/MCP/BrowserStack/TestRail) | First Playwright e2e test committed to any repo |

Decision record: `decisions/2026-05-28-marketplace-skill-adoption.md`.
Rejected outright: `self-improving-agent` (dup + third-party hooks), bulk domain installs (bloat).
