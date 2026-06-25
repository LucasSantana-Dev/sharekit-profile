---
name: coverage-gap
description: Find and fill test coverage gaps for a PR by analyzing diffs and writing new tests
user-invocable: true
argument-hint: "<PR_NUMBER> [--repo owner/name]"
metadata:
  owner: lucas-dev
  tier: production
  canonical_source: ~/.agents/skills/coverage-gap
---

Analyze a PR diff, identify new or changed functions without tests, and dispatch a subagent to write focused tests.

## Prerequisites

- GitHub CLI (`gh`) is installed and authenticated
- PR number is provided
- PR branch exists and is up-to-date
- No uncommitted changes in the PR branch (safe-list check)
- Target test framework matches project (Jest, Vitest, pytest, etc.)

## Workflow

1. **Fetch PR diff**: Use `gh pr diff <PR_NUMBER>` to get the full patch
2. **Parse diff**: Identify new or modified functions/methods in the diff:
   - Extract function signatures and line ranges
   - Skip deletions and comments
3. **Cross-reference tests**: Check if corresponding test files exist and cover the functions:
   - For TypeScript: look for `*.test.ts`, `*.spec.ts`, `*.test.tsx`
   - For Python: look for `test_*.py`, `*_test.py`
4. **Identify gaps**: Build a list of untested or under-tested functions
5. **Safe-list check**: Use `git status` to verify no uncommitted changes in the PR branch
6. **Dispatch subagent**: Send a focused prompt to `Agent(model="sonnet")`:
   - Function signature and behavior from the diff
   - Existing test patterns from the project
   - Request: Write tests ONLY (no source code changes)
7. **Push tests**: Commit and push new tests to the PR branch
8. **Report**: Show coverage delta (functions before → functions with tests)

## Safe-list rules

- **Reject if unstaged**: Refuse if PR branch has uncommitted changes (fail fast with clear error)
- **Tests only**: Subagent must never modify source files, only add/update test files
- **Non-destructive**: All changes must be new test additions; no deletions of existing tests

## Usage examples

```bash
# Analyze PR 645 in default repo
/coverage-gap 645

# Analyze PR in specific repo
/coverage-gap 645 --repo <github-user>/Lucky
```

## Output / Evidence

- List of identified gaps: functions without tests
- Subagent prompt (for transparency)
- Confirmation of tests written: file names and line count added
- Coverage delta: "Before: 42 functions, After: 45 functions with tests"
- Link to PR with test commits

## Implementation hints

- Parse unified diff format from `gh pr diff` to extract function names
- Use regex to identify function declarations: `function foo(...)`, `const foo = (...)`, `def foo(...)`, `export class Foo`, etc.
- Build a map of test files and their coverage (simple grep for function names in tests)
- Check for test patterns: describe blocks, test/it calls, @test decorators
- Subagent prompt example:
  ```
  You are a test-writing specialist. Your task is to write tests ONLY.
  
  New functions in PR #645:
  - `validateEmail(email: string): boolean` (src/utils/validation.ts, lines 12-18)
  - `sendNotification(user: User): Promise<void>` (src/services/notification.ts, lines 45-62)
  
  Existing test patterns in the project:
  [include sample test from a similar file]
  
  Write tests for these functions. Output only test code (no source file changes).
  ```
- After subagent completes, commit with message: `test: add coverage for PR #645` and push
- Verify the commit was pushed successfully before reporting

## Failure / Stop conditions

- Stop if `git status` shows uncommitted changes in the PR branch
- Stop if the PR number is invalid or not found
- Stop if the diff cannot be parsed (corrupted or too large)
- Stop if the subagent returns source code changes (safety violation)
