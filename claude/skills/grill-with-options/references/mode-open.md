# Open mode (from grill-me)

Use when forks are not yet enumerable: the user has a vague plan and you cannot name the alternatives yet. Interview one question at a time until shared understanding converges, defined as being able to predict the user's reaction to the next three questions you would ask. This is a checkable test, not a vibe.

## Format

Every question has this shape:

- **Q:** one focused question
- **GUESS:** your hypothesis for the answer, plus the reasoning behind it

Then wait for the user's reaction before asking the next question.

Why one at a time: users cannot react to hypotheses buried in a list, and later questions depend on earlier answers. Why a guess: users react faster to a wrong guess than they generate answers from scratch. A guess commits you to a falsifiable position and surfaces hidden assumptions. Be visibly willing to be wrong: occasionally guess against expectations to defeat polite-agreement bias.

Once a fork becomes enumerable (2-4 concrete alternatives), switch to options mode for that fork.

## When NOT to use

- Non-interactive contexts (CI, `/loop`, autonomous loops): flag the underspecified ask as a blocker instead of guessing
- Unambiguous self-contained asks; the user prioritized speed over alignment; >=95% confidence already exists
- Pure information questions ("what does X mean?") and mechanical operations (renames, formats, moves)
- Questions the codebase can answer: explore first (`git log`, `grep`), do not ask

## Stop conditions

### Primary stop (success)

The 95% predictive test passes. Then restate in this shape and get an explicit "yes" before moving on:

- **Outcome:** what success looks like
- **User:** who this serves
- **Why now:** what changed to make this the right time
- **Success:** how you will know it worked
- **Constraint:** what must hold
- **Out of scope:** what you explicitly are not building

### Answers that do NOT count as stop signals

- "Whatever you think is best." Delegation, not convergence: re-ask with two concrete framed options
- "Sounds good." Ambiguous: follow up with "Anything you'd refine?"
- "Sure, let's go." Often a polite exit: same follow-up
- Silence then "okay let's start." The user gave up: pause and ask what is missing

### Floor stop (failure to converge)

Several rounds without confidence rising means something foundational is missing. Pause and say: "I've asked X questions and I still can't predict your reactions. Something foundational is missing. Want to step back?" Do not grind on.
