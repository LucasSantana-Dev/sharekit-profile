#!/usr/bin/env bats
# tests/eval-hooks.bats - eval and loop hooks: eval-baseline, eval-tasks, textgrad,
# reflect-retry, tool-shortlist, trajectory-log, trajectory-seed, deploy-watch.
# (cycle.sh is covered separately.) Hermetic: hooks run from a copy of hooks/ in
# $BATS_TEST_TMPDIR (ROOT-relative state lands in the copy), HOME/BRAIN_ROOT point
# inside the tmpdir, and a fake gh on PATH guards against any GitHub/network call.

setup() {
  export REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export FAKE="$BATS_TEST_TMPDIR/root"
  export HOME="$BATS_TEST_TMPDIR/home"
  export BRAIN_ROOT="$BATS_TEST_TMPDIR/brain"
  mkdir -p "$FAKE/hooks" "$FAKE/.harness/runtime" "$HOME" "$BATS_TEST_TMPDIR/bin"
  cp -R "$REPO_ROOT/hooks/." "$FAKE/hooks/"
  printf '#!/bin/sh\necho "fake gh called: $*" >&2\nexit 99\n' > "$BATS_TEST_TMPDIR/bin/gh"
  chmod +x "$BATS_TEST_TMPDIR/bin/gh"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  RT="$FAKE/.harness/runtime"
  FORGE="$FAKE/.harness/forge"
}

hook() { local h="$1"; shift; bash "$FAKE/hooks/$h.sh" "$@"; }
need() { command -v "$1" >/dev/null 2>&1 || skip "$1 not installed"; }
# tool-shortlist uses `declare -A` (bash 4+); skip when the bash on PATH is 3.2.
need_assoc() { bash -c 'declare -A x' >/dev/null 2>&1 || skip "bash on PATH lacks associative arrays (tool-shortlist needs bash 4+)"; }

# --- eval-baseline ----------------------------------------------------------

@test "eval-baseline: init creates an empty eval set" {
  run hook eval-baseline init demo
  [ "$status" -eq 0 ]
  [[ "$output" == *"init: eval set 'demo'"* ]]
  [ -f "$FAKE/.harness/eval/demo/runs.jsonl" ]
  [ ! -s "$FAKE/.harness/eval/demo/runs.jsonl" ]
}

@test "eval-baseline: record appends a JSON run line" {
  hook eval-baseline init demo >/dev/null
  run hook eval-baseline record demo with pass 120 "first run"
  [ "$status" -eq 0 ]
  [[ "$output" == *"recorded: demo with pass 120ms"* ]]
  l="$(cat "$FAKE/.harness/eval/demo/runs.jsonl")"
  [ "$(printf '%s' "$l" | jq -r '.variant')" = "with" ]
  [ "$(printf '%s' "$l" | jq -r '.ms')" = "120" ]
  [ "$(printf '%s' "$l" | jq -r '.note')" = "first run" ]
}

@test "eval-baseline: record on an unknown set fails with exit 1" {
  run hook eval-baseline record nope with pass 1
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found; run init first"* ]]
}

@test "eval-baseline: record with missing args fails with exit 1" {
  hook eval-baseline init demo >/dev/null
  run hook eval-baseline record demo with
  [ "$status" -eq 1 ]
  [[ "$output" == *"record requires"* ]]
}

@test "eval-baseline: compare reports pass rate and average ms per variant" {
  hook eval-baseline init demo >/dev/null
  hook eval-baseline record demo with pass 100 >/dev/null
  hook eval-baseline record demo with fail 300 >/dev/null
  hook eval-baseline record demo without pass 50 >/dev/null
  run hook eval-baseline compare demo
  [ "$status" -eq 0 ]
  [[ "$output" == *"with: 1/2 pass (0.50), avg 200ms"* ]]
  [[ "$output" == *"without: 1/1 pass (1.00), avg 50ms"* ]]
}

@test "eval-baseline: compare shows 0 runs for a variant with none" {
  hook eval-baseline init demo >/dev/null
  hook eval-baseline record demo with pass 100 >/dev/null
  run hook eval-baseline compare demo
  [[ "$output" == *"without: 0 runs"* ]]
}

