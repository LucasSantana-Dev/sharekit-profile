# Reference Board Template

Write to `<project>/.claude/design/reference-board-<slug>.md`. Build skills consume this
format as their reference anchor; keep field names stable.

```markdown
# Reference Board — <surface> (<project>)

date: <YYYY-MM-DD>
brief: <surface type> · <register> · <brand constraints> · motion: <none|subtle|immersive>
coverage: full | partial (<which platform walled>)
platforms: <list actually searched>

## Direction A — <name, e.g. "quiet editorial">
<2-3 sentence characterization. Which references below belong to it.>

## Direction B — <name>
<same>

**Recommendation:** <A|B> because <fit to brief, 1-2 sentences>.

---

## R1 — <name> (<platform>)
- url: <link>
- screenshot: .claude/design/refs/<file>.png
- register: <production-credible | art-directed> · <mood adjectives, max 3>
- typography: <display face / body face, weights, scale feel>
- palette: <sampled values from screenshot, hex or oklch, 3-6 swatches, which is dominant>
- spacing/layout: <grid, density, rhythm — e.g. "12-col, 96px section gaps, sparse">
- motion: <named archetypes observed, or "static">
- steal: <2-4 concrete elements worth taking>
- avoid: <1-2 things in this reference NOT to take, and why>

## R2 — ...
(repeat, 5-9 total)
```

Rules:

- `palette` values come from sampling the screenshot, not from guessing brand colors.
- `steal`/`avoid` are mandatory per reference; a reference with nothing to avoid was not
  looked at critically.
- Two named directions minimum. If every reference points one way, the hunt was a
  monoculture; go back and widen.
