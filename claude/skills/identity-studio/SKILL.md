---
name: identity-studio
description: "Take a product with a weak or partial visual identity from diagnosis to shipped UI: owner diagnosis, recognition board, a mark if missing, two directions on a design canvas, a language guide, surface-by-surface review, an ADR, then code through repaint. Use when an app has no identity or only a logo, looks generic or AI-made, or starts or rebrands its visual language."
user-invocable: true
auto-invoke: "sem identidade, não tem identidade visual, só tem o logo, app parece genérico, cara de IA, criar identidade visual, linguagem visual, rebrand, no visual identity, looks generic, looks AI-made, only has a logo, create a design language"
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.claude/skills/identity-studio
mcp_servers: [rag-index]
---

# identity-studio

The workflow behind a 2026 design canvas whose owner called it the best frontend the
project had shipped. It turns "we only have a logo and a color" into a language
that is unmistakably the product's, reviews every surface with the owner, records the
decisions, and only then builds. The method is repaint's Gate 1
([identity-language.md](../repaint/references/identity-language.md)); this composite adds the
order, the gates between phases and the canvas practice. Phases 1 and 5 read repaint's
references instead of invoking repaint, because repaint has no gate-only mode; Phase 7 invokes it.

## When this fires

- The owner says the product has no identity, only has a logo, or looks generic / AI-made.
- A product starts or rebrands its visual language.
- Not for one component or a polish that keeps the existing style: plain `repaint`.

## Workflow

### Phase 0: Classify the starting point (recall)
```bash
test -n "${RAG_HOME:-}" || [ -d "$HOME/.sqlrecall" ] || [ -d "$HOME/.shelfmark" ] || echo "BLOCKED: no recall index, RAG/vault unreachable"
```
```
rag_query(query="<product> identidade visual marca decisão do dono", top=6, scope_types=["memory"])
```
Read DESIGN.md, design ADRs, brand memories and branches. Classify:
- **none**: no mark, no language. All phases.
- **mark-only**: final mark, no language. Skip Phase 2.
- **direction chosen**: the owner already picked a direction, language unwritten (for
  example, a retro kit already on a branch). Quote the recorded pick; Phase 1 only inventories artifacts; skip
  Phases 2-3; start building at Phase 4.
- **language exists**: hand to `repaint`; report Phases 1-6 skipped.

Name the decision owner and whether they are reachable. Feeds Phase 1: class, owner, prior
decisions with dates. **Done when:** class and owner are written down.

### Phase 1: Diagnose and board (reference read: repaint Gate 1)
Read identity-language.md §1-§2. Write `docs/design/identity-brief.md`: the owner's diagnosis
quoted, official artifacts with paths and hashes, 2-3 candidate themes from the product's
world, each with one genre reference for form and written exclusions. With the owner reachable,
put the themes on repaint's recognition board (6-9 existing pieces plus the candidates,
answered by number; repaint/SKILL.md, "Owner anchor by recognition").
Feeds Phase 3: the two themes the owner picked. **Done when:** the brief exists and the owner
answered the board by number, or (no owner) the strongest theme is stated as an assumption.

### Phase 2: Make the mark (logo-design | conditional)
Skip for mark-only and direction chosen. Feeds Phase 3: mark files and usage rule.
**Done when:** the owner approved a mark, or the skip is reported with the reason.

### Phase 3: Show two directions (design canvas | conditional)
Build the two picked themes as directions A and B at both widths with real names and content
(examples marked), same content in both. Canvas practice and scripts:
[canvas-playbook.md](references/canvas-playbook.md). Both rejected: repaint's stop rule, back
to the board, run `repaint/scripts/check_brief.py`. Feeds Phase 4: the pick, quoted.
**Done when:** the owner picks one in their own words.