@test "eval-baseline: gate passes and logs a decision when lift meets threshold" {
  hook eval-baseline init demo >/dev/null
  hook eval-baseline record demo with pass 10 >/dev/null
  hook eval-baseline record demo without fail 10 >/dev/null
  run hook eval-baseline gate demo 0.5
  [ "$status" -eq 0 ]
  [[ "$output" == *"lift=1.000"* ]]
  [[ "$output" == *"PASS"* ]]
  [ "$(jq -r '.result' "$RT/review-decisions.jsonl")" = "pass" ]
}

@test "eval-baseline: gate fails with exit 1 and logs a fail decision when lift is below threshold" {
  hook eval-baseline init demo >/dev/null
  hook eval-baseline record demo with pass 10 >/dev/null
  hook eval-baseline record demo without pass 10 >/dev/null
  run hook eval-baseline gate demo 0.1
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL"* ]]
  [ "$(jq -r '.result' "$RT/review-decisions.jsonl")" = "fail" ]
}

@test "eval-baseline: gate without runs for both variants fails with exit 1" {
  hook eval-baseline init demo >/dev/null
  hook eval-baseline record demo with pass 10 >/dev/null
  run hook eval-baseline gate demo 0.1
  [ "$status" -eq 1 ]
  [[ "$output" == *"need >=1 run each"* ]]
}

@test "eval-baseline: no command or unknown command exits 1 with usage" {
  run hook eval-baseline
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown command"* ]]
}

# --- eval-tasks -------------------------------------------------------------

@test "eval-tasks: count all equals seen plus heldout and is non-zero" {
  all="$(hook eval-tasks count)"
  seen="$(hook eval-tasks count --split seen)"
  held="$(hook eval-tasks count --split heldout)"
  [ "$all" -gt 0 ]
  [ "$seen" -gt 0 ]
  [ "$held" -gt 0 ]
  [ "$all" -eq $((seen + held)) ]
}

@test "eval-tasks: list prints tab-separated rows and honors --split" {
  run hook eval-tasks list --split heldout
  [ "$status" -eq 0 ]
  [[ "$output" == *"dp-drop-table"$'\t'"heldout"$'\t'"check-dangerous-patterns.sh"$'\t'"block"* ]]
  [[ "$output" != *"dp-rmrf-root"* ]]
}

@test "eval-tasks: show prints the task JSON for a known id" {
  run hook eval-tasks show dp-rmrf-root
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r '.expected')" = "block" ]
  [ "$(printf '%s' "$output" | jq -r '.input.tool_input.command')" = "rm -rf /" ]
}

