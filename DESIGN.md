# DESIGN.md: sharekit-profile guide page (`index.html`)

Locked via `/repaint` overhaul, 2026-10-06. Supersedes the 2026-08-04 "tightening" spec (dark + Geist + cyan),
which the owner replaced with a new direction. Owner anchor: [`docs/design/2026-10-06-owner-anchor.md`](docs/design/2026-10-06-owner-anchor.md).
Adopt these tokens verbatim; update this file, don't fork it.

## Register

**Hybrid: `docs` (primary) + `saas-landing` (hero only).** Unchanged. Only the hero (`#g-top`) gets
marketing treatment (headline + one CTA row). Every other section is `docs` register: no bento grids,
no repeated CTAs, no decorative motion. Catalog panels (Skills/Agents/Hooks/MCP/Plugins) are reference tables.

## Reference anchors (owner picks 2, 3, 4, 6)

- **Forge Kit (3)**: the token contract. Same OKLCH neutral ramp (hue 265), monochrome near-white
  primary, warm gold (hue 75) as the one accent. The guide and the catalog read as one family.
- **lucassantana.tech (2)**: the signature. Terminal windows (`$ claude` prompt, output, `✓` lines),
  IBM Plex Mono, status tables with a mono dot + label. Green is a status signal only.
- **Vercel docs (4)**: chrome and structure. Thin 1px borders, quiet top nav, sidebar density, no glow.
- **Linear changelog (6)**: rhythm. Large editorial H1 with tight tracking, section headings with a
  mono eyebrow, wide vertical whitespace between sections, content column ~720px for prose.

## Token spec

| Category | Token | Value |
|---|---|---|
| Color | `--bg` | `oklch(7% .004 265)` |
| | `--bg-elev` | `oklch(11% .004 265)` (cards, terminal body) |
| | `--bg-panel` | `oklch(15% .005 265)` (hover rows, inputs) |
| | `--fg` | `oklch(97% .003 265)` |
| | `--fg-muted` | `oklch(80% .007 265)` (body prose) |
| | `--fg-subtle` | `oklch(68% .006 265)` (meta, captions; ≥4.5:1 on `--bg`) |
| | `--border` | `oklch(100% 0 0 / .12)` |
| | `--border-strong` | `oklch(100% 0 0 / .24)` |
| | `--accent` | `oklch(80% .1 75)` warm gold: primary CTA fill, active nav marker, one key word in H1 |
| | `--accent-fg` | `oklch(18% .02 75)` (text on gold) |
| | `--ok` | `oklch(78% .15 150)` green: terminal `✓` and "live" status only |
| | semantic kinds | `--kind-skill oklch(75% .08 75)`, `--kind-agent oklch(72% .1 275)`, `--kind-hook oklch(73% .11 45)`, `--kind-server oklch(73% .09 185)`, `--kind-tool oklch(72% .09 145)`: category tags only |
| Type | display | Geist 600, H1 clamp(44px, 6vw, 76px), tracking -0.035em, leading 1.02 |
| | body | Geist 400, 16px, leading 1.6 |
| | mono | IBM Plex Mono 400/500: terminals, eyebrows (11-12px uppercase, tracking .08em), counts, code |
| Spacing | 4px base | 4 / 8 / 16 / 24 / 48 / 96 (96 only between top-level sections) |
| Radius | 3 values | 6px (chips, inputs, buttons), 10px (cards, terminal), 999px (status dot only) |
| Elevation | flat | 1px `--border`; no glow, no glass, no gradient fills. One shadow allowed: terminal window `0 18px 38px oklch(0% 0 0 / .4)` |
| Motion | 120 / 200ms | `ease-out`, color/border/opacity transitions only, named properties (never `transition: all`); honor `prefers-reduced-motion` |
| A11y | WCAG 2.2 | 4.5:1 text, 3:1 UI; `:focus-visible` 2px `--accent` outline, 2px offset; never `outline: none` without a replacement; targets ≥44px |

Weight contrast note: display 600 vs body 400 is below the generic ≥400 rule. The Linear anchor carries
hierarchy by size (76px vs 16px), so size contrast wins here by owner anchor.

## Layout

- Hero: mono eyebrow, H1 (one word in `--accent`), one-line lede, one CTA row (gold primary + ghost secondary),
  and a terminal window showing a real `$ claude` session beside or below it. The old 6-stat card grid becomes
  one mono status line (`50 skills · 9 composites · 39 agents ...`) inside or under the terminal.
- Sections: Linear changelog rhythm. Mono eyebrow + H2 left, content right or below; 96px between sections.
- Catalog panels: Vercel docs table density; kind tags use semantic kind colors as a small dot + mono label.

## Removed from the previous system

Cyan accent, violet/indigo gradients, glass surfaces, glow shadows, stat-card grid, emoji used as UI icons,
`transition: all`, bare `outline: none`.

## Open audit items carried into this build

- One `<h1>` in the accessible DOM at a time (EN/PT variants): the inactive language is `hidden`/removed, not just `display:none`.
- `<header>` landmark around the top nav; skip-to-main link first.
- SEO already added on `docs/guide-refresh-20261006` (OG, canonical, JSON-LD): keep it.
