# Context Anchors — references beyond dev-tool/SaaS

The base skill anchors heavily to Linear/Vercel/Stripe (dev-tooling). That's wrong by reflex for an
e-commerce page, a patient portal, or an editorial feature. This file gives **named, context-fit
anchors + concrete tokens + the slop tells specific to each context**, plus a palette of aesthetic
directions for art-direction mode and the 2026 token defaults.

Synthesized 2026-06-22 from web research across Dribbble/Mobbin/SaaS galleries, the Figma Community +
design-system docs, and type-foundry/editorial trend writeups. Anchors are real, named products;
treat their token specifics as *approximate* unless you confirm them. Where a claim was inferred
rather than sourced it is marked `(inferred)`.

**Refreshed 2026-06-23:** added the AI-chat and command-palette contexts; added 2026 slop tells
(bento-outside-landing, gradient-on-data, over-animation, pixel-font-as-body, default variable fonts);
re-verified anchors — Linear, Warby Parker, Aesop, the fintech set, the healthcare set, and Material 3 /
Carbon all still current (Material 3 added an "Expressive" layer but kept semantic color intact); flagged
Medium's shift to a system serif and Glossier's unconfirmed 2026 direction. The purple→blue gradient is
*confirmed* across 2026 sources as the single most common AI-UI tell.

---

## A. Context → register, anchors, tokens, must-haves, tells

Pick the row matching the brief. The **anchor** is the named bar to hit; the **tells** are what makes
that *specific* context read as AI-made.