@test "eval-tasks: show for an unknown id prints nothing and exits 0" {
  run hook eval-tasks show no-such-task
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "eval-tasks: show without an id exits 1" {
  run hook eval-tasks show
  [ "$status" -eq 1 ]
  [[ "$output" == *"show requires <id>"* ]]
}

@test "eval-tasks: every emitted task is valid JSON with a block or allow verdict" {
  run bash -c "bash '$FAKE/hooks/eval-tasks.sh' emit | jq -e 'select(.expected==\"block\" or .expected==\"allow\") | .id' | wc -l | tr -d ' '"
  [ "$status" -eq 0 ]
  [ "$output" = "$(hook eval-tasks count)" ]
}

@test "eval-tasks: unknown command exits 1 with usage" {
  run hook eval-tasks bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage:"* ]]
}

# --- reflect-retry ----------------------------------------------------------

@test "reflect-retry: stages a reflection with the failure context and records history" {
  run hook reflect-retry some/target.sh prop-1 "latency regressed"
  [ "$status" -eq 0 ]
  [[ "$output" == *"reflection staged:"* ]]
  [[ "$output" == *"retry 1/3"* ]]
  f="$(ls "$FORGE"/reflections/*-reflection.md)"
  grep -q 'fail reasons: latency regressed' "$f"
  [ "$(jq -r '.event' "$FORGE"/reflections/*-reflection.jsonl)" = "reflection" ]
  [ "$(jq -r '.status' "$RT/iteration-history.jsonl")" = "reflected" ]
}

@test "reflect-retry: appends to the trajectory only when it already exists" {
  hook reflect-retry t.sh p1 why >/dev/null
  [ ! -f "$RT/trajectory.jsonl" ]
  : > "$RT/trajectory.jsonl"
  hook reflect-retry t.sh p2 why >/dev/null
  [ "$(jq -r '.outcome' "$RT/trajectory.jsonl")" = "reflected" ]
}

@test "reflect-retry: no target exits 2 with usage" {
  run hook reflect-retry
  [ "$status" -eq 2 ]
  [[ "$output" == *"requires <target>"* ]]
}

@test "reflect-retry: --status says no reflections yet on a fresh tree" {
  run hook reflect-retry --status
  [ "$status" -eq 0 ]
  [ "$output" = "no reflections yet" ]
}

@test "reflect-retry: --status prints the last staged reflection" {
  hook reflect-retry t.sh p1 "boom" >/dev/null
  run hook reflect-retry --status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Reflection"* ]]
  [[ "$output" == *"boom"* ]]
}

@test "reflect-retry: --count without a target exits 2" {
  run hook reflect-retry --count
  [ "$status" -eq 2 ]
}

@test "reflect-retry: --count is 0 when there is no history" {
  run hook reflect-retry --count t.sh
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "reflect-retry: --count counts reflections back to the last gate PASS" {
  need tac
  h="$RT/iteration-history.jsonl"
  printf '%s\n' '{"target":"t.sh","status":"reflected"}' '{"target":"t.sh","status":"gated"}' \
    '{"target":"t.sh","status":"reflected"}' '{"target":"t.sh","status":"reflected"}' \
    '{"target":"other.sh","status":"reflected"}' > "$h"
  run hook reflect-retry --count t.sh
  [ "$output" = "2" ]
}

@test "reflect-retry: refuses a fourth reflection after the max retry cap, exit 0" {
  need tac
  h="$RT/iteration-history.jsonl"
  for i in 1 2 3; do printf '%s\n' '{"target":"t.sh","status":"reflected"}' >> "$h"; done
  run hook reflect-retry t.sh p9 why
  [ "$status" -eq 0 ]
  [[ "$output" == *"MAX RETRY CAP hit"* ]]
  [ -z "$(ls "$FORGE"/reflections/ 2>/dev/null)" ]
}

# --- textgrad ---------------------------------------------------------------

@test "textgrad: no target exits 2 with usage" {
  run hook textgrad
  [ "$status" -eq 2 ]
  [[ "$output" == *"requires <target>"* ]]
}

@test "textgrad: skips gracefully with exit 0 when there is no reflection" {
  printf 'x\n' > "$BATS_TEST_TMPDIR/t.sh"
  run hook textgrad "$BATS_TEST_TMPDIR/t.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no reflection"* ]]
  [ -z "$(ls "$FORGE"/gradients/)" ]
}

@test "textgrad: skips gracefully when the target file does not exist" {
  mkdir -p "$FORGE/reflections"; printf 'r\n' > "$FORGE/reflections/a-reflection.md"
  run hook textgrad "$BATS_TEST_TMPDIR/missing.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"target not found on disk"* ]]
  [ -z "$(ls "$FORGE"/gradients/)" ]
}

@test "textgrad: stages a gradient anchored on the reflection and records history" {
  mkdir -p "$FORGE/reflections"; printf 'anchor body\n' > "$FORGE/reflections/a-reflection.md"
  printf 'echo target-content\n' > "$BATS_TEST_TMPDIR/t.sh"
  run hook textgrad "$BATS_TEST_TMPDIR/t.sh" prop-7
  [ "$status" -eq 0 ]
  [[ "$output" == *"textual gradient staged:"* ]]
  [[ "$output" == *"anchored on reflection: a-reflection.md"* ]]
  md="$(ls "$FORGE"/gradients/*-gradient.md)"
  grep -q 'anchor body' "$md"
  grep -q 'echo target-content' "$md"
  [ "$(jq -r '.proposal_id' "$FORGE"/gradients/*-gradient.jsonl)" = "prop-7" ]
  [ "$(jq -r '.status' "$RT/iteration-history.jsonl")" = "gradient" ]
}

@test "textgrad: --status says no gradients yet on a fresh tree" {
  run hook textgrad --status
  [ "$status" -eq 0 ]
  [ "$output" = "no gradients yet" ]
}

