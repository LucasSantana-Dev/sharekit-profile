#!/usr/bin/env bats
# tests/cycle-hook.bats - hooks/cycle.sh, the CLI-only flywheel runner (not a lifecycle hook).
# Hermetic: hooks/ is copied into $BATS_TEST_TMPDIR/root and every sibling cycle.sh calls
# (memory-consolidate, skill-index, skill-prune, transcript-scanner, diagnose, distill,
# dispatch, propose, gate, deploy-watch, reflect-retry, textgrad) is REPLACED by a stub that
# appends "name|args" to $LOG and exits 0, or 1 when the name is listed in $STUB_FAIL.
# A stub prints $STUBS/<name>.out when present. So the tests assert cycle.sh's own logic.
# HOME/BRAIN_ROOT live inside the tmpdir and a fake gh guards against network calls.

setup() {
  export REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export FAKE="$BATS_TEST_TMPDIR/root"
  export HOME="$BATS_TEST_TMPDIR/home"
  export BRAIN_ROOT="$BATS_TEST_TMPDIR/brain"
  export LOG="$BATS_TEST_TMPDIR/stub.log"
  export STUBS="$BATS_TEST_TMPDIR/stubs"
  export STUB_FAIL=""
  mkdir -p "$FAKE/hooks" "$FAKE/.harness/runtime" "$HOME" "$BATS_TEST_TMPDIR/bin" "$STUBS"
  cp -R "$REPO_ROOT/hooks/." "$FAKE/hooks/"
  : > "$LOG"
  printf '#!/bin/sh\necho "fake gh called: $*" >&2\nexit 99\n' > "$BATS_TEST_TMPDIR/bin/gh"
  chmod +x "$BATS_TEST_TMPDIR/bin/gh"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  RT="$FAKE/.harness/runtime"
  local s
  for s in memory-consolidate skill-index skill-prune transcript-scanner diagnose distill \
           dispatch propose gate deploy-watch reflect-retry textgrad; do
    cat > "$FAKE/hooks/$s.sh" <<STUB
#!/usr/bin/env bash
echo "$s|\$*" >> "\$LOG"
[ -f "\$STUBS/$s.out" ] && cat "\$STUBS/$s.out"
case ",\$STUB_FAIL," in *,$s,*) exit 1 ;; esac
exit 0
STUB
    chmod +x "$FAKE/hooks/$s.sh"
  done
}

need() { command -v "$1" >/dev/null 2>&1 || skip "$1 not installed (cycle.sh parses logs with it)"; }
cyc() { bash "$FAKE/hooks/cycle.sh" "$@"; }
trajectory() { printf '{"tool":"Bash"}\n' > "$RT/trajectory.jsonl"; }
names() { cut -d'|' -f1 "$LOG" | tr '\n' ' '; }
last_report() { ls -t "$RT"/cycle-reports/cycle-*.md | head -1; }
count() { grep -c "^$1|" "$LOG" || true; }

# --- args -------------------------------------------------------------------

@test "unknown arg exits 2 with a message and runs nothing" {
  need rg
  run cyc --bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"cycle: unknown arg: --bogus"* ]]
  [ ! -s "$LOG" ]
}

@test "there is no help flag: --help is an unknown arg" {
  need rg
  run cyc --help
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown arg: --help"* ]]
}

@test "no-arg run executes the full cycle and exits 0" {
  need rg
  run cyc
  [ "$status" -eq 0 ]
  [[ "$output" == *"flywheel cycle"* ]]
  [[ "$output" == *"cycle complete"* ]]
}

# --- status -----------------------------------------------------------------

@test "--status with no reports prints a notice and exits 0" {
  run cyc --status
  [ "$status" -eq 0 ]
  [[ "$output" == *"no cycle reports yet"* ]]
  [ ! -s "$LOG" ]
}

@test "--status prints the latest cycle report without running any step" {
  need rg
  cyc >/dev/null
  : > "$LOG"
  run cyc --status
  [ "$status" -eq 0 ]
  [[ "$output" == *"# Flywheel cycle report"* ]]
  [ ! -s "$LOG" ]
}

