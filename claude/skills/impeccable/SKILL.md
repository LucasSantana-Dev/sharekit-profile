---
name: impeccable
description: Use when the user wants to design, redesign, shape, critique, audit, polish, clarify, distill, harden, optimize, adapt, animate, colorize, extract, or otherwise improve a frontend interface. Covers websites, landing pages, dashboards, product UI, app shells, components, forms, settings, onboarding, and empty states. Handles UX review, visual hierarchy, information architecture, cognitive load, accessibility, performance, responsive behavior, theming, anti-patterns, typography, fonts, spacing, layout, alignment, color, motion, micro-interactions, UX copy, error states, edge cases, i18n, and reusable design systems or tokens. Also use for design-system compliance checks, UI audits, UX framework reviews, or bland designs that need to become bolder or more delightful, loud designs that should become quieter, live browser iteration on UI elements, or ambitious visual effects that should feel technically extraordinary. Not for backend-only or non-UI tasks.
version: 3.1.0
user-invocable: true
argument-hint: "[craft|shape · audit|critique · animate|bolder|colorize|delight|layout|overdrive|quieter|typeset · adapt|clarify|distill · harden|onboard|optimize|polish · teach|document|extract|live] [target]"
license: Apache 2.0. Based on Anthropic's frontend-design skill. See NOTICE.md for attribution.
allowed-tools:
  - Bash(npx impeccable *)
triggers:
  - design ui
  - improve interface
  - polish ui
  - audit ui
---

Designs and iterates production-grade frontend interfaces. Real working code, committed design choices, exceptional craft.

## Setup (non-optional)

Before any design work, pass these gates:

| Gate | Required check | If fail |
|---|---|---|
| Context | PRODUCT.md / DESIGN.md loaded via `node .claude/skills/impeccable/scripts/load-context.mjs` | Run the loader |
| Product | PRODUCT.md exists and is not placeholder | Run `/impeccable teach` |
| Command | Matching command reference loaded | Load the reference |
| Craft | User-confirmed shape brief for this task | Run `/impeccable shape` |
| Image | Visual probes generated or skipped with reason | Resolve before code |

Gates are internal decision trees; never output to the user as status declarations.

**Context gathering**: Load PRODUCT.md (required) and DESIGN.md (optional) via `node .claude/skills/impeccable/scripts/load-context.mjs`. Consume full JSON output. If PRODUCT.md is missing/placeholder: run `/impeccable teach` first.

**Register**: Every task is **brand** (marketing, landing, portfolio: design IS the product) or **product** (app UI, admin, dashboard: design SERVES the product). Load [reference/brand.md](reference/brand.md) or [reference/product.md](reference/product.md).

## Shared design laws

See [reference/design-laws.md](reference/design-laws.md) for the full design laws: color (OKLCH, color strategy axis), theme, typography, layout, motion, absolute bans (side-stripe borders, gradient text, glassmorphism, hero-metric template, identical card grids, modal as first thought), copy rules, and the AI slop test.

Apply to every design, both registers. Match implementation complexity to the aesthetic vision. Interpret creatively. Vary across projects; never converge on the same choices.

## Commands

| Command | Category | Description | Reference |
|---|---|---|---|
| `craft [feature]` | Build | Shape, then build a feature end-to-end | [reference/craft.md](reference/craft.md) |
| `shape [feature]` | Build | Plan UX/UI before writing code | [reference/shape.md](reference/shape.md) |
| `teach` | Build | Set up PRODUCT.md and DESIGN.md context | [reference/teach.md](reference/teach.md) |
| `document` | Build | Generate DESIGN.md from existing project code | [reference/document.md](reference/document.md) |
| `extract [target]` | Build | Pull reusable tokens and components into design system | [reference/extract.md](reference/extract.md) |
| `fix [target]` | Build | Run critique, then auto-sequence and execute fixes | [reference/fix.md](reference/fix.md) |
| `critique [target]` | Evaluate | UX design review with heuristic scoring | [reference/critique.md](reference/critique.md) |
| `audit [target]` | Evaluate | Technical quality checks (a11y, perf, responsive) | [reference/audit.md](reference/audit.md) |
| `polish [target]` | Refine | Final quality pass before shipping | [reference/polish.md](reference/polish.md) |
| `bolder [target]` | Refine | Amplify safe or bland designs | [reference/bolder.md](reference/bolder.md) |
| `quieter [target]` | Refine | Tone down aggressive or overstimulating designs | [reference/quieter.md](reference/quieter.md) |
| `distill [target]` | Refine | Strip to essence, remove complexity | [reference/distill.md](reference/distill.md) |
| `harden [target]` | Refine | Production-ready: errors, i18n, edge cases | [reference/harden.md](reference/harden.md) |
| `onboard [target]` | Refine | Design first-run flows, empty states, activation | [reference/onboard.md](reference/onboard.md) |
| `animate [target]` | Enhance | Add purposeful animations and motion | [reference/animate.md](reference/animate.md) |
| `colorize [target]` | Enhance | Add strategic color to monochromatic UIs | [reference/colorize.md](reference/colorize.md) |
| `typeset [target]` | Enhance | Improve typography hierarchy and fonts | [reference/typeset.md](reference/typeset.md) |
| `layout [target]` | Enhance | Fix spacing, rhythm, and visual hierarchy | [reference/layout.md](reference/layout.md) |
| `delight [target]` | Enhance | Add personality and memorable touches | [reference/delight.md](reference/delight.md) |
| `overdrive [target]` | Enhance | Push past conventional limits | [reference/overdrive.md](reference/overdrive.md) |
| `clarify [target]` | Fix | Improve UX copy, labels, and error messages | [reference/clarify.md](reference/clarify.md) |
| `adapt [target]` | Fix | Adapt for different devices and screen sizes | [reference/adapt.md](reference/adapt.md) |
| `optimize [target]` | Fix | Diagnose and fix UI performance | [reference/optimize.md](reference/optimize.md) |
| `live` | Iterate | Visual variant mode: pick elements in the browser, generate alternatives | [reference/live.md](reference/live.md) |

Plus two management commands: `pin <command>` and `unpin <command>`, detailed below.

### Routing rules

0. **Vague or multi-part request**: enter auto mode — scan project, sequence commands automatically.
1. **No argument**: render the command table, ask what they'd like to do.
2. **First word matches a command**: load its reference file and follow its instructions.
3. **First word doesn't match**: general design invocation — apply setup + design laws + register reference.

If the first word is `craft`, setup runs first, then [reference/craft.md](reference/craft.md) owns the rest.

## Auto Mode

Triggered when a request is vague or multi-part. Instead of asking "which command?", scan the project and suggest a sequenced action plan: context scan → question round → diagnose → propose sequence → execute. If scan reveals nothing, fail safely: ask for `/impeccable teach` and let user pick a command.

## Pin / Unpin

**Pin** creates a standalone shortcut so `/<command>` invokes `/impeccable <command>` directly. **Unpin** removes it.

```bash
node .claude/skills/impeccable/scripts/pin.mjs <pin|unpin> <command>
```