@test "textgrad: --status prints the last staged gradient" {
  mkdir -p "$FORGE/reflections"; printf 'r\n' > "$FORGE/reflections/a-reflection.md"
  printf 'x\n' > "$BATS_TEST_TMPDIR/t.sh"
  hook textgrad "$BATS_TEST_TMPDIR/t.sh" >/dev/null
  run hook textgrad --status
  [ "$status" -eq 0 ]
  [[ "$output" == *"Textual gradient"* ]]
}

# --- tool-shortlist ---------------------------------------------------------

@test "tool-shortlist: hook mode writes a sidecar listing the matched tool and logs it" {
  need rg; need_assoc
  run bash -c "printf '%s' '{\"prompt\":\"please run a shell command\"}' | bash '$FAKE/hooks/tool-shortlist.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"tools matched; shortlist at"* ]]
  grep -q -- '- Bash' "$RT"/shortlist-*.md
  [ "$(jq -r '.event' "$RT/tool-shortlists.jsonl")" = "tool-shortlist" ]
}

@test "tool-shortlist: records the tool name on PreToolUse input without a prompt" {
  need rg; need_assoc
  run bash -c "printf '%s' '{\"tool_name\":\"Edit\"}' | bash '$FAKE/hooks/tool-shortlist.sh' 2>&1"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.event' "$RT/tool-shortlists.jsonl")" = "tool-used" ]
  [ "$(jq -r '.tool' "$RT/tool-shortlists.jsonl")" = "Edit" ]
  [ -z "$(ls "$RT"/shortlist-*.md 2>/dev/null)" ]
}

@test "tool-shortlist: empty stdin exits 0 and writes nothing" {
  need rg; need_assoc
  run bash -c "printf '' | bash '$FAKE/hooks/tool-shortlist.sh' 2>&1"
  [ "$status" -eq 0 ]
  [ ! -f "$RT/tool-shortlists.jsonl" ]
}

@test "tool-shortlist: malformed JSON stdin exits 0 and writes nothing" {
  need rg; need_assoc
  run bash -c "printf '%s' 'not json {' | bash '$FAKE/hooks/tool-shortlist.sh' 2>&1"
  [ "$status" -eq 0 ]
  [ ! -f "$RT/tool-shortlists.jsonl" ]
}

@test "tool-shortlist: suggest lists matching tools and records the event" {
  need rg; need_assoc
  run hook tool-shortlist suggest "fetch a url over http"
  [ "$status" -eq 0 ]
  [[ "$output" == *"- WebFetch"* ]]
  [ "$(jq -r '.matched' "$RT/tool-shortlists.jsonl")" -ge 1 ]
}

@test "tool-shortlist: suggest with no prompt exits 2" {
  need rg; need_assoc
  run hook tool-shortlist suggest
  [ "$status" -eq 2 ]
  [[ "$output" == *"requires a <prompt>"* ]]
}

@test "tool-shortlist: --status says no shortlist events on a fresh tree" {
  need_assoc
  run hook tool-shortlist --status
  [ "$status" -eq 0 ]
  [ "$output" = "no shortlist events yet" ]
}

@test "tool-shortlist: --status reports the event count after a suggest" {
  need rg; need_assoc
  hook tool-shortlist suggest "edit the file" >/dev/null
  run hook tool-shortlist --status
  [[ "$output" == *"shortlist events: 1"* ]]
}

# --- trajectory-log ---------------------------------------------------------

tlog() { printf '%s' "$1" | bash "$FAKE/hooks/trajectory-log.sh" 2>&1; }

@test "trajectory-log: successful tool call is logged with outcome success" {
  need rg
  run tlog '{"tool_name":"Read","tool_input":{"file_path":"a"},"tool_response":{"ok":true}}'
  [ "$status" -eq 0 ]
  [ "$(jq -r '.tool' "$RT/trajectory.jsonl")" = "Read" ]
  [ "$(jq -r '.outcome' "$RT/trajectory.jsonl")" = "success" ]
  [ "$(jq -r '.event' "$RT/trajectory.jsonl")" = "tool-call" ]
}

@test "trajectory-log: is_error response is tagged error" {
  need rg
  tlog '{"tool_name":"Bash","tool_input":{"command":"x"},"tool_response":{"is_error":true}}' >/dev/null
  [ "$(jq -r '.outcome' "$RT/trajectory.jsonl")" = "error" ]
}