# --- happy path -------------------------------------------------------------

@test "happy path runs steps in documented order via stubs" {
  need rg
  trajectory
  printf 'x\n' > "$BATS_TEST_TMPDIR/target.sh"
  printf 'proposal prop-20261002T1200 at .harness/forge/proposals/p1.md\n' > "$STUBS/propose.out"
  mkdir -p "$FAKE/.harness/forge/proposals"; : > "$FAKE/.harness/forge/proposals/p1.md"
  printf 'lift=0.25\n' > "$STUBS/gate.out"
  run cyc --target "$BATS_TEST_TMPDIR/target.sh" --eval myset
  [ "$status" -eq 0 ]
  [ "$(names)" = "memory-consolidate skill-index skill-prune transcript-scanner diagnose distill dispatch dispatch dispatch dispatch dispatch propose dispatch gate deploy-watch dispatch " ]
}

@test "happy path passes target, eval set and proposal file to gate" {
  need rg
  trajectory
  printf 'x\n' > "$BATS_TEST_TMPDIR/target.sh"
  printf 'proposal prop-20261002T1200 at .harness/forge/proposals/p1.md\n' > "$STUBS/propose.out"
  mkdir -p "$FAKE/.harness/forge/proposals"; : > "$FAKE/.harness/forge/proposals/p1.md"
  cyc --target "$BATS_TEST_TMPDIR/target.sh" --eval myset >/dev/null
  grep -q "^gate|prop-20261002T1200 --target $BATS_TEST_TMPDIR/target.sh --eval myset --proposal $FAKE/.harness/forge/proposals/p1.md$" "$LOG"
}

@test "happy path starts deploy-watch with the held-out lift parsed from the gate log" {
  need rg
  trajectory
  printf 'x\n' > "$BATS_TEST_TMPDIR/target.sh"
  printf 'prop-20261002T1200\n' > "$STUBS/propose.out"
  printf 'lift=0.25\n' > "$STUBS/gate.out"
  run cyc --target "$BATS_TEST_TMPDIR/target.sh"
  [[ "$output" == *"deploy-watch started (baseline heldout-lift=0.25)"* ]]
  grep -q "^deploy-watch|start prop-20261002T1200 $BATS_TEST_TMPDIR/target.sh heldout-lift 0.25$" "$LOG"
}

@test "happy path report lists all nine steps with pass status and post-merge watch hint" {
  need rg
  trajectory
  printf 'x\n' > "$BATS_TEST_TMPDIR/target.sh"
  printf 'prop-20261002T1200\n' > "$STUBS/propose.out"
  printf 'lift=0.25\n' > "$STUBS/gate.out"
  printf 'scanned 7 facts\n' > "$STUBS/memory-consolidate.out"
  cyc --target "$BATS_TEST_TMPDIR/target.sh" >/dev/null
  r="$(last_report)"
  grep -q -- '- steps passed: 8' "$r"
  grep -q -- '- steps failed: 0' "$r"
  grep -q -- '- steps skipped: 0' "$r"
  grep -q '| 1 | memory-consolidate | pass | scanned 7 facts |' "$r"
  grep -q '| 8 | gate | pass | proposal prop-20261002T1200 ready for merge_gate |' "$r"
  grep -q 'Post-merge watch' "$r"
  grep -q 'Improve track passed' "$r"
  grep -q -- '- proposal: `prop-20261002T1200`' "$r"
}

@test "dispatch is driven through intake, four advances, then allow-gate review_gate and a final advance" {
  need rg
  trajectory
  printf 'x\n' > "$BATS_TEST_TMPDIR/target.sh"
  printf 'prop-20261002T1200\n' > "$STUBS/propose.out"
  cyc --target "$BATS_TEST_TMPDIR/target.sh" >/dev/null
  [ "$(grep -c '^dispatch|cycle-[^ ]* --intake cycle proposal for ' "$LOG")" -eq 1 ]
  [ "$(grep -c '^dispatch|cycle-[^ ]* --advance$' "$LOG")" -eq 5 ]
  [ "$(grep -c '^dispatch|cycle-[^ ]* --allow-gate review_gate$' "$LOG")" -eq 1 ]
}

