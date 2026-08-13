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

## Big rationale belongs in a doc, not a comment block

A short WHY comment (1-3 lines) stays inline, next to the code it explains. But when the
rationale is a paragraph or more — a measured incident, a rejected alternative with numbers,
a multi-step causal chain, a decision with tradeoffs — write it as a doc (ADR, `DECISIONS.md`
entry, or a `docs/`/`references/` file) and leave a one-line pointer comment in the code:

```ts
// See DECISIONS.md 2026-08-09: 8b model hits TPM cap on this project's base prompt.
const GROQ_MODEL = process.env.GROQ_MODEL ?? "llama-3.3-70b-versatile";
```

not the full incident writeup inline. Long comment blocks rot the same way redundant ones
do — they drift from the code as it changes, they're invisible to anyone not reading that
exact file, and they bloat every read of the function. A doc is discoverable, versioned
independently, and doesn't force every future reader of the function to scroll past it.

**Why:** stated directly by the user while reviewing a codebase with deeply-reasoned
multi-paragraph comments (measured latency numbers, rejected model choices, live-incident
postmortems) embedded throughout `src/`. The reasoning was valuable but belonged in the
project's decision record, not inline.

**How to apply:** when writing or translating a comment and it runs longer than ~3 lines or
cites a measured incident/rejected alternative, stop and ask whether this is really a decision
record. If yes, move it to `DECISIONS.md` (or the project's equivalent) and shrink the inline
comment to a pointer + the one fact a reader needs right there (e.g. "70b not 8b: TPM cap").
Applies to new comments and to comments encountered while translating/refactoring existing code.