### Phase 4: Write the language guide (composite logic)
One guide board plus DESIGN.md with an **Identity** section (source, theme and its genre
reference, exclusions, signature family, from the brief and the pick), so repaint later
reports `Identity: inherited`. Then palette in shades with exceptions that carry meaning, type
scale, shapes, controls, the medium's craft grid when it has one, motion that works still.
Feeds Phase 5: DESIGN.md, the only tokens surfaces may use.
**Done when:** the guide board is published and DESIGN.md matches it.

### Phase 5: Review surface by surface (owner loop)
Surfaces are the pages plus the product's non-web surfaces (bot embeds, share cards, app
icon, emails), each at its native size; pages at 390 and 1440, each with its own hero variant.
Before showing, run identity-language.md §7 with this skill's scripts. Owner reactions follow
repaint's rejection-to-rule loop (DESIGN.md and memory, same turn).
Feeds Phase 6: approved surfaces, rules learned, open facts.
**Done when:** every in-scope surface is approved or listed as pending with the owner's words.

### Phase 6: Record the decisions (adr-write)
ADR citing each owner quote with date, marking what was relayed, listing amended ADRs.
Feeds Phase 7: ADR path and PR link. **Done when:** the ADR PR is open.

### Phase 7: Build (repaint)
Per surface or wave in the ADR's order. The brief for each cites its approved canvas surface
as the recorded anchor. Feeds Phase 8: PRs with 390/1440 prints.
**Done when:** each PR shows prints and repaint's reconciliation has no critical open.

### Phase 8: Capture (knowledge-loop)
Rules learned, owner decisions, asset locations. **Done when:** memory written and pushed.

## Reconciliation

Each row ends with one of `✅ DONE`, `🚫 DECLINED`, `🚧 BLOCKED`, `⚠️ DONE_WITH_CONCERNS`.
```
IDENTITY STUDIO - <product>
  Classify:        <none|mark-only|direction chosen|language exists; owner, reachable Y/N> <token>
  Diagnose:        <brief path; board answer by number | assumption> <token>
  Mark:            <files | (skipped: <reason>)> <token>
  Directions:      <canvas link or local boards; pick quoted | (skipped: direction chosen)> <token>
  Language guide:  <board + DESIGN.md Identity section> <token>
  Surfaces:        <approved N / pending N (why)> <token>
  Record:          <ADR path, PR link> <token>
  Build:           <PRs | (skipped: <reason>)> <token>
  Capture:         <memory paths> <token>
  Snapshot:        <memory or handoff path>
  Open watch:      <facts to confirm, assets pending, owner answers>
```

## Stop conditions

- **Stop if:** owner reachable but silent on the board or the directions.
  `BLOCKED: no owner pick / Missing: the owner's answer by number or in words / Next: send the
  board or canvas link`. Snapshot and stop; never start Phase 4 on a guess.
- **No reachable owner** (autonomous, eval, dispatched builder): never block. Take the source
  from the brief or the strongest domain theme, state it as an assumption, build one direction
  in the same pass, mark Directions `⚠️ DONE_WITH_CONCERNS`. This matches repaint's carve-out.
- **No design canvas tool** (other clients, headless): `BLOCKED: no canvas / Missing: a Design
  artifact / Next: local boards`. Build the directions as local HTML, screenshot both widths,
  send the images; the .dc.html scripts do not apply. Continue with Directions `⚠️`.
- **Official art unreachable** (CSP, login): upload local copies as assets; every download
  needs the owner's explicit ok. No ok: `BLOCKED: assets / Missing: owner ok / Next: ask`.
- Recall index unreachable: say so, continue without recall, never claim recall ran.

## Negative rules

- Do NOT skip the reconciliation block, even when the chain stops early.
- Do NOT copy another client's look (another product's posters, a pixel grid) into a product whose world
  differs; copy the method only. Medium rules apply only when the product has that medium.
- Do NOT let an industry anchor or a trend become the identity; it governs structure only.
- Do NOT start Phase 7 before the ADR PR exists.
- Do NOT invent facts about real people (roles, dates, bios); unknown stays "to confirm".
