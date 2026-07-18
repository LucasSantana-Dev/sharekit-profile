---
name: frontend-reference-hunt
description: Search and map visual frontend references from Dribbble, Mobbin, Pinterest, and curated galleries (Awwwards, Godly, Land-book, siteinspire) into a structured reference board covering register, typography, palette, spacing, layout, and named motion archetypes, with steal/avoid notes per reference. Use when a UI task needs real-world visual direction before building ("busca referências", "find design references", "reference hunt", "moodboard pra essa página", "procura no Dribbble/Mobbin", "referências de UI/UX/motion") or when repaint, frontend-craft, or premium-frontend-ui needs its reference-anchor phase fed with live, current references instead of training-data memory. Searches and maps only; does not build UI.
triggers:
  - busca referências visuais
  - find design references
  - reference hunt
  - moodboard
  - procura no dribbble
  - procura no mobbin
  - referências de motion
  - reference board
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.agents/skills/frontend-reference-hunt
---

# Frontend Reference Hunt

Turns "I want it to look premium, not AI-made" into a concrete, current reference board
sourced from real platforms, so build skills anchor on shipped work instead of
training-data averages (the root cause of slop convergence).

## Use When

- A frontend task needs visual direction and no reference board exists yet.
- A build skill (repaint, frontend-craft, ui-expert, premium-frontend-ui) is about to run
  its reference-anchor phase and would otherwise anchor from memory.
- User asks for UI/UX/motion references, a moodboard, or "what does good look like" for a surface.

## Do Not Use When

- References already curated this session (reuse the existing board).
- The task is building or restyling UI itself — hand the board to `repaint` / `frontend-craft`.
- Pure motion implementation questions — `premium-frontend-ui` archetypes may suffice without a hunt.

## Inputs / Prereqs

- Brief: surface type (landing / dashboard / app / component), register (production-credible
  vs art-directed), brand constraints (existing tokens? audience?), motion ambition (none / subtle / immersive).
- Browser: `claude-in-chrome` MCP against the user's Chrome (Mobbin and Pinterest gate most
  content behind the user's logged-in session). Fallback for public pages: WebSearch + WebFetch.

## Workflow

1. **Lock the brief** (4 axes above). If a build skill dispatched this hunt, inherit its
   register lock verbatim; never re-decide register here.
2. **Route platforms by goal** — full URL patterns, query recipes, and per-platform quality
   heuristics in [references/platform-playbook.md](references/platform-playbook.md):
   - Real shipped product UI / UX flows → **Mobbin** (strongest anti-slop signal).
   - Visual direction, type, art-direction polish → **Dribbble** (concept work; steal visuals, distrust feasibility).
   - Broad moodboard, typography, palettes → **Pinterest**.
   - Immersive motion / award-grade → **Awwwards, Godly**. Landing pages → **Land-book, SaaS Landing Page**. Editorial → **siteinspire**.
   Minimum 2 platforms per hunt; one platform = one aesthetic monoculture.
3. **Search** with the playbook's query recipes. Screenshot every candidate
   (claude-in-chrome) into the project's `.claude/design/refs/` (create if missing).
4. **Curate 5–9 references** through the quality gates:
   - Shipped beats concept; recent (≤2y) beats classic unless deliberately retro.
   - Reject anything matching the slop cluster: default purple-gradient-on-dark, glassmorphism
     cards, hero + 3 feature cards, Inter-everywhere, emoji icons.
   - Board must disagree with itself somewhere (two candidate directions), or it is a monoculture.
5. **Extract per reference** into the board (template:
   [references/reference-board-template.md](references/reference-board-template.md)):
   URL + screenshot path, register, typography pairing, palette (sample real values from the
   screenshot), spacing/layout rhythm, motion archetypes by name, **steal** list, **avoid** list.
6. **Emit + hand off**: write `<project>/.claude/design/reference-board-<slug>.md`, then
   state the 2 candidate directions and which one you recommend for the brief. If a build
   skill is waiting, pass the board path as its reference anchor.

## Outputs / Evidence

- `reference-board-<slug>.md` with 5–9 mapped references, screenshots on disk, and a
  recommended direction. Every claim about a reference cites its screenshot.

## Failure / Stop Conditions

- Mobbin/Pinterest walls content and Chrome session is not logged in → surface it, continue
  with the public platforms, and mark the board `coverage: partial`.
- Fewer than 5 usable references after gates → widen the query per playbook before lowering the gates.
- Never present a reference you did not actually open and screenshot this session.

## Load These Resources

- [references/platform-playbook.md](references/platform-playbook.md) — URL patterns, query recipes, quality heuristics, secondary galleries.
- [references/reference-board-template.md](references/reference-board-template.md) — board format the build skills consume.

## Related Skills

- `repaint`, `frontend-craft`, `ui-expert`, `premium-frontend-ui` — consumers of the board (build).
- `ai-slop-audit` — post-build lint; shares the slop-cluster definition.
- `use-my-browser` — the browsing layer this skill drives.

## Memory Hooks

- Read memory for project brand constraints (e.g. Criativaria guia-de-marca) before curating.
- Write memory only if the hunt establishes a durable brand reference direction for a project.