# --- flags ------------------------------------------------------------------

@test "--no-maintain skips track A, records four skips and still runs track B" {
  need rg
  trajectory
  run cyc --no-maintain
  [ "$status" -eq 0 ]
  [[ "$output" == *"track A: skipped (--no-maintain)"* ]]
  [ "$(count memory-consolidate)" -eq 0 ]
  [ "$(count skill-index)" -eq 0 ]
  [ "$(count skill-prune)" -eq 0 ]
  [ "$(count transcript-scanner)" -eq 0 ]
  [ "$(count diagnose)" -eq 1 ]
  [ "$(count distill)" -eq 1 ]
  grep -q '| 1 | memory-consolidate | skip | --no-maintain |' "$(last_report)"
}

@test "--dry-run runs no worker stub, writes a report with dry-run skips and exits 0" {
  need rg
  trajectory
  run cyc --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"mode:    dry-run"* ]]
  [[ "$output" == *"(dry-run) would run: memory-consolidate.sh"* ]]
  [ "$(count memory-consolidate)" -eq 0 ]
  [ "$(count diagnose)" -eq 0 ]
  [ "$(count distill)" -eq 0 ]
  [ "$(count propose)" -eq 0 ]
  [ "$(count gate)" -eq 0 ]
  grep -q '| propose | skipped | dry-run |' "$(last_report)" || grep -q '| 7 | propose | skipped | dry-run |' "$(last_report)"
}

@test "--dry-run still invokes dispatch.sh (intake plus advances); dry-run is not fully side-effect free" {
  need rg
  trajectory
  cyc --dry-run >/dev/null
  [ "$(count dispatch)" -eq 5 ]
}

@test "--target and --eval are echoed in the header and the report" {
  need rg
  run cyc --dry-run --target some/file.sh --eval evset
  [[ "$output" == *"target:  some/file.sh"* ]]
  [[ "$output" == *"eval:    evset"* ]]
  grep -q -- '- target: `some/file.sh`' "$(last_report)"
  grep -q -- '- eval set: `evset`' "$(last_report)"
}

# --- missing / empty state --------------------------------------------------

@test "missing trajectory skips skill-prune, transcript-scan and diagnose but still runs distill" {
  need rg
  run cyc --no-maintain
  [[ "$output" == *"no trajectory log yet"* ]]
  [ "$(count diagnose)" -eq 0 ]
  [ "$(count distill)" -eq 1 ]
  grep -q '| diagnose | skip | no trajectory log |' "$(last_report)"
}

@test "missing trajectory marks skill-prune and transcript-scan as skipped in the report" {
  need rg
  cyc >/dev/null
  [ "$(count skill-prune)" -eq 0 ]
  [ "$(count transcript-scanner)" -eq 0 ]
  grep -q '| skill-prune | skip | no trajectory |' "$(last_report)"
  grep -q '| transcript-scan | skip | no trajectory |' "$(last_report)"
}

@test "empty trajectory file skips skill-prune and transcript-scan but diagnose still runs (-f vs -s mismatch)" {
  need rg
  : > "$RT/trajectory.jsonl"
  cyc >/dev/null
  [ "$(count skill-prune)" -eq 0 ]
  [ "$(count transcript-scanner)" -eq 0 ]
  [ "$(count diagnose)" -eq 1 ]
}

@test "no target and no proposal id: propose --auto runs and gate is skipped" {
  need rg
  trajectory
  printf 'assembled 3 proposals\n' > "$STUBS/propose.out"
  run cyc
  [ "$status" -eq 0 ]
  grep -q '^propose|--auto$' "$LOG"
  [ "$(count gate)" -eq 0 ]
  [[ "$output" == *"propose --auto assembled 3 proposal(s)"* ]]
  [[ "$output" == *"no proposal to gate"* ]]
  grep -q '| propose | pass | auto: 3 proposals |' "$(last_report)"
  grep -q '| gate | skip | no proposal |' "$(last_report)"
}

