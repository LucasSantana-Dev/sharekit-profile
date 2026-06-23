---
name: using-git-worktrees
description: Create isolated git worktrees for feature work that should not reuse
  the current workspace. Use when the task needs branch isolation, a clean baseline,
  or multiple branches checked out at once.
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.agents/skills/using-git-worktrees
---









# Using Git Worktrees

Use this skill to create an isolated workspace without disturbing the current checkout.

## Use When

- New feature work should not reuse the current working tree.
- The task needs a clean branch baseline before implementation.
- Multiple branches must be open simultaneously.

## Do Not Use When

- The change is tiny and the current workspace is already safe to reuse.
- The repository is not a git checkout.
- The task only needs branch switching, not a second workspace.

## Inputs / Prereqs

- The repository root and desired branch name.
- Whether the current working tree must stay untouched.
- The project's setup or bootstrap command if a new worktree will need it.
- `scripts/worktree_preflight.py` plus `references/directory-selection.md` and `references/common-mistakes.md` when needed.

## Workflow

1. Run `python3 scripts/worktree_preflight.py` from the repository root to capture the current branch, dirty state, existing worktree directories, and active worktrees.
2. Choose the worktree base directory using the preflight output and `references/directory-selection.md`.
3. Create the worktree on the target branch without disturbing the current checkout.
4. Run only the minimal setup needed for the new workspace.
5. Verify the new worktree starts from the expected clean baseline before implementation begins.

## Outputs / Evidence

- The chosen worktree path and target branch.
- Preflight evidence covering dirty state, existing worktrees, and directory choice.
- Any setup command that was required before work could start.

## Failure / Stop Conditions

- Stop if the repository is dirty in a way that makes worktree creation unsafe.
- Stop if the target branch or directory choice is ambiguous and preflight does not resolve it.
- Do not guess a global worktree location when project-local guidance exists.

## Load These Resources

- `scripts/worktree_preflight.py`
- `references/directory-selection.md`
- `references/common-mistakes.md`

## Memory Hooks

- Read memory only if the repository has a durable worktree convention that changes the directory choice.
- Do not write memory unless the session establishes a new long-lived worktree rule.