@test "trajectory-log: BLOCKED response is tagged blocked" {
  need rg
  tlog '{"tool_name":"Bash","tool_input":{"command":"x"},"tool_response":"BLOCKED by policy"}' >/dev/null
  [ "$(jq -r '.outcome' "$RT/trajectory.jsonl")" = "blocked" ]
}

@test "trajectory-log: oversized response is truncated to 2048 bytes" {
  need rg
  big="$(head -c 5000 /dev/zero | tr '\0' 'a')"
  tlog "{\"tool_name\":\"Read\",\"tool_response\":\"$big\"}" >/dev/null
  [ "$(jq -r '.response | length' "$RT/trajectory.jsonl")" -le 2048 ]
}

@test "trajectory-log: empty stdin exits 0 and still appends one event" {
  need rg
  run tlog ''
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$RT/trajectory.jsonl" | tr -d ' ')" = "1" ]
}

@test "trajectory-log: malformed JSON exits 0 and appends a parseable event" {
  need rg
  run tlog 'not json {'
  [ "$status" -eq 0 ]
  jq -e '.event == "tool-call"' "$RT/trajectory.jsonl" >/dev/null
}

# --- trajectory-seed --------------------------------------------------------

@test "trajectory-seed: seeds a mixed trajectory when none exists" {
  run hook trajectory-seed
  [ "$status" -eq 0 ]
  [[ "$output" == *"wrote 8 representative event(s)"* ]]
  [ "$(wc -l < "$RT/trajectory.jsonl" | tr -d ' ')" = "8" ]
  [ "$(jq -r 'select(.outcome=="blocked") | .tool' "$RT/trajectory.jsonl" | wc -l | tr -d ' ')" = "2" ]
}

@test "trajectory-seed: refuses to overwrite an existing non-empty trajectory" {
  printf '{"real":1}\n' > "$RT/trajectory.jsonl"
  run hook trajectory-seed
  [ "$status" -eq 0 ]
  [[ "$output" == *"refusing to overwrite"* ]]
  [ "$(cat "$RT/trajectory.jsonl")" = '{"real":1}' ]
}

@test "trajectory-seed: seeds over an existing but empty trajectory file" {
  : > "$RT/trajectory.jsonl"
  run hook trajectory-seed
  [[ "$output" == *"wrote 8"* ]]
}

@test "trajectory-seed: --force appends to an existing trajectory instead of replacing it" {
  # Documents actual behavior: --force skips the guard but emit() uses >>, so it does not overwrite.
  printf '{"real":1}\n' > "$RT/trajectory.jsonl"
  run hook trajectory-seed --force
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$RT/trajectory.jsonl" | tr -d ' ')" = "9" ]
}

@test "trajectory-seed: --status reports 'no trajectory yet' when missing" {
  run hook trajectory-seed --status
  [ "$output" = "no trajectory yet" ]
}

@test "trajectory-seed: --status reports counts by outcome after seeding" {
  hook trajectory-seed >/dev/null
  run hook trajectory-seed --status
  [[ "$output" == *"trajectory: 8 events"* ]]
  [[ "$output" == *"success: 3"* ]]
  [[ "$output" == *"error: 3"* ]]
  [[ "$output" == *"blocked: 2"* ]]
}

@test "trajectory-seed: unknown arg exits 1" {
  run hook trajectory-seed --bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown arg"* ]]
}

# --- deploy-watch (no gh/network use; fake gh on PATH exits 99 if ever called) ---

@test "deploy-watch: start records a watching entry" {
  run hook deploy-watch start p1 hooks/x.sh pass_rate 0.9
  [ "$status" -eq 0 ]
  [[ "$output" == *"watch started: p1 on hooks/x.sh"* ]]
  [ "$(jq -r '.status' "$RT/deploy-watches.jsonl")" = "watching" ]
  [ "$(jq -r '.baseline' "$RT/deploy-watches.jsonl")" = "0.9" ]
}

@test "deploy-watch: start with missing args exits 2" {
  run hook deploy-watch start p1 hooks/x.sh
  [ "$status" -eq 2 ]
  [[ "$output" == *"start requires"* ]]
}

