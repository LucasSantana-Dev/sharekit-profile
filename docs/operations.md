# Operations — running the flywheel in production

P6 makes the self-improvement loop actually operate: it schedules the cycle,
seeds the trajectory for cold starts, and documents how to read a cycle report
and roll back a regression. This is the operational runbook for the harness.

## Cold start → warm start

A fresh checkout has an empty trajectory (`.harness/runtime/trajectory.jsonl`),
so every improve-track step (diagnose/distill/propose) no-ops. The transition
to a warm start is:

1. **Seed the trajectory** (cold-start fuel only):
   ```bash
   hooks/trajectory-seed.sh            # writes 8 representative events
   hooks/trajectory-seed.sh --status   # event counts by outcome
   ```
   The seed refuses to overwrite a non-empty trajectory — real sessions replace
   it. Once `trajectory-log.sh` (PostToolUse) has written real events during a
   session, do not re-seed.

2. **Run a session.** Every tool call is appended to the trajectory by the
   PostToolUse hook. This is the real fuel; the seed is only for the first
   cycle before any session has run.

3. **Run the cycle:**
   ```bash
   hooks/cycle.sh --target hooks/<file>.sh --eval harness
   ```
   The cycle runs both tracks (maintain + improve) and writes a report to
   `.harness/runtime/cycle-reports/`.

## Scheduling the nightly cycle

The cycle runs on demand by default. To schedule it nightly (macOS launchd):

```bash
# Install for the current project (opt-in; per-project, not global)
scripts/install-scheduler.sh install "$(pwd)"

# Check status
scripts/install-scheduler.sh status

# Trigger one cycle immediately (without waiting for 02:00)
scripts/install-scheduler.sh run

# Uninstall
scripts/install-scheduler.sh uninstall
```

The scheduler runs `cycle.sh --no-maintain --eval harness` nightly at 02:00
local. The maintain track is cheap but noisy in a scheduled run; run it
manually when you want the full sweep. The plist is a template
(`scripts/launchd/flywheel.plist.template`); the install script expands
`__HOME__` and `__ROOT__` and loads it. **The cycle writes to
`.harness/runtime/` which is per-project, so install once per project you want
the flywheel to improve — do not install globally.**

## Reading a cycle report

`hooks/cycle.sh --status` re-prints the last report. Each report has:

- **Summary** — steps passed / failed / skipped, the target, the eval set, the
  proposal id (if one was assembled).
- **Step results** — a table of the 8 steps with status and a one-line note.
  - `pass` = the step produced output.
  - `skip` = the step had nothing to act on (empty trajectory, no candidates).
  - `fail` = the step errored; read its log in `.harness/runtime/cycle-<ts>-<step>.log`.
- **What to do next** — contextual instructions: review the proposal, pass
  `merge_gate`, open a PR, or (on gate failure) read why the regression was
  recorded.

### Interpreting the held-out lift

The gate's step `[4/5]` prints the held-out eval result:

```
eval: PASS (lift=0.667, with=12/12, without=4/12)
```

- **lift** = (with pass rate) − (without pass rate). The `with` variant runs
  the target hooks on each task; `without` simulates the harness absent.
- A positive lift means the harness is doing useful work. The `--admin` fix
  raised the held-out lift from 0.545 to 0.667.
- A negative lift is a **regression** — the gate FAILS, the regression is
  recorded in `history.sh` (non-Markovian), and the proposer reads WHY it
  failed next time.
- The held-out set is one the proposer never sees (evaluator-not-agent). The
  gate auto-runs it via `eval-run.sh --gate-authority`; the proposer cannot.

## Rollback

If a merged change regresses in production, `deploy-watch.sh` auto-reverts to
git HEAD and records the regression:

```bash
hooks/deploy-watch.sh watch    # monitors post-deploy metrics
hooks/deploy-watch.sh revert   # manual revert (auto-backs-up first)
```

The regression is written to `.harness/runtime/iteration-history.jsonl` so the
next propose step reads WHY the prior change failed (non-Markovian full-history
search — the #1 lever).

## The first real cycle (P6)

The first end-to-end cycle ran against the `--admin` bypass fix (a real finding
the eval bench surfaced in P3). Results:

- **Track A (maintain):** memory-consolidate, skill-index (229 skills),
  skill-prune — all pass.
- **Track B (improve):** diagnose (wrote a diagnosis), distill (5 candidates
  staged), propose (targeted the fix), **gate PASS** (held-out lift=0.667,
  with=12/12, without=4/12).

This is the proof the loop works: the eval bench found a real gap, the cycle
proposed a fix, the gate validated it on held-out data the proposer never saw,
and the report instructed the host to pass `merge_gate` and open a PR. Every
load-bearing subsystem fired in sequence.
