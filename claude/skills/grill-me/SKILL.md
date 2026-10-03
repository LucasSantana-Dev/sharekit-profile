---
name: grill-me
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me".
triggers:
  - grill me
  - interview
  - stress-test plan
  - stress-test design
  - convergence interview
  - decision exploration
---

# Grill Me

Interview the user one question at a time until shared understanding converges — defined as **being able to predict their reaction to the next three questions you would ask**. If you can predict, you're done. If you can't, ask the next question.

This is a checkable test, not a vibe.

## When to Use

- User says "grill me", "interview me", or "stress-test this plan"
- A design or plan has ambiguity the user hasn't surfaced
- Before committing to a non-trivial implementation, you want the user to articulate trade-offs they haven't named

## When NOT to Use

- Non-interactive contexts (CI, `/loop`, autonomous loops) — flag the underspecified ask as a blocker instead of guessing
- Unambiguous self-contained asks
- User has explicitly prioritized speed over alignment
- ≥95% confidence already exists (don't manufacture doubt)
- Pure information questions ("what does X mean?")
- Mechanical operations (renames, formats, moves)
- Questions the codebase can answer — explore the codebase instead

## Format

Every question uses this shape:

- **Q:** one focused question
- **GUESS:** your hypothesis for the answer + the reasoning behind it

Then wait for the user's reaction before asking the next question.

**Why one at a time:** users can't react to hypotheses buried in a list. Batches encourage skim-reading and lock in the wrong framing for later questions, since later questions depend on earlier answers.

**Why a guess:** users react faster to a wrong guess than they generate answers from scratch. A guess commits you to a falsifiable position and surfaces hidden assumptions. Be visibly willing to be wrong — occasionally guess against expectations to defeat polite-agreement bias.

## Stop Conditions

### Primary stop (success)

The 95% predictive test passes — you can confidently predict the user's reaction to the next 3 questions. Then **restate** in this shape:

- **Outcome:** what success looks like
- **User:** who this serves
- **Why now:** what changed to make this the right time
- **Success:** how you'll know it worked
- **Constraint:** what must hold
- **Out of scope:** what you explicitly aren't building

Then get an explicit "yes" before moving on.

### Non-yes answers that do NOT count as stop signals

- "Whatever you think is best." → delegation, not convergence; re-ask with two concrete framed options
- "Sounds good." → ambiguous; follow up with "Anything you'd refine?"
- "Sure, let's go." → often a polite exit; same follow-up
- Silence then "okay let's start." → user gave up; pause and ask what's missing

### Floor stop (failure to converge)

Several rounds without confidence rising → something foundational is missing. Pause and tell the user:

> "I've asked X questions and I still can't predict your reactions. Something foundational is missing. Want to step back?"

Don't grind on.

## Codebase-First

If a question can be answered by exploring the codebase, explore the codebase instead. Don't ask the user what `git log` or `grep` can answer.
