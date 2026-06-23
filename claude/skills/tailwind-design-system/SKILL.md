---
name: tailwind-design-system
description: Tailwind CSS v4 design-system guidance for tokens, theming, component
  APIs, patterns, and migration choices. Use when shaping or refactoring a Tailwind-based
  design system and the task needs token structure, component conventions, or v4-specific
  implementation guidance.
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.agents/skills/tailwind-design-system
  progressive_disclosure: split
---

# Tailwind Design System (v4)

Use this skill when the task is about system-level Tailwind decisions, not just styling one component.

## Inputs / Prereqs

- Confirm the project is on Tailwind v4 or actively migrating.
- Identify whether the need is token design, component architecture, advanced v4 features, or migration strategy.
- Load only the reference file that matches the active design-system problem.

## Workflow

1. Start with the token and component architecture, not utility churn.
2. Choose the relevant reference for foundations, patterns, advanced v4 features, or migration.
3. Keep the system semantic and reusable instead of hand-tuned per screen.
4. Verify the design-system change against responsive, theming, and component API concerns.

## Outputs / Evidence

- The recommended token, component, or migration structure.
- Exact Tailwind v4 patterns or utilities that fit the request.
- Any tradeoffs or compatibility constraints that matter to the rollout.

## Failure / Stop Conditions

- Do not solve a system problem with ad hoc one-off classes.
- Do not introduce new tokens or variants without clear semantic purpose.
- Do not recommend v4-only features without checking project compatibility.

## Load These Resources

- [foundations.md](./references/foundations.md)
- [component-patterns.md](./references/component-patterns.md)
- [advanced-v4.md](./references/advanced-v4.md)
- [migration-and-practices.md](./references/migration-and-practices.md)

## Memory Hooks

- Read memory when the workspace already has established token or theming rules.
- Write memory only when the session establishes a durable design-system convention.
