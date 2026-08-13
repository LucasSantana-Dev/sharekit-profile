# Platform Playbook

URL patterns, query recipes, and quality heuristics per platform. One level deep from
SKILL.md; do not nest further.

## Primary platforms

### Mobbin — real shipped product UI (strongest anti-slop signal)

- URL patterns: `https://mobbin.com/search/{web|ios|android}?q=<query>` · browse by app:
  `https://mobbin.com/apps` · by pattern: `https://mobbin.com/patterns`
- Auth: most content behind login; drive the user's Chrome session. Free tier caps results;
  if walled mid-hunt, mark `coverage: partial`.
- Query recipes: search by PATTERN not adjective — "onboarding", "empty state", "pricing",
  "data table", "settings", app-name of a register anchor ("Linear", "Notion", "Arc").
- Quality heuristic: everything here shipped, so the gate is fit, not credibility. Prefer
  apps in the same register family as the brief. Screenshot flows, not single frames, when
  the brief is UX (2–4 consecutive screens).

### Dribbble — visual direction and concept polish

- URL patterns: `https://dribbble.com/search/<query>` · filters: append `?timeframe=year`
  (recency gate). Tags: `https://dribbble.com/tags/<tag>`
- Auth: public browsing works logged out.
- Query recipes: adjective + surface ("brutalist dashboard", "editorial landing page",
  "fintech mobile app dark"), or technique ("kinetic typography", "bento grid").
- Quality heuristics: concept work; most shots are unbuildable or ignore real content
  density. Steal: type pairings, palette moods, composition. Distrust: information
  architecture, data density, feasibility. Reject shots that are themselves AI-generated
  (uncanny mock content, melted icons, nonsense labels).

### Pinterest — moodboard breadth, typography, palettes

- URL pattern: `https://www.pinterest.com/search/pins/?q=<query>`
- Auth: logged-in session gives far better results; logged-out walls quickly.
- Query recipes: "web design inspiration <register>", "typography pairing <mood>",
  "color palette <mood>", "<industry> website design".
- Quality heuristics: high noise, high serendipity. Use for mood/type/palette only, never
  UX. Always click through to the original source; pin metadata rots and many pins are
  reuploads with dead provenance.

## Secondary galleries (route by goal)

| Goal | Gallery | URL |
|---|---|---|
| Immersive motion, award-grade | Awwwards | `awwwards.com/websites/<tag>/` |
| Immersive motion, curated small | Godly | `godly.website` |
| Immersive motion, curated small | appmotion.design | `appmotion.design` |
| Immersive motion, curated small | 60fps.design | `60fps.design` |
| Landing pages, SaaS | Land-book | `land-book.com` |
| Landing pages, SaaS | SaaS Landing Page | `saaslandingpage.com` |
| Landing pages, SaaS | purelanding.page | `purelanding.page` |
| Landing pages, SaaS | saaspo.com | `saaspo.com` |
| Editorial / typographic | siteinspire | `siteinspire.com` |
| Web design, broad sweep | curated.design | `curated.design` |
| Minimal / quiet register | minimal.gallery | `minimal.gallery` |
| Broad creative work (not web-specific) | Behance | `behance.net` |
| Component-level React | 21st.dev | `21st.dev` |
| Component-level React | ui.aceternity.com | `ui.aceternity.com` |
| Footers/navs (detail studies) | footer.design | `footer.design` |
| Navbars (component detail) | navbar.gallery | `navbar.gallery` |
| CTA sections (component detail) | cta.gallery | `cta.gallery` |
| Bento grids (component detail) | bentogrids.com | `bentogrids.com` |
| OG/share images (component detail) | ogimage.gallery | `ogimage.gallery` |
| Design systems, cross-company patterns | component.gallery | `component.gallery` |
| Brand / rebrand case studies | rebrand.gallery | `rebrand.gallery` |
| Fonts, type pairing | uncut.wtf | `uncut.wtf` |
| Icons | hugeicons.com | `hugeicons.com` |
| Portfolio sites | prettyfolio.com | `prettyfolio.com` |
| Email design | reallygoodemails.com | `reallygoodemails.com` |
| AI-friendly stock imagery | lummi.ai | `lummi.ai` |
| UX flow maps | uxmaps.co | `uxmaps.co` |
| AI-agent design-doc format ref (not visual) | styles.refero.design | `styles.refero.design` |

Awwwards/Godly/appmotion.design/60fps.design sites are live: open them, scroll, and record
actual motion behavior (what animates on load, on scroll, on hover) instead of trusting
thumbnails. `styles.refero.design` is a format reference (how to write a DESIGN.md for an
AI agent), not a visual gallery — read it for structure, don't screenshot it into the board.

## Query widening ladder (when <5 usable references)

1. Swap adjective synonyms (premium → refined, editorial, understated).
2. Search the register anchor's competitors by name.
3. Drop the industry qualifier, keep the surface type.
4. Add one more secondary gallery.
Only after all four: relax the recency gate. Never relax the slop-cluster gate.

## Motion archetype naming

Name motion observations using the archetype vocabulary in `repaint`'s reference library
(scroll-driven narrative, magnetic cursor, reveal/masking, kinetic type, parallax depth,
orchestrated load — absorbed from the retired `premium-frontend-ui` skill, 2026-07-16).
Shared vocabulary is what lets build skills consume the board without re-watching the sites.