@test "propose --auto failing is recorded as skip with no candidates" {
  need rg
  trajectory
  STUB_FAIL=propose run cyc
  [ "$status" -eq 0 ]
  [[ "$output" == *"no targets to propose for"* ]]
  grep -q '| propose | skip | no candidates |' "$(last_report)"
}

@test "nonexistent --target file records propose skip with target not found" {
  need rg
  trajectory
  run cyc --target "$BATS_TEST_TMPDIR/missing.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"target file not found"* ]]
  [ "$(count propose)" -eq 0 ]
  grep -q '| propose | skip | target not found |' "$(last_report)"
}

@test "propose output without a prop id leaves gate skipped" {
  need rg
  trajectory
  printf 'x\n' > "$BATS_TEST_TMPDIR/target.sh"
  printf 'garbage output\n' > "$STUBS/propose.out"
  cyc --target "$BATS_TEST_TMPDIR/target.sh" >/dev/null
  [ "$(count gate)" -eq 0 ]
}

@test "malformed sibling output (no counters) falls back to zero counts without crashing" {
  need rg
  trajectory
  printf 'unparseable nonsense\n' > "$STUBS/skill-index.out"
  run cyc
  [ "$status" -eq 0 ]
  grep -q '| skill-index | pass | indexed 0 skills |' "$(last_report)"
}

# --- failure propagation ----------------------------------------------------

@test "failing diagnose is recorded as fail, later steps still run, exit stays 0" {
  need rg
  trajectory
  STUB_FAIL=diagnose run cyc
  [ "$status" -eq 0 ]
  [[ "$output" == *"diagnose failed (rc=1"* ]]
  [ "$(count distill)" -eq 1 ]
  r="$(last_report)"
  grep -q '| diagnose | fail | rc=1' "$r"
  grep -q -- '- steps failed: 1' "$r"
  grep -q 'Failures present' "$r"
}

@test "failing distill is recorded as fail and propose still runs" {
  need rg
  trajectory
  STUB_FAIL=distill run cyc
  [ "$status" -eq 0 ]
  [ "$(count propose)" -eq 1 ]
  grep -q '| distill | fail | rc=1' "$(last_report)"
}

@test "failing maintain steps are recorded as skip, not fail" {
  need rg
  trajectory
  STUB_FAIL=memory-consolidate,skill-index,skill-prune,transcript-scanner run cyc
  [ "$status" -eq 0 ]
  r="$(last_report)"
  grep -q '| memory-consolidate | skip | no memory dir / empty |' "$r"
  grep -q '| skill-index | skip | no catalog |' "$r"
  grep -q '| skill-prune | skip | no catalog/trajectory |' "$r"
  grep -q '| transcript-scan | skip | no trajectory |' "$r"
  grep -q -- '- steps failed: 0' "$r"
}

@test "failing propose for an explicit target is recorded as fail and gate is skipped" {
  need rg
  trajectory
  printf 'x\n' > "$BATS_TEST_TMPDIR/target.sh"
  printf 'prop-20261002T1200\n' > "$STUBS/propose.out"
  STUB_FAIL=propose run cyc --target "$BATS_TEST_TMPDIR/target.sh"
  [ "$status" -eq 0 ]
  [ "$(count gate)" -eq 0 ]
  grep -q '| propose | fail | rc=1 |' "$(last_report)"
}

@test "failing gate records fail, runs reflect-retry then textgrad, and blocks dispatch" {
  need rg
  trajectory
  printf 'x\n' > "$BATS_TEST_TMPDIR/target.sh"
  printf 'prop-20261002T1200\n' > "$STUBS/propose.out"
  printf 'gate failed: lift-below-threshold\n' > "$STUBS/gate.out"
  STUB_FAIL=gate run cyc --target "$BATS_TEST_TMPDIR/target.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"gate FAILED"* ]]
  [ "$(count deploy-watch)" -eq 0 ]
  grep -q "^reflect-retry|$BATS_TEST_TMPDIR/target.sh prop-20261002T1200 gate failed: lift-below-threshold$" "$LOG"
  grep -q "^textgrad|$BATS_TEST_TMPDIR/target.sh prop-20261002T1200$" "$LOG"
  grep -q '^dispatch|cycle-[^ ]* --block gate regression on held-out eval$' "$LOG"
  grep -q '| gate | fail | regression recorded' "$(last_report)"
}

