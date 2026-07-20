# Commenting Policy

**Rule**: Write no redundant comments. Code should explain itself through well-named identifiers. A comment that restates what the code already says is noise that rots and misleads. Self-documenting code is the goal; comments fill the gaps that code cannot fill.

## Default: write no comment

Well-named identifiers explain what the code does. A comment that says the same thing as the code is noise that rots.

```ts
// Bad — restates the code
// Increment the counter
counter++;

// Bad — names the caller
// Called by AuthService.login()
function validatePassword(hash: string, input: string): boolean { ... }
```

## Write a comment when the WHY is non-obvious

```ts
// Delay matches the debounce window in the upstream API — removing this causes
// duplicate events on slow connections. See issue #412.
await sleep(300);

// bcrypt has a 72-byte input limit; truncate before hashing to avoid silent
// truncation that would accept any suffix after byte 72 as a valid password.
const truncated = password.slice(0, 72);
```

Good comment triggers: a hidden constraint, a specific bug workaround, an invariant the type system can't express, behavior that would surprise a reader.

## Never write

- Docstrings that restate the function signature (`@param id — the user id`)
- Multi-line comment blocks explaining what the function does when the name is clear
- `// TODO` without a ticket/issue reference — it will never be done
- References to current tasks or PRs (`// added for the auth refactor`) — those belong in commit messages, not source
- `// removed`, `// unused`, `// deprecated` markers — delete the code instead

## When documentation IS needed

For public APIs, library entrypoints, or non-obvious configuration, a single-line description is enough. Use JSDoc/docstrings only at module boundaries consumed by other teams or published packages.

```ts
/** Returns null if the token is expired or malformed. */
function parseAuthToken(token: string): Payload | null { ... }
```

## The test: would removing the comment confuse a future reader?

If no → don't write it. If yes → write it, and make it explain the constraint, not the mechanics.
