---
name: error-handling-audit
description: Focused one-call audit of the unhappy path — swallowed/mishandled errors, resource leaks (handles, timers, listeners, unbounded caches), and secrets/stack-traces leaking on error paths. Framework-aware (won't flag Prisma-pooled connections, discord.js auto-cleanup, supervised uncaught-exception). Scope-tightenable (path / --changed / --category / --severity); read-only/advisory. Use when you want JUST error+leak signal fast (e.g. a risky module, remote-driving) — for a full multi-dimension review use /code-review, which also covers this.
user-invocable: true
argument-hint: "[<path> | --changed] [--category errors,leaks,disclosure] [--severity low|med|high] [--budget N]"
metadata:
  type: skill
  status: stable
---

# Error-Handling Audit

The unhappy path is where bugs hide: the `catch` that swallows, the connection that's
never closed when that `catch` fires, the token that lands in the error log. This is a
**focused one-call lens** over exactly those three failure families. **Read-only** — it
reports the fix and routes to `/refactor`; it never edits.

Its failure mode is noise (every codebase has *some* error handling), so it **scopes
first** and is **framework-aware** — see the don't-flag list below.

## When to use this vs `/code-review`

`/code-review` is the full multi-dimension review (correctness, security, architecture,
perf, leaks, …) and **already covers this domain**. Reach for `error-handling-audit` when
you want *only* the unhappy-path signal, fast — a targeted pass on a risky module, or
remote-driving where a full review is too much. **Don't run both on the same diff** —
pick the depth you need. If you find yourself always wanting the full picture, just use
`/code-review`.

## Auto-invocation triggers

"check error handling", "are we leaking <connections/handles/listeners>", "does this
clean up on failure", "are we swallowing errors", "is anything sensitive in our error
logs", or `/error-handling-audit [scope]`. In a PR review default to `--changed`.

## Scope — tighten before auditing

Pick the narrowest scope that answers the question. **Never sweep the whole repo
unprompted** — state the chosen scope in one line, then audit:

| Option | Effect |
| --- | --- |
| `<path>` | audit one file/dir |
| `--changed` / `--diff` | only the working diff / `main..HEAD` (**default in review**) |
| `--category errors,leaks,disclosure` | one family only |
| `--severity high` | floor out the low-confidence findings |
| `--budget N` | cap at top-N by severity×reach |

Default with no scope: `--changed` if there's a diff, else ask for a path.

## Detection catalog

### Tier 1 — report with confidence (high signal)

| Family | Pattern | Fix |
| --- | --- | --- |
| errors | **Floating promise** — a promise statement neither awaited, `.catch()`-ed, nor `void`-ed | `await` it, or `void`/`. catch()` with intent |
| errors | **Throwing a non-Error** (`throw "msg"` / reject with a string) — loses stack + type | `throw new Error(msg)` |
| errors | **Rethrow that drops the cause** — `catch (e) { throw new Error(...) }` with no `{ cause: e }` | `throw new Error(msg, { cause: e })` |
| leaks | **Resource opened, not closed on all paths** — file/socket/stream/manual DB or Redis client with no `finally`/`using`/disposer; closed on success but not on throw | close in `finally` / `using` / `try-with-disposer` |
| leaks | **Per-request / per-event `setInterval`/`setTimeout` never cleared** — timer created in a handler, no `clearInterval` on exit | store the id, clear in `finally`/teardown |
| disclosure | **Stack trace or raw error object sent to the client** — `res.json(err)` / `err.stack` in a response | generic message to client; full detail to server logs (a `correlationId` is the bridge) |

### Tier 2 — report only with corroborating context

| Family | Pattern | Only flag when |
| --- | --- | --- |
| errors | **Empty catch** | no rethrow, no return, no fallback assignment inside — a true swallow |
| errors | **Catch that only logs, then continues** | execution proceeds in a broken state (no return/abort, uses a now-invalid value) |
| leaks | **Listener on a long-lived emitter, never removed** | the emitter outlives the subscription AND it's not the framework's own auto-cleaned client (see below) |
| leaks | **Unbounded Map/cache growth** | written on an unbounded key (e.g. user/guild id) with no eviction or size cap |
| disclosure | **Secret interpolated into an error message/log** | a real credential/token (not a test fixture/example); pair with entropy/pattern check |

## What is NOT a finding (framework-aware — don't flag)

Flagging these is the noise that makes an audit worthless. Skip them:

- **ORM/driver-pooled connections** (Prisma, Drizzle, `pg` Pool, ioredis) — the pool owns
  the lifecycle; you don't manually close per-query. Only flag a **manually** opened client.
- **Framework clients that auto-clean on teardown** (discord.js `Client`, most server
  frameworks) — listeners registered on them are cleaned on `destroy`/shutdown.
- **Missing `process.on('uncaughtException'|'SIGTERM')`** when a supervisor (PM2, systemd,
  Docker, k8s) restarts the process — that's a valid architecture. At most an INFO note for
  graceful-shutdown, never a leak finding.
- **Intentional fire-and-forget** explicitly marked (`void doThing()`) or commented.
- **Defensive/diagnostic logging gated by `NODE_ENV`** — not a disclosure leak.
- **App-lifetime timers/listeners** set up once at boot and meant to live for the process.

## Excluded (runtime territory — name as a pointer, not a finding)

Memory leaks (retained references/closures), connection-pool **starvation under load**,
stream backpressure, third-party-library listener accumulation, broad PII-field scanning.
These need profiling/load, not a static read — point the user to `/observe` + heap
dumps / `clinic.js` rather than emitting a low-confidence finding.

## Output

Severity-ranked, evidence-first. Per finding: `[TIER/SEV]` · `file:line` · the bug in one
line · the fix · **confidence + the check you ran** (e.g. "grepped for a matching
`clearInterval` / `.release()` — none on the throw path"). Lead with a verdict
(`Unhappy-path: 1 HIGH, 2 MED in <scope>` or `Clean — error/leak paths look sound`).
Signal-first: >3 non-critical findings → show top 3, then "N more — ask for the full list."

## Stop / negative rules

- Scope first; refuse a whole-repo sweep unless asked; default `--changed`.
- **Verify before reporting** — grep for the matching cleanup (`finally`/`clearInterval`/
  `.release()`/listener removal) before claiming a leak. "Looks unhandled" is not evidence.
- Respect the don't-flag list — framework-managed lifecycles are not bugs.
- Read-only. Propose; never edit. Route accepted findings to `/refactor`.
- Don't double-run with `/code-review` on the same diff — it covers this dimension.

## Related

- `/code-review` — full multi-dimension review (this is the focused subset) · `/refactor` — apply an accepted fix · `/observe` — runtime leak/memory profiling (what this skill defers) · `/secure` — deeper secret/credential handling and code security checks · `/coupling-map` — structural view before a cleanup.
- Built 2026-06-06 via `/research-and-decide` as a deliberate override: code-review already covers this domain; kept as a separate *focused* lens. Revisit if it produces noise or goes unused → fold into code-review. See `standards/decisions/2026-06-06-error-handling-audit-skill.md`.