@test "gate failure with a max-retry cap parks dispatch BLOCKED and skips textgrad" {
  need rg
  trajectory
  printf 'x\n' > "$BATS_TEST_TMPDIR/target.sh"
  printf 'prop-20261002T1200\n' > "$STUBS/propose.out"
  printf 'retry 3/3 MAX RETRY CAP\n' > "$STUBS/reflect-retry.out"
  STUB_FAIL=gate run cyc --target "$BATS_TEST_TMPDIR/target.sh"
  [[ "$output" == *"max-retry cap hit"* ]]
  [ "$(count textgrad)" -eq 0 ]
  grep -q "^dispatch|cycle-[^ ]* --block max-retry cap on $BATS_TEST_TMPDIR/target.sh$" "$LOG"
}

@test "without --target no proposal id is derived so gate, reflect-retry and textgrad are never reached" {
  need rg
  trajectory
  printf 'prop-20261002T1200\n' > "$STUBS/propose.out"
  # propose --auto does not capture a proposal id, so the gate step is skipped without --target.
  STUB_FAIL=gate run cyc
  [ "$(count gate)" -eq 0 ]
  [ "$(count reflect-retry)" -eq 0 ]
  [ "$(count textgrad)" -eq 0 ]
}

@test "failing reflect-retry is advisory: textgrad is not run and exit stays 0" {
  need rg
  trajectory
  printf 'x\n' > "$BATS_TEST_TMPDIR/target.sh"
  printf 'prop-20261002T1200\n' > "$STUBS/propose.out"
  STUB_FAIL=gate,reflect-retry run cyc --target "$BATS_TEST_TMPDIR/target.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"reflect-retry: nothing to reflect on"* ]]
  [ "$(count textgrad)" -eq 0 ]
}

@test "failing dispatch never aborts the cycle" {
  need rg
  trajectory
  printf 'x\n' > "$BATS_TEST_TMPDIR/target.sh"
  printf 'prop-20261002T1200\n' > "$STUBS/propose.out"
  STUB_FAIL=dispatch run cyc --target "$BATS_TEST_TMPDIR/target.sh"
  [ "$status" -eq 0 ]
  [ "$(count gate)" -eq 1 ]
}

@test "missing dispatch.sh falls back to calling propose and gate directly" {
  need rg
  trajectory
  printf 'x\n' > "$BATS_TEST_TMPDIR/target.sh"
  printf 'prop-20261002T1200\n' > "$STUBS/propose.out"
  rm "$FAKE/hooks/dispatch.sh"
  run cyc --target "$BATS_TEST_TMPDIR/target.sh"
  [ "$status" -eq 0 ]
  [ "$(count propose)" -eq 1 ]
  [ "$(count gate)" -eq 1 ]
  [ "$(count dispatch)" -eq 0 ]
}

# --- report -----------------------------------------------------------------

@test "report is written under .harness/runtime/cycle-reports and per-step logs exist" {
  need rg
  trajectory
  cyc >/dev/null
  [ -f "$(last_report)" ]
  ls "$RT"/cycle-*-diagnose.log >/dev/null
  ls "$RT"/cycle-*-memory-consolidate.log >/dev/null
}

@test "report states the invariants and the no-commit guarantee" {
  need rg
  cyc >/dev/null
  r="$(last_report)"
  grep -q 'No commits were made' "$r"
  grep -q 'Key invariants' "$r"
  grep -q 'deterministic routing: dispatch.sh owns state transitions' "$r"
}

@test "report on a cold start flags skipped steps and omits the proposal section" {
  need rg
  cyc >/dev/null
  r="$(last_report)"
  grep -q 'Skipped steps' "$r"
  ! grep -q 'Review the proposal' "$r"
}

@test "cycle leaves the fake HOME untouched and makes no gh call" {
  need rg
  trajectory
  cyc >/dev/null
  [ ! -e "$HOME/.claude" ]
  ! grep -q '^gh|' "$LOG"
}
