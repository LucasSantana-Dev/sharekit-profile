# `/impeccable fix`

Auto-diagnose design issues and execute fixes in sequence.

Run critique on a target (page, component, or file), map findings to design commands, propose an execution sequence, and run all fixes with a single user approval.

**Use when:** the user describes a vague problem ("this dashboard is hard to use" or "this form is ugly"), the interface needs polish across multiple dimensions (layout + typography + color), or you're blocked waiting for explicit feedback but can infer the most impactful next steps.

**Do not use for:** deep strategic work that requires user input before implementation (use `craft` → `shape` instead), or when the target needs only one or two specific fixes (just run `polish` or `typeset` directly).

## Prerequisites

Same as `critique`:

- PRODUCT.md loaded and non-empty.
- DESIGN.md loaded (strongly recommended).
- Target is a real file, component, or page in the project.
- Browser and network available if visual inspection is needed.

If any are missing, stop and ask the user to run prerequisites before continuing.

## Step 1: Run critique on target

```bash
npx impeccable critique <target>
```

Capture the full critique output: priority issues, heuristic scores, specific findings under each heuristic.

If critique fails or returns no actionable findings, report: "No design issues detected. The target is production-ready." Ask the user if they'd like to run `polish` for final refinement instead.

## Step 2: Parse priority issues

Extract the top 3–5 priority issues from the critique output. For each, identify:
- **Category:** Layout, Typography, Color, Interaction, Copy, Accessibility, Performance, Responsive, Hierarchy, or Clarity.
- **Severity:** Critical (blocks usability), High (impacts most users), Medium (affects some users), Low (nice to have).
- **Specific finding:** The exact quote or observation from critique.

Group by category. If multiple findings fall under the same category, combine them into a single entry.

## Step 3: Map findings to command sequence

Use the issue-to-command table below. For each finding category, assign:
- **Primary command:** The most direct fix for this category.
- **Secondary commands:** Often-paired fixes that reinforce the primary.

| Category | Primary | Secondary |
|---|---|---|
| Layout issues (spacing, alignment, grid, nesting) | `layout` | `polish`, `distill` |
| Typography (hierarchy, scale, contrast, line length) | `typeset` | `clarify`, `layout` |
| Color (palette, contrast, saturation, accessibility) | `colorize` | `polish`, `audit` |
| Copy (labels, error messages, microcopy, tone) | `clarify` | `harden`, `onboard` |
| Interaction (buttons, states, feedback, affordance) | `harden` | `animate`, `delight` |
| Accessibility (ARIA, contrast, focus, alt text) | `audit` | `harden`, `adapt` |
| Performance (load time, animation smoothness, render) | `optimize` | `audit` |
| Responsive (mobile, tablet, breakpoint issues) | `adapt` | `layout`, `polish` |
| Visual hierarchy (emphasis, contrast, focus) | `layout` or `typeset` | `colorize`, `distill` |
| Clarity (confusion, mental model, instruction) | `clarify` | `onboard`, `harden` |

Cross-reference: if the user's original task was vague (e.g., "make this better"), defer to the sequencing rule below.

## Step 4: Propose execution sequence

Order the mapped commands using this rule:

**Sequencing rule:** `layout` → `typeset` → `colorize` → `clarify` → `harden` → (personality passes: `animate`, `delight`, `bolder`) → `adapt` → `optimize` → `audit`.

**Rationale:** Layout first (structure), then typography (hierarchy), color (mood), copy (clarity), and behavior (interaction). Personality passes add delight. Finally, adapt for devices and measure performance.

If secondary commands are suggested, interleave them at their natural position in the sequence (e.g., `polish` after `layout`, `audit` before final check).

**Example:** If findings map to `typeset`, `clarify`, and `colorize`, propose: `layout` (optional touch-up) → `typeset` → `colorize` → `clarify` → `harden` (if interaction issues arose).

## Step 5: Present findings and ask for approval

Output a summary to the user:

```
## Design Issues Found

[List the 3–5 priority issues with severity, category, and specific findings]

## Proposed Fix Sequence

1. [Command 1]: [Why it's first]
2. [Command 2]: [Why it's second]
...

This sequence will take ~[estimated time] to run. Each step includes a browser verification.

**What would you like to do?**
- **A)** Run all fixes in order
- **B)** Skip specific steps (list them)
- **C)** Run only step [N] (specify which)
- **D)** Custom sequence (provide your own order)
```

Use `AskUserQuestion` to capture the user's choice.

## Step 6: Execute the approved sequence

For each command in the approved sequence:

1. Run the command: `npx impeccable <command> <target>`.
2. Wait for the command to complete.
3. After completion, open the target in the browser and verify visually.
4. Capture a screenshot or note visual changes.
5. If the user requests modifications mid-sequence, pause and apply their feedback before continuing.

Do not skip any approved steps. If a command fails, report the error and ask the user if they'd like to retry or skip.

## Step 7: Final polish pass (optional)

After all commands complete, run one final check:

```bash
npx impeccable audit <target>
```

This ensures no new issues were introduced and the interface meets accessibility and performance standards.

## Step 8: Present summary

Summarize the work done:

```
## Fix Sequence Complete

Commands executed:
- [Command 1]: [Brief result, e.g., "spacing adjusted, visual rhythm improved"]
- [Command 2]: [Result]
...

Visual verification: All changes reviewed in browser.

**Next steps:**
- If satisfied, you can commit and ship.
- If you'd like additional refinement, suggest specific commands (e.g., "Run `delight` to add micro-interactions").
- If you found new issues, we can run another `fix` cycle.

Would you like me to help with anything else?
```

## Fallback: If critique finds no issues

If the target scores well across all heuristics and critique reports no actionable findings:

1. Report: "This interface is already well-designed. Critique found no critical or high-priority issues."
2. Offer alternatives:
   - "Run `/impeccable bolder` to amplify the design" (if it feels safe or restrained).
   - "Run `/impeccable delight` to add personality" (if it's functional but lacks memorable touches).
   - "Run `/impeccable audit` for a final technical quality check" (accessibility, performance, responsive behavior).
3. Ask the user which direction they'd prefer.

## Gotchas

- **Scope creep:** If the target is huge (entire app), ask the user to scope it to a single page or component. `fix` works best on focused targets.
- **Missing DESIGN.md:** If DESIGN.md is not present, nudge the user to run `/impeccable document` first. Proceed anyway, but note that color and typography fixes may be less on-brand.
- **Interrupted sequences:** If the user pauses mid-sequence or asks for custom changes, save their feedback and apply it to the remaining steps. Do not re-run completed commands.
- **No browser available:** If you cannot open a browser, ask the user to visually verify changes themselves. Proceed without screenshots.
