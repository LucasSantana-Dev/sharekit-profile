# Claude Code Profile: Coding Essentials

This profile demonstrates core principles for using Claude Code effectively. Apply and adapt these rules to your own workflow.

## Think Before Code

1. **Understand before solving.** Read the failing test or spec. Ask what the current state is. Grep for similar patterns. Don't code in a vacuum.
2. **Small wins compound.** One focused change that ships beats three "ambitious" branches that rot. Prefer incremental delivery and early validation.
3. **Simplicity is a feature.** Reach for stdlib before custom code. Use the platform's native features before dependencies. The code you don't write is the code you won't debug.

## Commit Discipline

- **Atomic commits.** One logical unit per commit. A commit should be understandable in isolation and revertible without side effects.
- **Descriptive messages.** Lead with *why*, not what. "Return early to reduce nesting" beats "Add early return." Reference issues if they exist.
- **No merge commits locally.** Rebase before pushing to keep history linear. Exception: true divergent histories that can't fast-forward.

## Code Standards

- **Readability over cleverness.** Future you and your teammates will thank you. If you need a comment to explain the logic, the logic is probably too clever.
- **Consistency matters.** Follow the existing patterns in the repo, even if you'd do it differently on a green field. Uniformity reduces cognitive load.
- **Test what matters.** Write tests for complex logic, edge cases, and the paths users actually hit. One-liners and straightforward pass-throughs often don't need tests.

## PR and Review

- **Ship to review early.** Draft PRs invite feedback. Don't wait for perfection. Smaller diffs are easier to review and faster to land.
- **Respond to feedback specifically.** "Done" is less useful than "moved validation to the caller; check line 42." Quote the code when you change it.
- **Own your code.** If something you wrote breaks after merge, own the fix. The goal is a healthy codebase, not a perfect streak.

## When Stuck

1. Write a failing test or add a log line that isolates the problem.
2. Grep the codebase for similar situations.
3. Read the related code top-to-bottom, not just the failing function.
4. If still stuck after 20 minutes, ask for a second opinion or pair.

## Tools and Patterns

- Use `.claude/standards/` to codify team rules that apply everywhere.
- Use `.claude/tasks/` for large or multi-phase work (ship a feature, migrate a dependency, clean up tech debt).
- Use `.claude/plans/` to sketch out architecture before major refactors.
- Link ADRs in decision-bearing commits so future changes understand the "why."

---

**This is a living document.** Add rules that save you time. Remove rules that create friction. A coding standard that nobody follows is worse than none.