@test "deploy-watch: check with current above baseline prints OK and exits 0" {
  hook deploy-watch start p1 hooks/x.sh pass_rate 0.8 >/dev/null
  run hook deploy-watch check p1 0.9
  [ "$status" -eq 0 ]
  [[ "$output" == "OK: pass_rate=0.9 (baseline=0.8, no regression)"* ]]
}

@test "deploy-watch: check with current below baseline prints REGRESSION and exits 1" {
  hook deploy-watch start p1 hooks/x.sh pass_rate 0.8 >/dev/null
  run hook deploy-watch check p1 0.5
  [ "$status" -eq 1 ]
  [[ "$output" == *"REGRESSION: pass_rate dropped from 0.8 to 0.5"* ]]
}

@test "deploy-watch: check uses the LAST watch record for the same proposal id" {
  hook deploy-watch start p1 hooks/x.sh pass_rate 0.5 >/dev/null
  hook deploy-watch start p1 hooks/x.sh pass_rate 0.8 >/dev/null
  # 0.7 is above the first baseline (0.5) but below the last (0.8)
  run hook deploy-watch check p1 0.7
  [ "$status" -eq 1 ]
  [[ "$output" == *"dropped from 0.8 to 0.7"* ]]
}

@test "deploy-watch: check with no watches file exits 2" {
  run hook deploy-watch check p1 1
  [ "$status" -eq 2 ]
  [[ "$output" == *"no active watches"* ]]
}

@test "deploy-watch: check for an unknown proposal id exits 2" {
  hook deploy-watch start p1 hooks/x.sh m 1 >/dev/null
  run hook deploy-watch check other 1
  [ "$status" -eq 2 ]
  [[ "$output" == *"no watch for other"* ]]
}

@test "deploy-watch: check with missing args exits 2" {
  run hook deploy-watch check p1
  [ "$status" -eq 2 ]
  [[ "$output" == *"check requires"* ]]
}

@test "deploy-watch: revert backs up the deployed file and restores it from git HEAD" {
  need git
  repo="$BATS_TEST_TMPDIR/repo"; mkdir -p "$repo"
  git -C "$repo" init -q
  printf 'original\n' > "$repo/f.txt"
  git -C "$repo" add f.txt
  git -C "$repo" -c user.name=t -c user.email=t@example.com commit -q -m init
  printf 'deployed change\n' > "$repo/f.txt"
  cd "$repo"
  run hook deploy-watch revert p1 "$repo/f.txt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"reverted $repo/f.txt to HEAD"* ]]
  [ "$(cat "$repo/f.txt")" = "original" ]
  [ "$(cat "$RT"/backups/*-f.txt.bak)" = "deployed change" ]
  [ "$(jq -r '.status' "$RT/iteration-history.jsonl")" = "regressed" ]
}

@test "deploy-watch: revert of a missing target exits 2" {
  run hook deploy-watch revert p1 "$BATS_TEST_TMPDIR/nope.txt"
  [ "$status" -eq 2 ]
  [[ "$output" == *"target not found"* ]]
}

@test "deploy-watch: revert outside a git repo exits 2 but keeps the backup" {
  need git
  mkdir -p "$BATS_TEST_TMPDIR/nogit"; printf 'x\n' > "$BATS_TEST_TMPDIR/nogit/f.txt"
  cd "$BATS_TEST_TMPDIR/nogit"
  GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR" run hook deploy-watch revert p1 "$BATS_TEST_TMPDIR/nogit/f.txt"
  [ "$status" -eq 2 ]
  [[ "$output" == *"git checkout failed"* ]]
  [ -n "$(ls "$RT"/backups/)" ]
}

@test "deploy-watch: status says no active watches on a fresh tree" {
  run hook deploy-watch status
  [ "$status" -eq 0 ]
  [ "$output" = "no active watches" ]
}

@test "deploy-watch: status lists started watches" {
  hook deploy-watch start p1 hooks/x.sh pass_rate 0.9 >/dev/null
  run hook deploy-watch status
  [ "$status" -eq 0 ]
  [[ "$output" == *"p1: hooks/x.sh (pass_rate baseline=0.9) [watching]"* ]]
}

@test "deploy-watch: unknown command exits 2" {
  run hook deploy-watch bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown command"* ]]
}