### E-commerce product detail (DTC / retail) — register `marketing`/`ecommerce`
- **Anchors:** Warby Parker (editorial product discipline — the brand's edge is its product/features; the *web* lesson is presentation restraint), Nike (scroll-revealed product story), Aesop (quiet, typography-led, calm motion). *(Glossier was the classic pairing but its current direction is unconfirmed for 2026 — verify before anchoring to it.)*
- **Tokens:** warm-neutral ground (not dark dev-tool); serif or characterful sans for product name + clean sans for price/CTA; 24–32px section gaps, 80–120px between major blocks; *intentionally varied* card spacing, not uniform 16px radius everywhere.
- **Must-haves:** gallery with zoom; variant selectors (shade/size) with live preview; price + add-to-cart above the fold; reviews/social proof *before* the CTA; real product photography, never AI-smooth stock.
- **Tells:** uniform 16px radius on everything; stock "diverse team" photos; vague copy ("elevate your routine"); purple→blue gradient; missing a real product image.

### Fintech / banking dashboard — register `product-app` (fintech)
- **Anchors:** Revolut, Monzo, Cash App, Robinhood (data-viz), YNAB (category color-coding).
- **Tokens:** dark-first; semantic status colors (green=up, red=down, amber=warn) applied *consistently*; tight internal spacing (8–16px) with 24px+ between sections; mono for figures/balances; **no gradients inside data viz** (kills clarity).
- **Must-haves:** balance summary; account cards; transactions list; one clear chart; a primary money action (transfer/pay). Trust signals near sensitive data.
- **Tells:** inconsistent accent meaning; circular-progress overload; decorative gradient charts; system-default font pairing; gamification bolted on without purpose.

### Healthcare / patient portal — register `product-app` (healthcare)
- **Anchors:** Teladoc (one-tap telehealth), b.well, Sidekick/Reframe (calm chronic-care). 
- **Tokens:** **calm soft palette** (soft green/blue, warm neutrals), never harsh saturation; large type + generous whitespace; WCAG AA+ contrast and **44px touch targets** mandatory; visible trust signals (lock, privacy, certification) near data entry.
- **Must-haves:** appointments; medications; lab/results; message-your-doctor; progressive disclosure (show only what's relevant); smart defaults / pre-filled values.
- **Tells:** generic "doctor in white coat" imagery; hedging copy; missing trust badges; unexplained medical jargon; anxiety-inducing reds; cramped density.

### Editorial / long-form article — register `marketing` (editorial)
- **Anchors:** Substack (serif body + author-controlled branding), The Verge (custom type + real imagery), ProPublica (Tiempos, institutional rigor), classic magazine features. *(Medium shifted to a system serif ~2024–25, so it is no longer the custom-serif exemplar — keep Lyon/Tiempos/GT Sectra as the type benchmark, not Medium's own stack.)*
- **Tokens:** **serif body** (Tiempos, Lyon, GT Sectra, Editorial New, Spectral, Cormorant) at **1.5–1.65 line-height**, measure **~60–75 chars (650–800px)**; sans only for UI/metadata; 80–120px side margins; paragraph spacing ~1.5–2× line-height; **no cards/boxes around prose**.
- **Must-haves:** headline + byline + read-time; hero image; pull-quotes; section breaks; related-stories footer (not a competing sidebar).
- **Tells:** system serif (Georgia) with no personality; cards around text; AI-smooth article illustrations; "The Ultimate Guide to…" headings; filler ("In today's world").

### Mobile app home screen — register `product-app` (mobile)
- **Anchors:** Spotify (adaptive shelves), Apple Music, Telegram (gesture system), Apple Maps (context modes).
- **Tokens:** **bottom-centric navigation** (thumb reach); 8px internal padding, 16–24px section gaps; single driving accent; dark-first; design at the stated width (e.g. 390px) — don't ship a desktop layout shrunk.
- **Must-haves:** bottom tab bar OR bottom sheet; primary stat/CTA in thumb zone; recent/list section; touch targets ≥44px; pull-to-refresh / gesture affordances where natural.
- **Tells:** top-heavy nav forcing thumb stretch; uniform 8px everywhere; generic shelf labels ("Recommended"); oversized stock illustration; desktop-shrunk layout.

### B2B analytics dashboard / enterprise admin — register `product-app` (b2b-data-dense)
- **Anchors:** Tableau (presentation-grade viz), Looker (semantic metrics), Carbon (enterprise grid).
- **Tokens:** dark-first; resizable card grid (4–12 col); **semantic data colors, no decorative gradients**; mono for metrics; sticky filter/date header; chart margins on the 4px grid; "updated Xs ago" real-time cue.
- **Must-haves:** date-range picker; collapsible filters; drill-down; export (CSV/PDF); density that respects importance (lead metric larger).
- **Tells:** placeholder chart icons / fake data; generic metric names ("KPI", "Performance"); decorative gradients; no drill-down; no freshness indicator.

### Auth (sign-up/login) + error/404 — register `product-app` (utility) / `utility`
- **Anchors:** Vercel (high-contrast minimal), Stripe (explicit errors), Clerk (passkey/social-first).
- **Tokens:** purposeful heading ("Sign in to continue to Acme", not "Login"); 24px between fields, 32px between sections; full-width CTA on mobile, 48px targets; single semantic accent.
- **Must-haves:** email-first; password visibility toggle; inline (not modal) errors with *specific* text ("Incorrect email or password"); social/passkey ordered by audience **in DOM order** (consumer → social buttons first; **B2B → the email/SSO block first**, social below the divider); on 404: branded illustration + clear "Go home" + search/related links.
- **Tells:** "Something went wrong" / generic errors; placeholder-as-label; stock illustration on the 404; tiny targets; oversized desktop fields.

### Marketing event / product-launch — register `saas-landing` / `marketing`
- **Anchors:** Stripe ("Financial infrastructure for the internet" — 5-word clarity), Vercel launch pages, Linear.
- **Tokens:** display headline 40–80px; one accent on a committed light or dark hero; 80–120px section padding; real product screenshots/video over mockups.
- **Must-haves:** hero (headline + sub + CTA + product visual); features 3–4 col; trust signals (named logos, G2/specific metrics); pricing/comparison if relevant; founder voice.
- **Tells:** "Build the future of work"/"Scale without limits"; stock office photo; rounded-corner-everything; purple→blue gradient; no named/measurable proof.

### AI / LLM chat & agent interface — register `product-app` (ai-chat)
- **Anchors:** ChatGPT (streaming thread + left-rail history), Claude.ai (centered ~768px measure, side artifact panel), Perplexity (citation-forward, numbered inline sources), Raycast AI (compact, OS-native density), v0 (prompt → live code + preview).
- **Tokens:** dark-first baseline; one restrained action accent (teal/blue), **never a purple→blue gradient** (the #1 AI-UI tell); semantic status (error/success/warn/info); full-width message containers on a subtle ground, *not* chat bubbles everywhere; mono (JetBrains Mono, Geist Mono) for code; body 16px / 1.6; a committed sans, not Inter-by-default; radius varied by role (don't paint 16px on everything).
- **Must-haves:** streaming output (token-by-token) with a **stop** control; a growing multiline composer (Cmd/Ctrl+Enter to send); a per-message action row (copy, edit, regenerate); markdown with syntax-highlighted, copy-able code blocks; citations as numbered footnotes / inline links (Perplexity); left-rail conversation history grouped by date (Today / Yesterday / 7d+); a model picker if multi-model; explicit error recovery (stop, retry, visible failure).
- **Tells:** purple→blue gradient; the generic **"centered input + sparkle icon + 'How can I help you today?'"** template dropped into an unrelated domain; chat-bubble UI forced everywhere; no streaming affordance (waits for the full response — feels broken); visible markdown artifacts mid-stream (half-open code fences); uniform 16px radius; Inter/system-by-default; vague "Ask anything" over specific capability language.

### Command palette / action launcher — register `product-app` (utility)
- **Anchors:** Superhuman (centered modal, monospaced commands, icon per row, toggle), Linear (Cmd+K convention, fuzzy + context-aware filtering), VS Code / Figma (the power-user baseline users now expect).
- **Tokens:** inherit the app theme; subtle backdrop (app bg + opacity, not a heavy black scrim); selected row uses the app accent; **no gradients**; a monospaced or tight UI face for commands (JetBrains / IBM Plex / Geist Mono); rows 40–48px (touch ≥44px); centered modal 500–700px desktop, near-full-width mobile.
- **Must-haves:** Cmd+K trigger (same shortcut toggles open/closed); fuzzy search with typo tolerance, not exact-match; an icon per command; context-aware filtering (hide commands unavailable in the current state/role); action-focused titles (Create…, Find…, Export…) with aliases for discoverability; displayed keyboard shortcuts; an overflow hint (more below the fold); focus restoration on close.
- **Tells:** a bare text-only list with no icons or hierarchy; the default system font (loses the "powerful tool" signal); no shortcuts shown; a corner dropdown instead of a centered modal; exact-match-only search; generic category names ("Features", "Tools") instead of verbs.

---

## B. Aesthetic directions for art-direction mode

When the brief is creative/open ("surprise me", "bold", brand-expression), pick ONE of these named
directions instead of inventing a vibe. Each carries real typefaces + a color stance.

Each direction below ships **execution specs**, not just a name — type scale, tracking, leading, a color triplet, and the one signature move — so it is concrete enough to build without further clarification. (A direction named without these is "nominally specific but operationally vague" — the gap that makes art-direction output read generic.)

**Scope guard:** §B is for **art-direction mode / open creative briefs only.** When a `DESIGN.md`, a shadcn `components.json`, or an established design system already owns the tokens (Phase 2 / Gate 3), it **overrides every direction below** — never pull these typefaces or color triplets into a product surface that already has a token system. Adopt the registry; don't art-direct over it.

1. **Warm editorial serif** — refined, cinematic.
   - *Type:* Editorial New / Tiempos / GT Sectra / Lyon, display; a quiet humanist sans or the same serif for body.
   - *Scale:* display `clamp(2.5rem, 6vw, 5.5rem)` · tracking `-0.02em` · leading `1.05`; body leading `1.6`.
   - *Color:* bg `#F7F3EC` · fg `#1A1714` · accent terracotta `#C26A4A` (ochre `#C9912F` alt).
   - *Signature:* oversized drop-cap or full-bleed editorial photography with luxurious margins.
   - *Use:* luxury, heritage, long-form.
2. **Swiss / neo-grotesque** — rational, grid-native, trustworthy.
   - *Type:* Neue Montreal / GT America / Söhne.
   - *Scale:* display `clamp(2rem, 4.5vw, 4rem)` · tracking `-0.01em` · leading `1.1`; strict 12-col grid.
   - *Color:* bg `#FAFAF8` · fg `#0A0A0A` · one restrained accent (klein `#0047FF` or signal red `#E5322D`).
   - *Signature:* visible baseline grid + hairline rules; asymmetric Müller-Brockmann layout.
   - *Use:* systematic tech, modern corporate.
3. **Soft-organic / biophilic** — calm, wellness, grounded.
   - *Type:* Neue Gstaad / Palma display + a humanist body (Aktiv Grotesk, Mier).
   - *Scale:* display `clamp(2.25rem, 5vw, 4.5rem)` · tracking `-0.01em` · leading `1.15`; large radii `16–28px`.
   - *Color:* bg mushroom `#EDE7DC` · fg clay `#3D3528` · accent moss `#6B7A55` (softened blue `#7E96A8` secondary).
   - *Signature:* organic blob shapes, soft `24px` radii, generous whitespace — no hard edges.
   - *Use:* health, eco, meditative.
4. **Brutalist / neo-brutalist** — raw, confrontational, honest.
   - *Type:* Monument Extended / Neue Haas Grotesk display + a mono (JetBrains Mono, VT323) for data.
   - *Scale:* display `clamp(4rem, 10vw, 15rem)` · tracking `-0.03em…-0.06em` · leading `0.85–0.95`; mono `10–14px` tracking `0.05–0.1em`.
   - *Color:* light bg `#F4F4F0` / fg `#050505` / accent `#E61919`; dark bg `#0A0A0A` / fg `#EAEAEA` / accent `#E61919`.
   - *Signature:* **zero radius, zero gradient, zero soft shadow** — 1–2px solid borders only; `[ LABEL ]` ASCII framing, CRT scanlines / halftone, `REV 2.6`-style strings.
   - *Use:* provocative indie/tech.
5. **Typographic maximalism / kinetic** — type as hero.
   - *Type:* Neue York / GT Flexa (variable-weight).
   - *Scale:* display `clamp(3rem, 12vw, 12rem)` · tracking `-0.04em` · leading `0.9`; animate the variable weight axis.
   - *Color:* base `#0D0D0D` + saturated accents trapped inside glyphs (`#FF3D2E`, `#3D5AFE`, `#FFE600`).
   - *Signature:* type overlaps and bleeds off-canvas; weight shifts on scroll; color lives *inside* the letters.
   - *Use:* music, entertainment, expressive campaigns.
6. **Retro-futurist / material 3D** — tactile, exuberant, Y2K-revived.
   - *Type:* bold display (Clash Display, Monument) + tactile glass/metal surfaces with *real* texture.
   - *Scale:* display `clamp(2.5rem, 7vw, 6rem)` · tracking `-0.02em`.
   - *Color:* deep base `#10131A` + chrome/iridescent accents (`#A8B5FF`, `#FF9CEE`) — grain, not CGI sheen.
   - *Signature:* beveled glass/chrome surfaces; inner-glow built from noise, not blur.
   - *Use:* consumer delight, gaming.
7. **Imperfect-by-design** — anti-sterile, crafted, human.
   - *Type:* hand-drawn / display with character + mono body; grain/riso texture.
   - *Scale:* display `clamp(2.5rem, 6vw, 5rem)` · slightly irregular tracking · leading `1.2`.
   - *Color:* bg wheat `#E9DCC4` · fg espresso `#2A211A` · accent caramel `#B5793D` (sage `#8A9678` secondary).
   - *Signature:* riso/grain overlay, slight element rotation, visible registration offset — deliberate imperfection.
   - *Use:* indie/DTC, editorial identity.
8. **Deconstructed / specimen** — intellectual, curatorial, "pinned specimen".
   - *Type:* experimental lettersets; oversized specimen numerals beside fine captions.
   - *Scale:* mixed — numerals `clamp(4rem, 9vw, 11rem)` against `12px` captions; tracking varies by role.
   - *Color:* B&W `#0A0A0A` / `#FFFFFF` + one accent `#FF4D00`.
   - *Signature:* pinned-specimen layout, numbered annotations, hairline crop marks, asymmetric negative space.
   - *Use:* gallery, academic, catalogues.

Two more named directions (from premium-frontend references), use the same spec discipline:
- **Cyber / technical** — dark substrate + neon accents + monospace; staggered terminal-style reveals. bg `#080A0F` / fg `#D6E1E8` / accent `#39FF88` or `#00E0FF`; mono display, `[STATUS]` framing, grid telemetry. Use: dev-tools with attitude, security, web3.
- **Cinematic pacing** — full-viewport imagery, slow cross-fades, scroll-as-narrative, heavy negative space. Restrained palette, one or two huge type moments. Motion is the medium — pair with §L. Use: product films, premium launches, brand stories.

Foundries to draw from (named, current): **Pangram Pangram, Grilli Type, Klim, Commercial Type, ABC Dinamo.** Free routes: Bricolage Grotesque, Fraunces, Spectral, Cormorant, Geist, IBM Plex, JetBrains Mono.

---

## C. 2026 token defaults (when the project has none)

- **Spacing:** 8px grid for layout, 4px sub-grid for internal padding. Steps 4/8/12/16/24/32/48/80/120.
- **Type scale:** 16px base, modular ratio ~1.25; line-height snapped to the 4px grid (e.g. 14/20, 16/24). Editorial body 1.5–1.65.
- **Radius:** semantic XS/S/M/L/XL/Full = 2/4/8/12/16–24/9999. Assign per component; don't paint one radius on everything.
- **Elevation:** ≤5 levels; modern depth = two-part shadow (sharp key + soft ambient), or color-contrast elevation (Carbon). Avoid the default `0 4px 6px rgba(0,0,0,.1)`.
- **Color naming:** semantic tokens (`bg-surface`, `text-muted`, `border`, `accent`), one name → per-theme value. Dark mode is a first-class context, not a `dark:` afterthought; step surfaces +5–8% luminance.
- **Accessibility:** 4.5:1 text / 3:1 UI+large; focus ring ≥2px at ≥3:1; touch targets ≥44px (24px is the AA floor).
- **2026 color stance:** the field shifted from cool steely grays (2022) to **warm earthy neutrals + one restrained accent**. Tint neutrals; reserve saturation for a single accent. Concrete warm neutrals: wheat `#E3DAC9`, taupe `#CAB9A9`, warm gray `#908D87`; earthy accents: terracotta `#CC5959`, ochre `#E6B35A`, smokey-jade `#4A635D`.
- **Premium-consumer palette ban:** the LLM default for cookware/wellness/artisan/luxury/DTC-home-goods briefs is warm beige/cream (`#f5f1ea`/`#f7f5f1`/`#efeae0`) + brass/clay/oxblood/ochre (`#b08947`/`#b6553a`/`#9a2436`) + espresso near-black (`#1a1714`) — this exact family is now the generic tell for the register, banned as a default reach. Rotate instead: cold luxury (silver-grey/chrome/smoke), forest (deep green/bone/amber), black-and-tan (off-black + warm tan, no beige), cobalt+cream, terracotta+slate, olive+brick+paper, or monochrome + one saturated pop. Don't reuse the same family across consecutive premium-consumer projects. Override only when the brand brief explicitly names the beige/brass palette.

---

## D. Updated slop catalog (additions to the base hard bans)

The base SKILL.md already bans purple gradients, generic bento, glassmorphism-by-default, default
shadow, em dashes, and emoji-as-icons. Add these, confirmed across 2026 trend sources:

- **Decorative glassmorphism** — frosted cards/blur as spectacle reads as 2021–22. *Nuance:* restrained, **functional** depth ("glass 2.0" — blur used for legible layering over content, e.g. a now-playing bar) is fine. Decoration out; function in.
- **Oversaturated hyper-smooth 3D** — pristine CGI gradient spheres / liquid-metal blobs. If 3D, give it real texture/imperfection.
- **Perfect symmetry + dead-center everything** — reads as algorithm. Use grid-based but human-adjusted asymmetry.
- **Neumorphism** — soft debossed/embossed buttons; dated to ~2020.
- **AI-smooth stock imagery** — impossibly polished + "diverse office". Prefer real photography (with grain/character), custom illustration, or data-as-imagery.
- **Algorithmic HSL color ramps** — evenly-stepped lightness ladders with no human curation; tells as generated. Curate with reasoning (warm vs cool, where saturation goes).
- **Uniform-everything** — identical radius + identical padding on every element. Vary by role.
- **Vague/averaging copy** — "Scale", "Transform", "Seamlessly integrate", "Build the future of X". Replace with specific, measurable, founder-voiced lines.
- **Bento outside its lane** — the bento grid is a *landing-page* device. On a product-app dashboard, a dense data table, or a product-detail page it reads as trend-chasing; those registers want scannable hierarchy and functional density, not modular tiles. (Extends the base generic-bento ban to non-landing registers.)
- **Gradient on data** — gradient-filled chart series, or the "big hero metric + gradient accent line" pattern (now in ~90% of generated SaaS dashboards). Numbers and data viz take *solid semantic* color; a gradient on a value is decoration that costs clarity.
- **Over-animation on dense UI** — Framer Motion / Motion.dev / Spline make it trivial to animate everything; on dashboards, tables, and feeds that obscures scannability. Motion is for feedback and state change, not decoration on information-dense surfaces.
- **Pixel / bitmap display fonts as body** *(critical)* — Geist Pixel and similar bitmap faces are a real 2026 trend but **logotype/campaign-only**; using them for body text, sustained reading, or any accessibility-critical copy is an instant tell.
- **Variable fonts left at defaults** — loading a variable face (GT Flexa, etc.) but never setting weight/width/optical-size reads as "installed the tech without designing with it." Variable fonts demand intentional axis choices.
- **Version/count eyebrows** — version labels (`V0.6`, `BETA`, `EARLY ACCESS`) as a default hero eyebrow, section-number eyebrows (`00 / INDEX`, `001 · Capabilities`), and `01 / 4`-style pagination on images/bento tiles — banned unless the brief is genuinely about launch/preview status or the count is functional (a real carousel index).
- **Eyebrow ratio (mechanical)** — max 1 eyebrow (small uppercase/tracked label above a section headline) per 3 sections; hero counts as one. If section *n* has one, the next two can't. Pre-ship check: count `uppercase tracking`-style labels against section count; over the ratio, drop them — the headline alone is enough.
- **Decoration text strips & scroll cues** — bottom-of-hero mono-caps strips (`BRAND. MOTION. SPATIAL.`), locale/weather strips (`LIS 14:23 · 18°C`), and scroll-cue affordances (`↓ scroll`, an animated mouse icon) are agency-portfolio tells. Drop them unless the strip is a real functional nav/status element, or the brief is explicitly travel/timezone-distributed.
- **Split-header pattern** — a big left-aligned headline with a small explainer paragraph floating in the section header's top-right corner, unconnected to any visual, is a tell. Stack vertically instead (headline, then body, max `65ch`) unless the right column genuinely carries a visual or interactive element.
- **Micro-decoration inflation** — the middle-dot (`·`) rationed to ≤1 per metadata line, not the default separator for everything; decorative colored status dots before every nav item/list row/badge with no real state behind them; generic step labels (`Stage 1/2/3`, `Phase 01/02/03` — the step's own content is the label); photo-credit-style captions (`Field study no. 12 · Ines Caetano`) on stock/generated images with no real credited photographer; fake version footers (`v1.4.2 · last sync 4s ago`) on marketing pages; live-stock counters (`Reservation 412 of 800`) without real backing data.
- **Filled-track comparison bars** — a large `bg-zinc-200`-style filled-background progress bar used only to compare two numbers is dashboard clutter on a landing page. Prefer a number + small icon, or a thin bar with no background track.
- **Layout repetition tells** — more than 2 consecutive image+text zigzag sections (the 3rd reads as templated rhythm); more than one horizontal marquee per page; a long spec/list table with a hairline under every single row (pick one divider style used sparely, or switch to grouped chunks / a 2-col card grid / featured-vs-rest disclosure).
- **Hero mechanical constraints** — headline ≤2 lines desktop, subtext ≤20 words and ≤4 lines, top padding capped around `6rem` (more reads as content floating mid-viewport, not breathing room — fix with font/asset scale, not padding), and ≤4 total text elements (eyebrow-or-brand-strip *or* neither, headline, subtext, CTAs). No trust micro-strip, pricing teaser, or feature-bullet list stuffed into the hero — those get their own section directly below it, including the "Used by" logo wall.
- **CTA discipline** — button label must fit one line at desktop (shorten to ≤3 words or widen the button, never wrap); one label per intent across the whole page ("Get in touch" *or* "Contact us", not both scattered across nav/hero/footer).
- **Button/ghost contrast** — verify CTA text is legible against its own background before shipping: white-on-white buttons, a `bg-white` CTA with a `text-white` label, and borderless ghost buttons over photographic backgrounds with no scrim/stroke are the recurring failure. WCAG AA (4.5:1 body / 3:1 large) applies to buttons, not just body text.
- **Jane Doe effect** — generic placeholder names ("John Doe"/"Sarah Chan"), generic egg/default-user-icon avatars, fake-perfect round numbers (`99.99%`, `50%`), and startup-slop invented brand names ("Acme"/"Nexus"/"SmartFlow") all read as generated. Use specific, organic, locale-appropriate substitutes (`47.2%`, names/brands that sound real).

---

## E. Typeface by role (stop defaulting to Inter)

- **Display (tech):** Geist, Neue Montreal, GT America, Bricolage Grotesque.
- **Display (editorial/luxury):** Editorial New, Tiempos, GT Sectra, Fraunces, Playfair Display.
- **Body (reading):** Tiempos/Lyon/Spectral/Cormorant (serif); Geist Sans, Söhne (sans).
- **Body (calm / wellness):** Neue Gstaad — humanist sans, soft apertures; health, eco, meditative surfaces.
- **Functional UI:** Geist Sans, IBM Plex Sans (Inter only if `DESIGN.md` already commits to it).
- **Mono (flavor/metrics):** JetBrains Mono, Geist Mono, GT America Mono, Söhne Mono.
- **Never for body:** pixel/bitmap display faces (Geist Pixel) and any mono — logotype, code, and retro/zine campaigns only.
- **2026 shift:** the field moved from geometric sans (Circular, Montserrat) to **neo-grotesque** — prefer Neue Montreal, Söhne, or the free Bricolage Grotesque for display/UI in systematic contexts.
- **Anti-generic additions (2026-08):** mono com caráter: **Berkeley Mono** (usgraphics.com, paga; humanist-machine, terminal chic), **Departure Mono** (pixel-adjacent, grátis), **Commit Mono** (neutra, ligaturas opcionais, grátis); grotesks com identidade no **Fontshare (grátis)**: **Cabinet Grotesk** (terminais suaves, líder do "bouba grotesk"), **General Sans**, **Satoshi**. Regra: uma face "com opinião" no display OU no mono, nunca nas duas ao mesmo tempo.

---

## F. Interaction & experience patterns (elite UX)

§A–§E are how it *looks*; this is how it *behaves*. These back **Gate 5** and the **experience audit**. The bar is set by products whose *experience* is the draw — Linear, Stripe, Raycast, Superhuman, Figma, Gmail. The recurring failure: the model makes it look right and leaves the interaction hollow — so this is where to spend effort.

**Honest feedback & perceived performance.** Users judge speed by feedback, not milliseconds. Latency budget:
- **<100ms** feels instant — hover/press/focus, optimistic toggles; no spinner.
- **100–400ms** (Doherty threshold) stays "responsive" — short calls, validation.
- **400ms–1s** show a **skeleton** (layout known) or a spinner (brief action); progress visible by ~800ms.
- **1–10s** explicit progress (`Uploading… 3 min left`) + cancel.
- **>10s** step progress + estimate + pause/resume.
- **Optimistic UI** — render the action immediately (the like turns red), roll back with a message on failure. **Skeletons feel ~30–50% faster than spinners** for content; reserve spinners for brief actions. *Stripe skeletons; Twitter optimistic like; Figma `Saving…` → `Saved`.*

**Keyboard-first & efficiency.** Everything operable by keyboard: `Tab`/`Shift+Tab` in a logical order, `Enter`/`Space` activate, `Esc` closes/cancels; visible focus (Gate 3 numbers — not restated here); never `<div onClick>`. A power surface (≥10 actions) earns a `Cmd+K` palette with fuzzy, typo-tolerant search. Surface shortcuts in tooltips/help. No drag-only interaction — give it a keyboard equivalent. *Linear (`Cmd+K`, `J/K`), Raycast, Superhuman.*

**Error prevention & forgiving input.** Smart defaults (today's date, the signed-in name); input masks; validate **on blur or submit, not on every keystroke** (real-time only for password strength / async availability, shown as progress, not error); autosave/draft for anything long (`Saving…` → `Saved`). **Destructive actions get confirm *or* undo** — confirm with the safe option focused and the verb named ("Delete invoice forever"), or a live undo toast (Gmail's 5s undo-send). *GitHub type-to-confirm delete; Figma deep undo + version history.*

**Wired states, not mocked states.** Gate 4's 8 states must be reached by *real code paths*, not just styled: the disabled button is actually unclickable, the loading state actually shows on submit, the error state actually renders the server message. Pair every state with a non-color signal (icon/opacity/text), never color alone.

**Recognition over recall.** Progressive disclosure — essentials first, advanced behind "More"; multi-step only with a visible step indicator + back/forward + saved draft; one obvious primary action per screen (secondary de-emphasized, tertiary in a menu); inline help on focus, not a separate `?`.

**Experience anti-patterns (the interaction slop catalog)** — the behavioural "AI made that", backing the experience audit. Each with the elite alternative:
- **Blocking full-page spinner as the default load** *(critical)* → a skeleton matching the layout, or optimistic UI with a pending marker on the affected row only.
- **Keyboard trap** *(critical)* → a modal traps focus *intentionally*, `Esc` closes, focus returns to the trigger; dropdowns/widgets always have a keyboard exit.
- **Destructive action with no confirm and no undo** *(critical)* → confirm (safe option focused, verb named) or a live undo toast.
- **Silent submit/click** *(critical)* → disable + spinner on the control, or an optimistic update; prevents the double-submit.
- **Validation on every keystroke** → validate on blur/submit; real-time only as non-error progress.
- **Dead-end empty/error state** → answer *what happened, why, what next* with a CTA; treat empty states as onboarding.
- **Hover-only affordance** → `:focus`/`:active` match `:hover`; nothing important hidden behind hover on touch.
- **`<div onClick>` / placeholder-as-label / `outline:none`** → semantic `<button>`/`<a>`; a real `<label>`; a visible focus replacement.
- **Disabled button with no reason** → say why inline ("Complete all required fields"), or keep it enabled and validate on click.
- **Motion ignoring `prefers-reduced-motion`** → gate animation/parallax behind the media query; nothing auto-plays unstoppably.
- **Toast-only reporting of a critical error** → modal/persistent banner for critical; toast only for low-stakes background events.

**AI-generated experience tells** (look fine, behave hollow): `onClick` handlers that do nothing · states styled in CSS but no path reaches them · `<div>`/`<span>` click targets with no `onKeyDown`/`role`/`tabindex` · missing `aria-label` on icon-only buttons · generic labels ("Submit"/"OK") · no loading flag in the submit handler · `console.error` instead of a user-facing error · placeholder used as the label.

---

## G. Microcopy by interaction type

High-stakes text is the cheapest UX win and the model's most generic output. Be specific, human, and actionable — name the problem *and* the next step. This is a frame, not a phrasebook.

| Interaction | Pattern | Example |
|---|---|---|
| Form-field error | name the field + the fix, inline | "Project name is required." |
| API / submit / conflict error | what failed + recovery, persists until acted on | "That slug is taken — try another, or open the existing project." |
| Loading (blocking) | name the work + progress, not a bare spinner | "Uploading report.pdf — 3s left" |
| Loading (non-blocking) | transient, on the affected element | `Saving…` → `Saved` |
| Empty state | reassure + value + a next action | "No items starred yet. Star anything to find it fast — browse the library." |
| Confirm (destructive) | name the exact action + named buttons | "Delete this conversation?" · `Cancel` / `Delete` |
| Success (transient) | confirm + offer undo where it applies | "Invite sent. Undo." |
| Disabled control | say *why*, near the control | "Add a card to continue." |

Voice matches the register: supportive (Slack, Mailchimp), professional (Stripe, Linear), terse (Raycast). **Never:** "Something went wrong" · "Invalid input" · "Error #5892" · "Submit" · "No data" · "Are you sure?".

**Pre-ship copy self-audit.** Re-read every visible string (headlines, eyebrows, buttons, body, captions, alt text, errors) before calling it done. Flag and rewrite: grammatically broken lines, unclear referents, forced/cute AI-wordplay, or copy that reads like the model performing thoughtfulness — plain and functional beats clever-but-wrong.

**One copy register per page.** Don't mix technical-mono, editorial prose, and marketing punch in the same composition unless the brand voice explicitly calls for the mix.

---

## H. Accessibility & SEO

**One semantic-HTML foundation serves both.** What a screen reader reads is what a crawler reads — landmark regions, a logical heading hierarchy, real labels, and meaningful alt text make a page navigable for assistive tech *and* parseable for search. Accessibility applies to **every register**; SEO applies to **public surfaces** (saas-landing, marketing, docs, e-commerce, editorial) and is **N/A for product-app / personal-portfolio** (post-login / private — crawlers don't and shouldn't reach them; internal a11y still applies). Backs **Gate 6** and the **a11y/SEO audit**. (Contrast/focus/touch live in Gate 3; keyboard, focus management, and reduced-motion in Gate 4/5 — not repeated here.)

### Accessibility — the structural / semantic layer (every register)
- **Landmarks** — `<header>`, `<nav>`, exactly one `<main>` (the unique content), `<footer>`; `<article>`/`<section>` for grouping. Real elements over `<div>` soup. **Native HTML before ARIA** — ARIA fills a gap native HTML can't express; it is not a default.
- **Headings** — exactly one `<h1>` (the page's purpose), then `<h2>` → `<h3>` with no level skips; descriptive, not "Section 1".
- **Forms** — every control has a real `<label>` (via `for`/`id` or wrapping), visible, never placeholder-as-label; errors set `aria-invalid="true"` + `aria-describedby` pointing to a persistent, specific message.
- **Form contrast** — inputs, placeholder text, focus rings, helper text, and error text each independently pass WCAG AA against the section background; a light placeholder on a near-white form, or helper text grayer than 4.5:1, fails even when the field's own label passes.
- **Images** — content images carry concise, descriptive `alt` (a chart's *insight*: `alt="Revenue up 23% YoY"`, not "Chart"); decorative images use `alt=""` (present but empty), never omitted.
- **Custom widgets** — expose **name / role / value** (`role`, `aria-label`/`aria-labelledby`, and state via `aria-checked` / `aria-expanded` / `aria-selected` / `aria-valuenow`); document the interaction model in `DESIGN.md`.
- **Live updates** — async/optimistic changes ("Saving…" → "Saved", a new message, a refreshed metric) live in an `aria-live="polite"` region (present at load, content swaps inside it); `assertive` only for time-critical alerts.
- **Page basics** — `lang` on `<html>` (BCP-47, e.g. `lang="en"`); a **skip-to-main** link as the first focusable element (visible on focus, never `display:none`) on nav-heavy pages; no positive `tabindex` (use `0`/`-1` + DOM order).

### SEO — public registers only
- **Head** — a unique, descriptive `<title>` (~50–60 chars, purpose-forward, not "Untitled"); a unique `<meta name="description">` (~120–160 chars, plain language + soft CTA); a **self-referential, absolute** `<link rel="canonical">` (resolves `?utm=`/sort/filter variants; no canonical chains).
- **Social** — Open Graph (`og:title`, `og:description`, `og:image` [absolute URL, ~1200×630, static], `og:url`, `og:type`) + Twitter (`twitter:card="summary_large_image"`), all in the server-rendered HTML.
- **Structure** — the shared `<h1>` + heading hierarchy + landmarks; **descriptive link text** (the destination, never "click here" / "read more"); `<meta name="viewport" content="width=device-width, initial-scale=1">`.
- **Crawlable** — title / H1 / body present in the **server-rendered** HTML (SSR/SSG), not client-JS-only; nothing critical hidden via `display:none` / `opacity:0`.
- **Never** — a `<meta name="keywords">` tag (dead since ~2009; a spam signal), keyword-stuffed titles/copy/anchors, doorway/thin pages, or canonical chains.

### JSON-LD structured data by context
| Context | schema.org type |
|---|---|
| SaaS / product landing | `Product` + `Offer` (per tier) + `Organization` (combine via `@graph`) |
| Blog / editorial / article | `Article` / `BlogPosting` (headline, datePublished, author) |
| Docs — FAQ / help | `FAQPage` (Q&A pairs) |
| Docs — multi-page reference | `BreadcrumbList` (matches the real path) |
| E-commerce product | `Product` + `Offer` + `AggregateRating` (omit ratings if none exist) |
| Any site identity | `Organization` (name, logo, contactPoint, sameAs) |

### Core Web Vitals (a ranking factor — keep it light, not a perf budget)
Targets (2026): **LCP ≤2.0s · INP ≤200ms · CLS <0.1**, on real-user data (Search Console CrUX), mobile + desktop. SEO's job is to *meet* the thresholds (reserve image space to avoid CLS, keep handlers <200ms, don't render-block the LCP element); per-asset optimization is a separate discipline — don't spec it here.

### Verify
- **axe-core / axe DevTools / WAVE** — WCAG 2.2 issues (headings, landmarks, labels, alt, name/role/value).
- **Lighthouse SEO** (mobile + desktop) — title, meta, crawlable links, viewport.
- **Rich Results Test / schema validator** — the JSON-LD parses and matches its type.
- **OG/Twitter preview** (opengraph.xyz, platform debuggers) — the card renders (image not broken, text not truncated).

---

## I. Design systems & the patterns big companies define

Gate 2 anchors to a named *product*; this is the named *systems* layer — the industry-standard design systems to anchor to (or adopt) per context, and the cross-cutting patterns they've standardized. **Anchor to the system that fits the register, not reflexively to a dev-tool one.**

### The systems — anchor to the one that fits the context
| System | Company | Anchor it for | Signature it defined |
|---|---|---|---|
| Material 3 | Google | consumer, Android, multi-platform | dynamic color, density modes, color-role semantics |
| Human Interface Guidelines | Apple | iOS / macOS / visionOS native apps | clarity · deference · depth; platform-native controls, SF Symbols |
| Carbon | IBM | enterprise, data-dense B2B, compliance | role-based semantic color, grid-native, multi-theme |
| Polaris | Shopify | commerce admin, merchant tooling | merchant-first language, framework-agnostic web components |
| Fluent 2 | Microsoft | MS ecosystem, enterprise cross-platform | two-part elevation, semantic alias tokens, density |
| Ant Design | Ant Group | high-density B2B data tables (React) | 12-col grid, dark-first, deep component APIs |
| Lightning (SLDS 2) | Salesforce | Salesforce / enterprise multi-tenant | AI-ready tokens, framework-agnostic CSS |
| Spectrum | Adobe | design tooling, premium-polish apps | expressive motion, accessible-contrast tokens |
| Primer | GitHub | developer tools, code platforms | mono-friendly, Octicons, table/code-display |
| Atlassian | Atlassian | team-collaboration / workflow software | token elevation, productivity density |
| Base Web | Uber | large multi-brand systems | Overrides API (customise without forking) |
| Radix | — | a headless foundation for a custom system | unstyled primitives + ARIA / keyboard built in |
| shadcn/ui | Vercel ecosystem | Next.js + Tailwind, copy-paste source | Radix + Tailwind + semantic tokens in your repo |
| Mantine | — | batteries-included React | 120+ components/hooks, WCAG color system |

### Anchor vs. adopt vs. build (extends Phase 2)
**Adopt is the default whenever a system is present** — inventing a palette *beside* an existing system is the single most common production regression. Only anchor-or-build when there is no system to adopt.
- **Adopt wholesale** when the project already uses an established library (MUI/Material, Ant, Polaris, Mantine, Carbon-React, Fluent-React, shadcn/Radix): use its tokens, primitives, theming — **never a parallel palette** (the #1 Gate-3 → production drift).
- **Anchor to** when you're *not* using that library: adopt its visual language, token naming, and pattern grammar as the bar (e.g. "anchored to Material 3 semantics"), implemented in your stack. The most common case.
- **Build custom** only for art-direction or a true one-off — then use the §C 2026 defaults and still follow the token discipline below.

### Cross-cutting patterns the industry standardized (apply where they fit)
- **Multi-tier tokens** — primitive (raw `blue-600`) → semantic (`color-primary`) → component (`button-bg`). One semantic change ripples everywhere; this is what makes theming work.
- **Tokens-as-code** — W3C **DTCG** JSON (stable since Oct 2025), version-controlled, transformed to CSS vars / Tailwind / Figma (Style Dictionary, Tokens Studio). ~74% of mature systems ship tokens as the primary deliverable.
- **4 / 8px grid** + a 4px sub-grid for internal spacing (no stray 2/6px offsets).
- **Command palette** — `Cmd+K`, fuzzy, context-aware (see §A command-palette row).
- **Density modes** — compact (data, mouse) · normal · cozy (touch, 48px targets); responsive.
- **Dark mode first-class** — its own elevation (surfaces +5–8% luminance) and semantic overrides, not a `dark:` afterthought.
- **Motion tokens** — duration (120/200/320ms) + named easing; prevents animation overload.
- **Two-part elevation** — sharp key shadow + soft ambient (replaces the banned `0 4px 6px rgba(0,0,0,.1)`).
- **`:focus-visible`** baseline (Gate 3 numbers) · **container queries** — components respond to their container, not just the viewport (baseline 2026).

---

## J. Psychology of interface design (ethical) + dark-pattern bans

The cognitive science under elite products — *why* the patterns in §F/§G work. Use it to design honestly. The **dark-pattern bans** below are where psychology gets turned *against* the user: instant rewrite, same severity as a critical slop/experience finding. (§F already owns the Doherty threshold, recognition-over-recall, and progressive disclosure — not repeated here.)

### Principles → the design implication
- **Gestalt — proximity / similarity / common region / closure / continuity.** Grouping is read from space, shared style, and shared boundaries: related fields ~24px apart, sections 80px+; same-type controls share one look; a card/fieldset groups better than spacing alone.
- **Hick's law.** Decision time grows with options → show essentials, hide advanced behind "More"; ≤7 top-level nav items.
- **Fitts's law.** Targets are faster when bigger/closer → primary CTA ≥48px, touch ≥44px; separate Delete from Save; primary actions in the thumb zone on mobile.
- **Miller's law / chunking.** Working memory ~7±2 → chunk a 12-field form into three labeled groups; group dashboard metrics by category.
- **Jakob's law.** Users expect your app to work like the ones they already know → follow category conventions (left-sidebar nav, familiar settings); deviate only when it adds clarity.
- **Tesler's law.** Complexity is conserved → absorb it into the system (smart defaults, auto-calculation), don't push it onto the user.
- **Aesthetic-usability effect.** Polish buys leniency for minor friction — but never substitutes for honest interaction (Gate 5 still applies).
- **Von Restorff (isolation).** The distinct item is remembered → exactly one emphasized primary action; don't paint everything the accent color.
- **Serial position (primacy / recency).** First and last are remembered → most-important nav/list items first, next-most last.
- **Peak-end rule.** An experience is judged by its peak and its end → design one delightful moment and a clean, reassuring finish (a confirmed success, not a trail-off).
- **Zeigarnik + goal-gradient.** Unfinished tasks nag and nearness motivates → show "Step 3 of 5" and progress toward completion; never silently abandon an incomplete state.
- **Cognitive load (intrinsic vs. extraneous).** Keep the inherent task as-is; strip the *extraneous* — clutter, jargon, needless steps.
- **Fogg behavior model — B = Motivation × Ability × Prompt.** Put the prompt at the moment of intent, lower the effort, make the value real.
- **Ethical persuasion (Cialdini, applied honestly).** Social proof (*named*, specific — "Trusted by 2,000+ teams", not "loved by millions"); authority (cite the real source/cert); scarcity (only when genuine); loss-aversion & framing (honest, gain-framed); anchoring (with a defensible reference). The signal must be **real**.

### Dark patterns — banned (psychology used against the user)
| Pattern | Tell | Do instead |
|---|---|---|
| Confirmshaming | a guilt-y decline ("No thanks, I hate saving money") | neutral options ("Not now") |
| Forced continuity | silent auto-charge after a trial | explicit opt-in + a reminder before the charge |
| Roach motel | one-click signup, buried cancel | exit as easy as entry |
| Fake urgency | a countdown that resets on reload | only real, stated deadlines |
| Hidden costs | fees revealed only at the last step | show the full total upfront |
| Disguised ads | sponsored content styled as organic | label it "Sponsored" |
| Preselected opt-ins | pre-ticked add-ons / marketing | default unchecked; the user opts in |
| Misdirection / nagging | the user's goal hidden; dismissals ignored | make the intended action prominent; honor "not now" |
| Trick questions | double-negatives that confuse consent | plain, direct language |

---

## K. Compile-clean contract (guaranteed-runnable output)

The output must *run on the first try*, not merely look right — the discipline behind Claude Artifacts (single-file, import-allowlist, no build step) and v0's autofixer (it exists to fix the import/icon/type class post-generation). Lint against this **before** browser-verify (Gate 7), fix every violation, then render.

**Detect the mode first:**
- **Self-contained** — a single artifact, no build step, a preview sandbox: everything inlines; only the preloaded allowlist is importable; the entry component must render with zero required props.
- **Project-scaffold** — the surface lands in an existing app with a bundler: the "allowlist" is *whatever is in `package.json`*; never import a dependency that isn't declared there.

**Import allowlist**
- *Self-contained:* `react` / `react-dom`, and only well-known sandbox/CDN-preloaded libs — `lucide-react` (icons), `recharts` / `d3` (charts), `framer-motion` (motion), `clsx`/`classnames`, `date-fns`, `lodash`. Tailwind via the play CDN or inline styles. Nothing else.
- *Project-scaffold:* only packages already in `package.json`. If a needed lib is absent, either add it explicitly (and say so in the report) or implement without it — never emit a bare import to an undeclared package.
- Icons come from the project's `iconLibrary` (shadcn) or the allowlisted icon set — **never emoji as UI icons**, never an icon import that isn't installed.

**Forbidden patterns (instant fix before verify)**
| Pattern | Why it breaks | Fix |
|---|---|---|
| Import of a non-allowlisted / undeclared package | module-not-found at build | use an allowlisted lib or add the dep explicitly |
| A *named* import the package doesn't export (e.g. a `lucide-react` icon that isn't real) | named-export error — the #1 thing v0's autofixer catches | verify the symbol exists before using it |
| `<link rel=stylesheet>` / `<script src>` to an external URL (self-contained) | blocked in sandbox | inline the styles/script |
| Top-level `fetch`/XHR/WebSocket at module load (sandbox) | network blocked / crash on mount | gate behind an effect or handler; mock the data |
| `localStorage`/`sessionStorage` in a sandboxed artifact | unavailable in the sandbox | use React state |
| Default export with required props | the preview entry renders with none | default the props or make the entry prop-free |
| `class=` in JSX, unclosed/mismatched tags | compile error | `className`; close every tag |
| Apostrophe inside a single-quoted JS/TS string | string terminates early | Phase-3 string rule — double-quote/template the whole value, never touch the apostrophe |
| Undeclared identifier · conditional hook · missing return | TS/JSX won't compile | declare it; hooks at top level; return JSX |

**Pre-verify lint (the builder runs this, then browser-verifies)**
1. Every `import` → allowlisted or in `package.json`? Each *named* symbol real?
2. Grep the diff for the forbidden patterns above.
3. Self-contained: the entry component default-exports and renders with zero props.
4. *Then* run the dev server / browser-verify — the lint kills the import/compile class cheaply; the browser is for runtime + visual.

---

## L. Motion craft (orchestration, beyond the §C duration/ease tokens)

§C gives *atomic* motion (one element's duration + ease). This is the *craft* layer — orchestrated, scroll-aware, performant — for art-direction and any motion-heavy brief. Tokens are the foundation; this is what separates "nice transitions" from production choreography. (Pointer: Gate 5 motion-safety + art-direction mode.)

**Scroll-driven choreography**
- Bind animation progress to scroll only with intent: `scrub` ties scroll% → animation%; *pin* to extend a section's range; trigger relative to the viewport (start when the element is ~80% up).
- Batch entrance: stagger multiple elements *as a group* when they enter the viewport, not each on its own trigger.
- Discrete (play once on enter) vs continuous (scrub with a little lag-smoothing). **Never scroll-jack** — don't fight the user's scroll momentum.

**Timeline orchestration**
- Sequence with **named labels and relative positions** (`"intro"`, `"intro+=0.2"`, `"<"` = with previous, `">"` = after) — not magic-number delays.
- Nest timelines for reuse; let duration/ease defaults inherit downward. Prefer one timeline over many chained `.delay()`s.

**Stagger recipes**
- 50–120ms between items for 3–6 elements; **>200ms reads scattered**. Combine with an ease for a cascade; reverse the order for a last-to-first feel.

**Performance guardrails**
- Animate **`transform` + `opacity` only** (`x`/`y`/`scale`/`rotate`). **Never animate** `width`/`height`/`top`/`left`/`margin`/`padding` — that thrashes layout.
- `will-change: transform` only *while* animating; remove it after. High-frequency followers (cursor): batch with a `quickTo`-style setter, not per-frame React state.

**Motivated motion (the reasoning gate)**
- Before adding any animation, name what it communicates in one sentence: hierarchy (draws attention to the right thing), storytelling (reveals content in a sequence that matches a narrative), feedback (acknowledges a user action), or state transition (shows something changed). "It looked cool" isn't an answer — animating everything because the library is available is a tell, not craft. Can't name the reason → drop the animation.

**Motion-slop tells (instant fix)**
- **Oversaturation** — >3 simultaneous motion types on one element (scale + rotate + skew + …).
- **Timing misalignment** — a stagger that doesn't divide evenly into the duration (reads jittery).
- **Layout thrashing** — animating `width` instead of `scaleX`.
- **Weak reduced-motion** — `prefers-reduced-motion` must *disable* the motion (or swap to a fade), not merely "reduce" it.
- **Decorative scroll rails / progress bars** that clash with the register or overflow heading text.

**Native platform motion (2025-2026, minimal JS)**
- Scroll-driven CSS: `animation-timeline: view()` (reveal-on-scroll) or `scroll()` (scrub), with `animation-range: entry 0% cover 35%`. GPU-cheap, zero library. Gate behind `@supports (animation-timeline: view())`; else IntersectionObserver.
- View Transitions: `document.startViewTransition(cb)` + `view-transition-name` for shared-element morphs; cross-document `@view-transition { navigation: auto }` gives app-like nav on a plain MPA. High signal, hard to copy.
- Enter from first paint: `@starting-style` + `transition-behavior: allow-discrete`; `interpolate-size: allow-keywords` unlocks `height: auto` transitions.

**Smoothing (the "expensive" tell)**
- Never assign a target directly: lerp toward it each frame (`v += (target - v) * 0.15`) for cursor and parallax followers. Lenis for inertial scroll, feeding its progress to scroll-triggers. Smooth-scroll (inertia) is not scroll-jacking (fighting momentum): the first is fine, the second stays banned above.

**Motion personality (pick one per project)**
- Playful / Premium / Corporate / Energetic. Set spring + duration character to match: Premium reads heavier (`{stiffness:120,damping:22}`), Energetic snappier (`{400,35}`). Consistency across the page is the tell.

**Layered motion budget**
- primary (the action) / secondary (supporting) / ambient (background drift). Budget each separately; ambient stays compositor-only (`transform`/`opacity`), never per-frame JS.

**Interruptibility**
- Rapid or gesture-driven motion (toasts, toggles, drags) must retarget from current state, never restart from zero. Use CSS transitions or springs, not keyframes that replay from 0.

**Motion a11y + performance budget (extends Gate 5 / §H)**
- WCAG 2.3.3 Animation-from-Interactions (AAA): interaction-triggered motion must be disableable unless essential; document essential vs decorative.
- Vestibular safety: parallax, zoom, and spin can cause dizziness or nausea; respect the OS reduce-motion setting (natural scroll is exempt).
- INP budget: interactions land in <=200ms (good), >500ms is poor. 60fps = 16.67ms per frame; animate composited props only; measure with DevTools Performance + the Long Animation Frames API.

**Named easing (beyond the §C tokens)**
- ease-out-quart `cubic-bezier(.25,1,.5,1)` for default UI enter; ease-out-expo `(.16,1,.3,1)` for dramatic reveals; a stepped `linear(...)` curve for spring feel. Motion.dev (the Framer Motion successor) for 120fps React springs.

---

## M. Reference-hunt site directory (Gate 2 live lookup)

Live galleries to pull real, current references from during Gate 2 — instead of anchoring off training-data
memory alone. Grouped by what you're hunting for; each site is single-purpose, so pick by need, not habit.

**General / curated galleries** — broad sweeps across categories, start here if the anchor is undecided
- [curated.design](http://curated.design/) — web design
- [godly.website](http://godly.website/) — full sites
- [minimal.gallery](http://minimal.gallery/) — minimal/quiet register
- [catalog.cool](http://catalog.cool/)
- [inspora.design](http://inspora.design/)
- [webpo.space](http://webpo.space/)
- [mindsparklemag.com](http://mindsparklemag.com/)
- [behance.net](http://behance.net/) — broad creative/visual work, not web-specific

**Landing pages / SaaS**
- [landing.love](http://landing.love/)
- [purelanding.page](http://purelanding.page/)
- [saaslandingpage.com](http://saaslandingpage.com/)
- [saaspo.com](http://saaspo.com/) — SaaS websites
- [saasframe.io](http://saasframe.io/)
- [lad-book.com](http://lad-book.com/) — land-book, landing-page inspiration

**Components / patterns** — for a specific piece, not a whole page
- [navbar.gallery](http://navbar.gallery/)
- [cta.gallery](http://cta.gallery/)
- [bentogrids.com](http://bentogrids.com/)
- [ogimage.gallery](http://ogimage.gallery/) — OG/share images
- [component.gallery](http://component.gallery/) — design systems, cross-company pattern comparison

**Motion**
- [appmotion.design](http://appmotion.design/)
- [60fps.design](http://60fps.design/)
- [animejs.com](http://animejs.com/) — animation library, not a gallery

**Mobile**
- [mobbin.com](http://mobbin.com/) — mobile + web app screen flows

**Brand / identity**
- [rebrand.gallery](http://rebrand.gallery/)
- [dieline.com](http://dieline.com/) — packaging design

**Type**
- [uncut.wtf](http://uncut.wtf/) — fonts

**Icons**
- [hugeicons.com](http://hugeicons.com/)

**Portfolio**
- [prettyfolio.com](http://prettyfolio.com/)

**Email**
- [reallygoodemails.com](http://reallygoodemails.com/)

**Imagery / stock**
- [lummi.ai](http://lummi.ai/) — AI-friendly stock photography

**UX flows / maps**
- [uxmaps.co](http://uxmaps.co/)

**AI-agent-specific**
- [styles.refero.design](http://styles.refero.design/) — high-quality DESIGN.md examples written for AI agents; read for token-spec/register-doc format, not visual inspiration
- [vibeindex.dev](http://vibeindex.dev/) — directory of vibe-coding tools

**Component libraries (buildable, not just reference)**
- [ui.aceternity.com](http://ui.aceternity.com/) — React component library for landing pages

**Misc tools**
- [designmd-store.com](http://designmd-store.com/) — templates
- [dynapictures.com](http://dynapictures.com/) — dynamic image generation
- [iloveenhance.com](http://iloveenhance.com/) — AI image enhance
- cosmos — visual bookmarking/moodboard tool (verify current domain before citing)

Use like §A anchors: pick 1-2 sites matching the brief's register, pull 2-3 concrete references, name what's
being stolen (layout, motion, type pairing) — never screenshot-and-clone wholesale.

---

## N. Redesign mode (preserve vs. overhaul vs. greenfield)

Misclassifying redesign mode is the biggest source of bad redesign output — detect it before Phase 0.

- **Greenfield** — no existing site, or a full overhaul is explicitly approved. No preservation constraints.
- **Preserve** — modernize without breaking the brand. Audit first, extract brand tokens, evolve gradually.
- **Overhaul** — new visual language on existing content. Treat visuals as greenfield; preserve content/IA.

If ambiguous, ask once: *"Should this preserve the existing brand, or start visually from scratch?"*

**Audit before touching (preserve/overhaul):** document brand tokens (accent colors, type stack, logo, radii), IA (nav, conversion paths), content blocks (what's doing work vs. filler), patterns to keep (signature interactions, copy voice) vs. retire (slop tells, dead links, perf traps), and the SEO baseline (ranking pages, meta, structured data, OG cards — **SEO migration is the #1 redesign risk**, see §H).

**Preservation rules (preserve mode):** don't change IA/slugs/nav labels/form field names unless asked — it breaks SEO, analytics, autofill, and muscle memory; extract and keep the existing brand color rather than reflexively applying §C/§D palette rules; don't rewrite copy voice unless asked — visual modernization ≠ content rewrite; don't regress existing accessibility wins.

**Modernization levers, in priority order (stop when the brief is satisfied):** 1) typography refresh (biggest lift, lowest risk) → 2) spacing/rhythm → 3) color recalibration (desaturate, unify neutrals, keep the brand accent) → 4) motion layer (§L) → 5) hero/key-section recomposition → 6) full block replacement (only when unsalvageable).

**Targeted evolution vs. full redesign:** IA/content/SEO sound → targeted evolution (levers 1–4), most of the value at a fraction of the risk. Visual debt is structural (broken IA, no system, broken mobile) → full redesign with strict content preservation. Brand itself is changing → greenfield.

---

## O. Characterful anchors, escaping the generic register (2026-08-21)

When a brief says "não quero cara de IA", "com personalidade", "fora do padrão SaaS", or a §A anchor
feels too safe, pull from this pool. These are PRODUCTION systems (2023-2026) whose identity survives
the name-swap test. Values from teardowns (oh-my-design.kr, shadcn.io/design, Figma community): treat
non-official hexes as `// approximate`, confirm against the live product before locking tokens.

### Systems with strong personality

- **Wise** (rebrand 2023, Ragged Edge): lime `#9FE870` sobre forest `#163300`; Wise Sans 900 só em
  display, Inter no produto; pill buttons; "graphic tapestries" de textura colada. Register: fintech
  global product+marketing. Steal: par verde-sobre-verde de alto contraste como identidade inteira.
- **Headspace** (rebrand Italic Studio, 2024): cream `#F9F4F2` + charcoal `#2D2C2B` (nunca preto puro)
  + um azul de ação `#0061EF`; Aperçu custom; radius 8-32 (pill), hairline borders, quase sem sombra.
  Register: wellness/consumer. Steal: calor como estrutura, não decoração.
- **Perplexity** (2024): parchment `#FDFBFA` + teal único `#016A71`; pesos 400-500 apenas (hierarquia
  sem bold); sidebar fixa ~260px, conteúdo max-width 900px. Register: AI product. Steal: "invisible
  brand", identidade por restrição, não por ornamento.
- **Toss** (TDS, fintech coreana): azul `#3182F6`; zero sombras (elevação por opacidade); margens
  30-32px em números financeiros; espaço = segurança. Register: product-app financeiro denso.
- **Cash App**: verde `#00E013` + citron `#D8FF14`; Cash Sans (base Klim/Söhne com pontuação
  arredondada); raios 2px/20px/999px; profundidade por blocos de cor chapados. Register: consumer
  fintech Gen-Z. Steal: tríade de raios disciplinada + flat colorblock.
- **Duolingo** (design.duolingo.com): verde `#58CC02` como ÚNICO saturado permitido em display;
  ilustração geométrica de 4 formas básicas. Register: consumer/edu. Steal: uma cor de progresso, o
  resto neutro.
- **LINE Seed** (seed.line.me, SIL OFL grátis): CJK+Latin harmonizados, 5 pesos; `#06C755`; flat.
  Register: plataforma global multi-idioma. Steal: tipografia própria gratuita com identidade real.
- **Gumroad** (redesign 2021): neo-brutalismo de produção: canvas cream ~`#F4F4F0` `// approximate`,
  contornos pretos grossos, sombras offset duras, cor saturada como pontuação. Register: creator
  commerce anti-SaaS. Caveat de usabilidade: brutalismo caótico derruba task-success em páginas densas.
  Use "disciplined brutalism" (grid firme por baixo do ruído).
- **Nubank** (Nu Sans por Blackletra, 2024; illustration system 3.0 da Polar): transparência como
  conceito; ilustração trust-forward, não cartunesca. Register: fintech LATAM.

### Movimentos vivos em produção (2025-2026)

- **Warm paper / nature distilled**: terra, argila, grão de filme via CSS, formas orgânicas;
  Rifle Paper Co., claude.ai da Anthropic. O contraponto direto ao "AI blandness".
- **Terminal chic / technical mono**: Berkeley Mono/Departure Mono, ASCII/box-drawing como ornamento,
  grids de alto contraste; dev tools indie, security startups. Sinal de credibilidade na subcultura
  builder; crossover mainstream esperado 2026.
- **Neo-brutalismo disciplinado**: Gumroad como poster child; bordas pretas + sombras offset SOBRE
  grid rígido. Evitar em superfícies informacionalmente densas.

### Como usar

Gate 2: quando a direção está aberta e o brief pede personalidade, monte as 2-3 variantes com ≥1
âncora deste pool (ex.: *Perplexity-restraint · Headspace-warm · terminal-chic*), não só
Linear/Stripe. §B continua dono do art-direction extremo; §O é para PRODUTO com identidade.

---

## Sources (condensed)
Dribbble/Mobbin/SaaS-gallery context research, Figma Community + design-system docs (Material 3,
Polaris, Carbon, Fluent 2, Ant, Primer, Mantine, Radix/shadcn), and foundry/editorial trend writeups
(Pangram Pangram, Grilli Type, Klim, Commercial Type; Adobe/Fontfabric/It's Nice That 2026 trend
reports; NN/g neobrutalism). Full URL list in the research run logs. Token specifics for named
products are approximate unless confirmed in that product's own design docs.

2026-06-23 refresh drew on the AI-UI anti-pattern writeups (BSWEN AI-UX anti-patterns; Muzli "why every
AI app looks the same"), AI-chat anatomy guides (Setproduct, thefrontkit), Superhuman's command-palette
notes, Fontfabric's 2026 typography trends + Vercel's Geist Pixel release, the bento-in-2026 critiques,
and primary design docs (Linear design-refresh notes, Aesop, ProPublica typography, Material 3 / m3.material.io).

§F/§G (interaction & experience, 2026-06-23) draw on NN/g's 10 usability heuristics + button-states research,
the Doherty threshold / optimistic-UI + skeleton-vs-spinner writeups (LogRocket, Pencil&Paper), WCAG 2.2
(2.1.2 no-keyboard-trap, 2.5.5 target size, prefers-reduced-motion), the "AI-generated UI is inaccessible by
default" catalogue (Frontend Masters), and destructive-action / empty-state / form-validation-timing pattern
guides (Smashing, Eleken, a11yblog). Exemplar interactions (Linear, Stripe, Raycast, Superhuman, Figma, Gmail)
are illustrative; confirm specifics against each product.

§H (accessibility & SEO, 2026-06-23) draws on the WCAG 2.2 spec + WebAIM checklist (1.1.1 non-text content,
1.3.1 info & relationships, 2.4.1 bypass blocks, 3.3.1 error identification, 4.1.2 name/role/value, 4.1.3
status messages), MDN ARIA live-regions, the semantic-HTML-for-accessible-SEO writeups, Google Search Central
(Core Web Vitals — LCP ≤2.0s as of 2026, mobile-first indexing), schema.org / Rich Results, and the
meta-keywords-are-dead + canonical-best-practice guides. SEO is register-gated to public surfaces.

§I (design systems, 2026-06-23) draws on the primary docs of each system (m3.material.io, Apple HIG,
carbondesignsystem.com, Shopify Polaris, fluent2.microsoft.design, Ant Design, Salesforce SLDS 2, Adobe
Spectrum, GitHub Primer, Atlassian, Uber Base Web, Radix, shadcn/ui, Mantine) and the W3C Design Tokens
Community Group (DTCG first stable spec, Oct 2025) plus the multi-tier-token / density / container-query
writeups. §J (psychology, 2026-06-23) draws on the Laws of UX / IxDF / NN/g treatments of Gestalt, Hick,
Fitts, Miller, Jakob, Tesler, Von Restorff, serial-position, peak-end, Zeigarnik, goal-gradient and the
Fogg model, Cialdini's principles applied ethically, and the FTC/GDPR-flagged dark-pattern taxonomy
(careerfoundry, usercentrics, arXiv). Persuasion is included only in its honest form; manipulation is banned.

§M (reference-hunt site directory) is an operator-curated link list, added 2026-08-13 verbatim from a
personal bookmark set — not independently re-verified per site. Confirm a site still resolves before citing
it as a source in a real anchor decision.
