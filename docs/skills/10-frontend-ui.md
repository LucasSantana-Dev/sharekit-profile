# Frontend & UI Skills

`ui-expert` for production-quality interfaces; `ai-slop-audit` after any AI-generated UI to catch anti-patterns. `design-build` (composite) for the full design-to-verified-in-browser loop. `shadcn` + `tailwind-design-system` for component and token work.

---

## /ui-expert

Build production-grade frontend interfaces that look like Linear, Vercel, Stripe, or Notion — not generic LLM output.

**Builds:**
- Production-quality UI (not AI-generic)
- Design system compliance
- Responsive layouts (mobile, tablet, desktop)
- Accessible interactions (keyboard, screen readers)
- Smooth animations + transitions

**Anti-patterns rejected:**
- Gradient backgrounds everywhere
- Over-saturated colors
- Identical feature cards (.map() loops with no variation)
- Cheesy stock imagery
- "AI-made" visual patterns

**When to use:** Building professional interfaces; design polish pass

**Output:** Production-quality UI components

---

## /ui-audit

UI/UX design system reference and focused review — patterns, palettes, typography, layout heuristics.

**Audits:**
- Color palette (contrast, saturation, semantic use)
- Typography (font scale, hierarchy, line length)
- Spacing (padding, margin, grid consistency)
- Layout patterns (sidebar, main, modal, etc.)
- Component library consistency

**When to use:** Design system review; UI polish pass

**Output:** Design audit + recommendations

---

## /frontend-design

Create bold, art-directed frontend interfaces for explicitly creative or expressive work.

**Modes:**
- Editorial (narrative anchors, custom layouts)
- Experimental (breaking conventions, exploring new patterns)
- Motion-heavy (animations, transitions, micro-interactions)
- Unforgettable (memorable, distinctive visual voice)

**When to use:** Creative brief; "kill the cliché"; art direction required

**Output:** Bold, distinctive UI

---

## /design-build ⭐ **Composite**

Design, scaffold, build, and verify a UI: ui-audit → shadcn/tailwind → impeccable → webapp-testing.

**Phases:**
1. **Audit:** Design system reference + UI review
2. **Scaffold:** Setup shadcn components + Tailwind tokens
3. **Build:** Implement UI in browser
4. **Polish:** Impeccable (a11y, responsive, hierarchy)
5. **Verify:** Webapp-testing (screenshots, interactions, a11y)

**When to use:** Full design-to-verified-in-browser loop

**Output:** Built, verified UI

---

## /shadcn

Manage shadcn components — adding, searching, fixing, debugging, and configuration.

**Operations:**
- Add components: `npx shadcn-ui@latest add`
- Search available components
- Fix component issues (styling, behavior)
- Debug integration
- Update shadcn config

**When to use:** shadcn component management

**Output:** Components installed + configured

---

## /tailwind-design-system

Tailwind CSS v4 design-system guidance for tokens, theming, and component patterns.

**Topics:**
- Color tokens (palette design)
- Typography scale (font sizes, weights, line height)
- Spacing scale (consistent padding/margin)
- Shadow + border tokens
- Dark mode theming
- Component patterns (buttons, cards, forms, etc.)

**When to use:** Design system work; Tailwind configuration

**Output:** Design system reference + token definitions

---

## /nextjs-patterns

Next.js App Router patterns — Server Components, Actions, caching strategies, RSC boundaries, Next.js 16+.

**Patterns:**
- Server Components (default) vs. Client Components (use "use client")
- Server Actions (form submissions, mutations)
- Route caching (default, revalidate, dynamic)
- RSC boundaries (when to use Client Components)
- Streaming + Suspense
- Image optimization

**When to use:** Next.js App Router development

**Output:** Patterns reference + implementation guide

---

## /ai-slop-audit

Post-generation QA pass that lints frontend output against known "AI made that" anti-patterns.

**Flags:**
- Gradient backgrounds + neon colors
- Identical card.map() loops (no variation)
- Over-saturated, cartoonish imagery
- Missing semantic HTML
- Inaccessible interactions
- Cheesy placeholder copy ("Welcome to our amazing platform!")

**When to use:** After any AI-generated UI

**Output:** Slop audit + cleanup checklist

---

## /vercel-patterns

React composition and performance optimization patterns — component libraries, React 19, waterfalls, bundle size.

**Topics:**
- Component composition (composition over props)
- React 19 features (use client, use server, etc.)
- Avoiding waterfalls (parallel data fetching)
- Bundle size optimization (code splitting, tree-shaking)
- Image optimization (Next.js Image)
- Performance metrics (Lighthouse, Web Vitals)

**When to use:** React performance tuning; component architecture

**Output:** Patterns reference + performance guide

---

**Last updated:** 2026-06-25
