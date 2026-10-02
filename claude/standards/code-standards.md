# Code Standards

## General

- Prefer clear, boring code over clever abstractions.
- Keep functions small enough to understand without scrolling.
- Avoid speculative features and premature generalization.
- Replace broken patterns instead of layering deprecations.
- Make edge cases explicit.
- Verify libraries before importing: check `package.json` / `pyproject.toml` / `Cargo.toml` first; if missing, decide whether to add it (and which version) or use what exists.
- Match the existing file's naming and formatting conventions; never mix styles within a module. Async, DI and comment rules still apply. Refactor separately.

## signal-first

- Report verdict first, then the top 3 findings inline; with more than 3 non-critical findings, say "X more, ask".
- Never dump full detail when a summary serves the decision. Scale length to the change.
- Signal-first caps detail, not coverage: a real nit still gets a one-line mention or a slot in the "X more" count. Blockers always surface.

## naming

| Context | Convention |
|---|---|
| JS/TS variables, functions, methods | camelCase |
| Classes, types, interfaces | PascalCase |
| Truly immutable constants, env vars | SCREAMING_SNAKE |
| JS/TS file names, CSS classes | kebab-case |
| Python files, variables, functions; DB columns | snake_case |

- Name by what it is or does, not its type: `userList` not `arrayOfUsers`.
- Booleans start with `is`, `has`, `can`, `should`.
- Event handlers start with `on` or `handle`.
- No abbreviations except universal ones (`id`, `url`, `api`, `db`, `ctx`).
- Prefix private members with `_` only when the language lacks access modifiers; otherwise prefer `private`.
- Single-letter generics only when trivial (`T`, `K`, `V`); otherwise descriptive (`TEntity`).
- No noise words (`data`, `info`, `manager`, `helper`, `util`) as standalone suffixes: `UserData` becomes `User`.

## comments

- Default: write no comment. Names carry the what; a comment restating code rots.
- Write one only when the WHY is non-obvious: hidden constraint, bug workaround, invariant the types cannot express, surprising behavior.
  `// bcrypt truncates at 72 bytes; cut first so a suffix cannot pass as valid.`
- Test: would removing it confuse a future reader? If no, delete it.
- Never write: docstrings restating the signature, multi-line blocks explaining a clearly named function, `TODO` without an issue reference, task or PR references (those belong in commits), `removed` / `unused` / `deprecated` markers (delete the code).
- Public APIs and module boundaries get a one-line doc only.
- A comment over about 3 lines, or one citing an incident or rejected alternative, belongs in `DECISIONS.md` (or the project's equivalent); leave a pointer plus the one fact needed.

## dependency injection

- Dependencies flow in: receive what you need, never create or import it inside.
- Prefer constructor injection; for simple functions pass a scoped `deps` argument. Never grow a god `deps` object.
- Use a DI container only when manual wiring is a real burden.
- Inject external I/O (DB, HTTP, mailer, queues), per-environment config, and clocks/random sources needing deterministic tests.
- Do not inject pure utilities, framework internals, or constants.
  `new NotificationService(mailer, db)`, not `new SendgridMailer(process.env.KEY)` inside a method.

## async

- Always `await` Promises; never fire-and-forget unless failure is genuinely unobservable.
- Never mix `.then()` chains and `async/await` in one function.
- Handle errors at boundaries where failure is handled or reported, not around every call; never swallow errors (`catch { return null }`).
- Run independent awaits in parallel: `const [a, b] = await Promise.all([f(), g()])`. Use `allSettled` when you need every result, `all` when any failure aborts.
- `forEach(async ...)` does not await: use `for...of` or `Promise.all(map(...))`.
- Never leave an unhandled rejection: `await` or `.catch()` every escaping Promise.
- Race long awaits against a timeout when latency matters.
- Python: `asyncio.gather()` for parallel coroutines; never call `asyncio.run()` inside a running loop; any function that `await`s is `async`; bridge sync and async callers explicitly.

## python cli (Typer + Rich)

- Split a CLI module past about 200 lines or with unrelated subcommands: one file per domain, registered through a `create_app()` factory with `add_typer`.
- Commands sharing no state go in separate modules; commands using the same manager stay together; 5+ commands in 250+ lines split by manager.
- Exit with `raise typer.Exit(code)`, never `sys.exit()` in a command body.
- Errors go to stderr with a nonzero exit; success output via a `Console`.
- Keep `subprocess` calls and service-name branching out of CLI callbacks: move to a manager/service layer.
- No global state modified by commands: inject via factory params or constructor.
- Put help text in `typer.Option(..., help="...")`.
- Test with `typer.testing.CliRunner` against `create_app()`; inject fake managers through the factory instead of spawning subprocesses.
