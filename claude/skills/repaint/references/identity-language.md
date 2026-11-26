# Identity language: the client's own world, not a borrowed look

Backs Gate 1, the identity rows of the slop audit, and the identity checks in Browser
verification. Gate 1 reads §1-§2; §3-§5 only when the medium has its own grammar; §7 at Browser verification.

Origin: a 2026 design canvas for a volunteer community inside a pixel-art game. The owner judged it the best frontend the project had shipped: every page "screams
identity" and nothing reads as AI output. Copy the method and the rules, never the look
(a Soviet space-race poster language only fits that client).

## 1. Find the identity source (Gate 1)

The identity comes from four places, in this order. An industry anchor (Linear, Stripe)
is never one of them; it governs structure and interaction quality only.

1. **The owner's diagnosis, quoted.** "A companhia se encontra perdida no que diz respeito
   a identidade visual, tendo como referencia só a logo e o azul." ("The company is lost on visual
   identity; its only reference is the logo and the blue.") That sentence is the brief.
2. **Official artifacts.** Logo files, media kit, the platform's avatar API, real rooms or
   venues, group badges, intros and lore. Hash each logo and confirm which entity it belongs
   to: the file the site used as "the logo" was a sub-department's badge.
3. **The medium.** If the product lives in a game or a platform with a visual grammar
   (pixel sprites, isometric rooms), that grammar is the craft layer.
4. **A theme from that world plus one genre reference for form.** Space, astronomy and ETs
   already lived in the community's intros; Soviet space-race posters gave the form (rays,
   banners, rockets, stamps). Write the exclusions before the first board: form only, no
   political symbols, no off-palette color.

No artifacts and no culture (a fresh SaaS)? Derive the theme from the product's domain and
its users' craft, state it in one line, and ask the owner one question before building.
Never fall back to a trend (glass, bento, neon, warm paper) as the identity.

**Signature family.** The identity must produce at least: a hero family with one variant per
page (three approved posters became Home, Classes, Ranking), crafted ornament assets from
the medium, and color exceptions that carry meaning. Record all three in `DESIGN.md`.

## 2. Color: narrow palette, scarce exceptions with meaning

- The official palette, in shades. When the brand has one color (one such case: "only the logo
  and the blue"), shades of that one hue for everything. Exceptions only where they mean
  something: gold only for honors and 1st place, each sub-group's color only on its own card.
  Scarcity is what makes gold read as honor.
- A page that needs a new color reopens `DESIGN.md`, not the page.

## 3. Craft in the medium (pixel art example)

- One grid at the platform's native sprite scale (for example: 1 art pixel = 2 screen px).
  Smaller means redrawn with fewer pixels, never resized.
- Never scale a platform sprite; crop without scaling (`object-fit:none`).
- Regrade generated art to the official assets' measured palette and outline (game badges:
  14-26 colors, binary alpha, 1 px outline; generated pieces had 8k-32k colors and fake grids).
- No blur or radial glow on pixel pieces. Smoke became pixel clouds, fire a 3-frame pixel
  flame, stars square pixels with a few twinkling crosses ("they look more like snowflakes"
  was the reaction to round dots).
- Small sprites ship as SVG data URIs, `shape-rendering:crispEdges`, one rect per horizontal
  run (a 72x60 laurel dropped from 132 KB to 44 KB).

## 4. Motion that explains, and works still

- "Everything has to work and communicate even without animation" (the owner): the static state of
  every animation communicates alone (ticker text visible, wave rings already spread, the
  answer sheet already marked).
- Animation only behind `prefers-reduced-motion: no-preference`; `steps()` for pixel art.
- Content never waits for an animation or an IntersectionObserver to appear. An observer
  entrance left a whole page empty in the review canvas.
- Animated objects are recognizable instruments of the function, one family across siblings
  (radar for security, antenna for communication, a filling answer sheet for admissions).
  Abstract rings were rejected: "it refers to nothing, it carries no identity".
- Never animate over the logo or a section's emblem: "the logo always has to stay visible".

## 5. Content

- Titles name the thing: "the title has to be the department's name". Verbs go on buttons.
- Emphasis through crafted assets, not glow: honor became pixel laurels, a monument pedestal
  with a gold plate, crossing spotlights and sparkles. Each reads as honor when still.
- An outside reference is seasoning, never a genre swap: the news page took a masthead,
  double rules, halftone photos and a drop cap inside the dark app. A full newspaper page
  was rejected: "if we make it 100% a newspaper it will feel out of place".
- Long lists borrow a proven structure (one chapter at a time, compact cards, a detail sheet
  on click) instead of giant cards ("it will get far too big").
- Real people: avatar from the public API, account checked (a nick given from memory matched
  a different, unrelated account), role and dates only from the owner. Unknown stays
  "to confirm"; never write a bio for a real person.

## 6. Owner loop

- Each reaction is quoted, the instance fixed, and the general rule written into
  `DESIGN.md` in the same turn. The rules above all started as one sentence of rejection.
- Same piece reproved twice: stop iterating blind, show 2-3 concrete options with previews,
  the owner picks (this is the Gate 2 stop rule applied to a single piece).

## 7. Identity checks (run with Browser verification)

| Check | Defect it caught | How |
|---|---|---|
| Logo-swap test | (the core identity test) | Swap the logo for a competitor's. If nothing else on the page breaks, the identity is borrowed: back to Gate 1 |
| Webfonts loaded in previews | A local preview without the font `<link>` measured system fonts, narrower; a name "fit" locally and overflowed live | Copy every `<link>` from the page head into any preview |
| No horizontal scroll with a classic scrollbar | Roots with fixed `width:1440px` scrolled 15 px once a vertical scrollbar appeared | Render inside an iframe of `width - 15` px; fail if `scrollWidth > clientWidth`. Root is `width:100%` + `overflow-x:clip` |
| Static state | Pages that only made sense in motion | Swap `(prefers-reduced-motion:no-preference)` for `not all` in the preview CSS, screenshot |
| After entrance | Entrance animations start at opacity 0 | Headless Chrome `--virtual-time-budget=2500` before the screenshot |
| True 390 px | Headless Chrome clamped the window to 500 px in our runs | Measure inside an iframe of the target width |

Overflow probe for the iframe page (read `parent.document.title` via `--dump-dom`; serve both pages over http, or pass `--allow-file-access-from-files`, so the iframe can reach its parent):
```html
<script>addEventListener('load',()=>setTimeout(()=>{const W=document.documentElement.clientWidth,f=[];
for(const e of document.querySelectorAll('body *')){const r=e.getBoundingClientRect();
if(r.width&&(r.right>W+1||r.left<-1))f.push((e.className||e.tagName)+' R'+Math.round(r.right))}
parent.document.title=JSON.stringify({sw:document.documentElement.scrollWidth,cw:W,out:f.slice(0,6)})},1500))</script>
```
Elements listed inside a deliberate horizontal scroller (card rows) are fine while `sw == cw`.
