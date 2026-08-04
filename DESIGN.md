# DESIGN.md — sharekit-profile landing/guide page (`index.html`)

Locked via `/repaint` full pipeline, 2026-08-04. This file is the source of truth for
`index.html`'s design decisions — do not invent a competing palette or type system;
adopt these tokens verbatim. Update this file, don't fork it, if tokens change later.

## Register

**Hybrid: `docs` (primary) + `saas-landing` (hero only).** This is a developer guide/reference
site (`#g-guide` panel: install, quickstart, core concepts, hard rules — classic `docs` content)
fronted by one marketing hero that has to convince a skeptical dev-tool audience to install.
The catalog panels (Skills/Agents/Hooks/MCP/Plugins) are `docs`-register reference tables.

Rule: only the hero (`#g-top`) gets marketing treatment (headline + one CTA row). Every other
section is `docs` register — no bento grids, no repeated marketing CTAs, no decorative motion.

## Reference anchors

- **Vercel** — Geist/Geist Mono type (already in use, correct choice — keep), blueprint-grid
  rigor, monochrome-with-one-accent restraint. Primary anchor for the hero and overall rhythm.
- **Linear** — sidebar density (`.g-sidebar`, already Linear-anchored: 36px-ish row height,
  status-pill category filters), command-palette-adjacent search-first catalog interaction.
- **Stripe docs** — code-as-marketing quickstart blocks (`$ claude` → output → `✓ session ready`)
  are already this pattern; keep, tighten the copy around them.
- **GOV.UK content-first** — for the `docs`-register sections: one thing per section, no
  decorative filler, direct language over marketing adjectives.

## Token spec (mostly already correct — confirm and tighten, don't replace)

| Category | Value | Note |
|---|---|---|
| Type | Geist (300-700), Geist Mono (400-600) | Already correct — Vercel's own face, not Inter. Keep. |
| Color bg/surface | `#09090b` / `#111113` / `#18181b` | Tinted dark neutrals, not pure black. Keep. |
| Color accent | `--cyan: #22d3ee` | Single primary accent — keep as the ONE carried hue. |
| Color secondary hues | `--violet #a78bfa`, `--blue #60a5fa`, `--green #4ade80`, `--amber #fbbf24`, `--red #f87171`, `--pink #f472b6` | Keep as **semantic-only** (category tags, status colors) — never combined with cyan in a single gradient (see finding below). |
| Radius | `8px` / `5px` | Keep. |
| Spacing | 4/8/16/24/32/48px scale | Keep. |
| Motion | `0.1s` / `0.15s` / `0.2s` | Keep — already short/functional, not decorative. |
| Accessibility | WCAG 2.2, 4.5:1 body / 3:1 UI, focus ring ≥2px | Audit and fix gaps (see findings). |
| SEO | Public register (whole page is public/discoverable) | Currently near-zero — see findings. |

## Findings from the pre-build audit (fix these — this is most of the value of this pass)

1. **Hero H1 gradient text is the N9 purple-gradient tell**, line ~565:
   `background: linear-gradient(125deg, #fafafa 25%, #a78bfa 55%, #22d3ee 100%)` — violet→cyan
   text gradient on the flagship headline. Rewrite to solid `var(--text)` with the accent carried
   by one word or the badge above it instead, not a rainbow gradient across the whole H1.
2. Small badge/icon element, line ~78: `linear-gradient(135deg, #6366f1 0%, #22d3ee 100%)` —
   indigo→cyan, same family. Simplify to a solid accent fill.
3. **SEO is nearly absent** for a public discoverability-focused page: no Open Graph tags, no
   Twitter card, no canonical link, no JSON-LD (SoftwareApplication or WebSite would fit). Title
   and meta description exist and are fine. Add OG + canonical + JSON-LD — this is the single
   highest-value fix for the stated goal (Claude Code tag / discoverability).
4. Multiple cyan-tinted "glow" box-shadows (lines ~649, 675, 702, 240) — audit under the
   subtraction test; keep at most one signature glow moment (e.g. the primary CTA hover), flatten
   the rest to the existing flat elevation system.
5. No `<header>`/`<footer>` landmark elements confirmed missing — verify and add if the footer
   content (`<!-- FOOTER -->`, ~line 1124) isn't already wrapped in a real `<footer>`.
6. `<h1>` count = 2 in source (one per language variant) — verify only one is ever in the
   accessible DOM at a time (not just `display:none`, which axe still flags); prefer removing the
   inactive language's `<h1>` from the DOM entirely when hidden, or use `aria-hidden` correctly.
7. `#g-guide` section copy density: Mental Model / Core Concepts / I Want To / Hard Rules read as
   dense prose blocks. Apply GOV.UK content-first: tighten to essential sentences, use the
   existing step/card components for scannability instead of paragraph walls where it fits.

## Direction

No new visual direction — the existing dark + Geist + cyan system is already a legitimate
Vercel/Linear-anchored dev-tooling identity. This pass is a **tightening and completion** pass:
kill the two gradient tells, add real SEO metadata, reduce shadow/glow overuse, and tighten
guide-section copy density. Do not introduce new colors, new fonts, or a new layout system.
