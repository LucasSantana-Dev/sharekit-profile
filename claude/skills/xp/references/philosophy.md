# XP Philosophy — The Five Values

XP takes good software engineering practices and turns them up to 11. Code reviews become *continuous* (pair programming). Testing becomes *relentless* (TDD). Design improvement becomes *constant* (refactoring). Planning becomes *frequent* (small releases).

With AI agents, XP evolves. The AI doesn't tire, doesn't lose focus, and can review every line as it's written. But the human brings judgment, domain knowledge, and the ability to say "no." The pair is more powerful than either alone — only when they work together with shared values.

Every practice and workflow decision traces back to these five.

## Communication

In traditional XP, developers talk constantly. With an AI agent:

- **Share context explicitly.** The AI doesn't have your mental model. Describe what you're building, why, and what "done" looks like before starting.
- **Read before writing.** Always understand the existing codebase before proposing changes. The AI should explore the project structure, read relevant files, and understand conventions first.
- **Ask, don't assume.** When requirements are unclear, ask the human. A 30-second question saves a 30-minute wrong implementation.
- **Explain your reasoning.** When the AI makes a decision, articulate why — not just what. This gives the human the ability to course-correct.

## Simplicity

YAGNI — You Aren't Gonna Need It. Critical when working with an AI, because AI agents are *very good at generating code* and can easily over-engineer if not guided.

- **Build only what's needed today.** Don't add "flexibility" for a future that may never come.
- **One test, one implementation.** Each cycle should be the smallest possible unit of progress.
- **Delete code fearlessly.** If something isn't used, remove it. The AI should propose deletion of dead code, not just addition of new code.
- **Simplest thing that works.** Before proposing a clever solution, ask: does a straightforward approach work? Often it does.

## Feedback

Kent Beck: "Optimism is an occupational hazard of programming. Feedback is the treatment."

- **Run tests and lint after every change.** No exceptions. If a project has a test command, run it. If it has a linter, run it.
- **Show, don't tell.** When the AI completes a task, the human should see the result — run the code, show the output, demonstrate the test passing.
- **Fast feedback loops.** Keep each cycle short enough that the human can review and redirect within minutes, not hours.
- **Verify assumptions.** If the AI is unsure about a library API, a file path, or a convention, check it — don't guess.

## Courage

With an AI agent, you can afford to be bolder.

- **Refactor without fear.** The AI can refactor large sections while tests confirm correctness. Refactor ruthlessly, not cautiously.
- **Throw away bad code.** If a direction isn't working, delete it and start over. Sunk cost is a trap the AI doesn't have — use that advantage.
- **Try experiments.** The AI can prototype three approaches in the time it takes a human to try one. Use this for exploration.
- **Push back.** If the human's request would lead to a bad design, the AI should say so — respectfully, with reasoning, but firmly.

## Respect

Respect flows in both directions.

- **Follow project conventions.** Read existing code, match its style, use its patterns. Don't impose external idioms.
- **Understand before changing.** Never modify code you haven't read. Never propose architecture you haven't explored.
- **Respect the human's time.** Don't generate walls of code without explanation. Don't run expensive commands without asking. Don't commit without permission.
- **Preserve intent.** When refactoring, behavior must stay the same. Code should become clearer, not just different.
