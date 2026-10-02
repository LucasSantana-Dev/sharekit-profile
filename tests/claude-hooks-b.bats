#!/usr/bin/env bats
# tests/claude-hooks-b.bats - distributable hooks in claude/hooks/: rate-limit-watch,
# rtk-rewrite, session-budget-guard, skill-quality-gate, statusline, check-harness-drift,
# check-idempotency. Hermetic: HOME is a tmpdir, rtk is a stub, per-test session ids keep
# the /tmp state flags unique (removed in teardown). No network.

setup() {
  export REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export H="$REPO_ROOT/claude/hooks"
  export HOME="$BATS_TEST_TMPDIR/home"
  export SID="bats-$$-${BATS_TEST_NUMBER}"
  mkdir -p "$HOME/.claude/projects/p" "$BATS_TEST_TMPDIR/stub"
  unset SKILL_GATE_BYPASS CLAUDE_PROJECT_DIR
}

teardown() {
  rm -f /tmp/claude-rate-limit-${SID}.json /tmp/claude-rate-limit-band-${SID}.txt \
        /tmp/claude-rate-limit-block-${SID} /tmp/claude-ctxnudge-calls-${SID}.txt* \
        /tmp/claude-ctxnudge-${SID}-*
}

need() { command -v "$1" >/dev/null 2>&1 || skip "$1 not installed"; }

# --- rate-limit-watch -------------------------------------------------------

rl_session() { # $1 = remaining tokens
  printf '{"headers":{"anthropic-ratelimit-tokens-remaining":"%s"}}\n' "$1" \
    > "$HOME/.claude/projects/p/${SID}.jsonl"
}
rl() { printf '{"session_id":"%s"}' "$SID" | bash "$H/rate-limit-watch.sh"; }

@test "rate-limit-watch: empty stdin exits 0 silently" {
  need jq
  run bash -c "printf '' | bash '$H/rate-limit-watch.sh'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "rate-limit-watch: malformed JSON stdin exits 0 silently" {
  need jq
  run bash -c "printf 'not json' | bash '$H/rate-limit-watch.sh' 2>/dev/null"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "rate-limit-watch: missing session transcript exits 0 silently" {
  need jq
  run rl
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "rate-limit-watch: plentiful headroom writes state file and emits nothing" {
  need jq
  rl_session 900000
  run rl
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(jq -r '.tokens_remaining' /tmp/claude-rate-limit-${SID}.json)" = "900000" ]
}

@test "rate-limit-watch: crossing the 10000 band emits a yellow warn-only message" {
  need jq
  rl_session 9000
  run rl
  [ "$status" -eq 0 ]
  [[ "$(echo "$output" | jq -r '.systemMessage')" == "[yellow]"* ]]
  [ "$(echo "$output" | jq -r '.hookSpecificOutput // empty')" = "" ]
}

@test "rate-limit-watch: crossing the 500 band emits decision block with handoff reason" {
  need jq
  rl_session 100
  run rl
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.hookSpecificOutput.decision' | tail -1)" = "block" ]
  [[ "$output" == *"/handoff"* ]]
}

@test "rate-limit-watch: block is emitted once per session then falls back to systemMessage" {
  need jq
  rl_session 100
  run rl
  [ "$status" -eq 0 ]
  rm -f /tmp/claude-rate-limit-band-${SID}.txt   # re-arm band, keep block flag
  run rl
  [ "$status" -eq 0 ]
  [[ "$output" == *"[red]"* ]]
  [[ "$output" != *'"decision"'* ]]
}

@test "rate-limit-watch: same band is not re-announced on the next turn" {
  need jq
  rl_session 9000
  run rl
  [ -n "$output" ]
  run rl
  [ -z "$output" ]
}

@test "rate-limit-watch: transcript without ratelimit headers exits 0 silently" {
  need jq
  echo '{"type":"user"}' > "$HOME/.claude/projects/p/${SID}.jsonl"
  run rl
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- rtk-rewrite ------------------------------------------------------------

mk_rtk2() { # $1 exit code, $2 rewrite stdout, $3 version
  cat > "$BATS_TEST_TMPDIR/stub/rtk" <<STUB
#!/usr/bin/env bash
if [ "\$1" = "--version" ]; then echo "rtk ${3:-0.30.0}"; exit 0; fi
if [ "\$1" = "rewrite" ]; then printf '%s' '$2'; exit $1; fi
exit 1
STUB
  chmod +x "$BATS_TEST_TMPDIR/stub/rtk"
}
rtk_hook() { PATH="$BATS_TEST_TMPDIR/stub:$PATH" bash "$H/rtk-rewrite.sh"; }
CMD_JSON='{"tool_input":{"command":"git status","description":"d"}}'

@test "rtk-rewrite: exit 0 rewrite auto-allows with updatedInput" {
  need jq
  mk_rtk2 0 "rtk git status"
  run bash -c "echo '$CMD_JSON' | PATH='$BATS_TEST_TMPDIR/stub:$PATH' bash '$H/rtk-rewrite.sh'"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.hookSpecificOutput.permissionDecision')" = "allow" ]
  [ "$(echo "$output" | jq -r '.hookSpecificOutput.updatedInput.command')" = "rtk git status" ]
  [ "$(echo "$output" | jq -r '.hookSpecificOutput.updatedInput.description')" = "d" ]
}

@test "rtk-rewrite: exit 3 (ask rule) rewrites without permissionDecision" {
  need jq
  mk_rtk2 3 "rtk git status"
  run bash -c "echo '$CMD_JSON' | PATH='$BATS_TEST_TMPDIR/stub:$PATH' bash '$H/rtk-rewrite.sh'"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.hookSpecificOutput.updatedInput.command')" = "rtk git status" ]
  [ "$(echo "$output" | jq -r '.hookSpecificOutput.permissionDecision // "none"')" = "none" ]
}

@test "rtk-rewrite: exit 1 (no equivalent) passes through silently" {
  need jq
  mk_rtk2 1 ""
  run bash -c "echo '$CMD_JSON' | PATH='$BATS_TEST_TMPDIR/stub:$PATH' bash '$H/rtk-rewrite.sh'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "rtk-rewrite: exit 2 (deny rule) passes through silently" {
  need jq
  mk_rtk2 2 ""
  run bash -c "echo '$CMD_JSON' | PATH='$BATS_TEST_TMPDIR/stub:$PATH' bash '$H/rtk-rewrite.sh'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "rtk-rewrite: already-rtk command (identical output) emits nothing" {
  need jq
  mk_rtk2 0 "git status"
  run bash -c "echo '$CMD_JSON' | PATH='$BATS_TEST_TMPDIR/stub:$PATH' bash '$H/rtk-rewrite.sh'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "rtk-rewrite: empty stdin exits 0 silently" {
  need jq
  mk_rtk2 0 "rtk x"
  run bash -c "printf '' | PATH='$BATS_TEST_TMPDIR/stub:$PATH' bash '$H/rtk-rewrite.sh'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "rtk-rewrite: malformed JSON stdin exits 0 silently" {
  need jq
  mk_rtk2 0 "rtk x"
  run bash -c "printf 'garbage' | PATH='$BATS_TEST_TMPDIR/stub:$PATH' bash '$H/rtk-rewrite.sh' 2>/dev/null"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "rtk-rewrite: rtk older than 0.23.0 warns on stderr and exits 0" {
  need jq
  mk_rtk2 0 "rtk git status" 0.22.1
  run bash -c "echo '$CMD_JSON' | PATH='$BATS_TEST_TMPDIR/stub:$PATH' bash '$H/rtk-rewrite.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"too old"* ]]
}

@test "rtk-rewrite: missing rtk warns and exits 0" {
  need jq
  mkdir -p "$BATS_TEST_TMPDIR/jqonly"
  ln -s "$(command -v jq)" "$BATS_TEST_TMPDIR/jqonly/jq"
  run bash -c "echo '$CMD_JSON' | PATH='$BATS_TEST_TMPDIR/jqonly' /bin/bash '$H/rtk-rewrite.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"rtk is not installed"* ]]
}

@test "rtk-rewrite: missing jq warns and exits 0" {
  run bash -c "echo '$CMD_JSON' | PATH='$BATS_TEST_TMPDIR/stub' /bin/bash '$H/rtk-rewrite.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"jq is not installed"* ]]
}

# --- session-budget-guard ---------------------------------------------------

# Writes a transcript: a 10K baseline turn, then a turn at $1 input tokens (model $2).
sb_session() {
  {
    printf '{"type":"assistant","message":{"model":"%s","usage":{"input_tokens":10000},"content":[]}}\n' "${2:-claude-sonnet}"
    printf '{"type":"assistant","message":{"model":"%s","usage":{"input_tokens":%s},"content":[]}}\n' "${2:-claude-sonnet}" "$1"
  } > "$HOME/.claude/projects/p/${SID}.jsonl"
}
sb() { printf '{"session_id":"%s"}' "$SID" | bash "$H/session-budget-guard.sh"; }
sb_prime() { echo 24 > /tmp/claude-ctxnudge-calls-${SID}.txt; }  # next call is #25

@test "session-budget-guard: empty stdin exits 0 silently" {
  need jq
  run bash -c "printf '' | bash '$H/session-budget-guard.sh'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "session-budget-guard: malformed stdin exits 0 silently" {
  need jq
  run bash -c "printf 'nope' | bash '$H/session-budget-guard.sh'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "session-budget-guard: first call only increments the counter" {
  need jq
  sb_session 199000
  run sb
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(cat /tmp/claude-ctxnudge-calls-${SID}.txt)" = "1" ]
}

@test "session-budget-guard: garbage in counter file is sanitized" {
  need jq
  echo "ab9x" > /tmp/claude-ctxnudge-calls-${SID}.txt
  run sb
  [ "$status" -eq 0 ]
  [ "$(cat /tmp/claude-ctxnudge-calls-${SID}.txt)" = "10" ]
}

@test "session-budget-guard: below thresholds creates no band flag (empty band must not shift fields)" {
  need jq
  sb_session 20000
  sb_prime
  run sb
  [ -z "$output" ]
  run bash -c "ls /tmp/claude-ctxnudge-${SID}-* 2>/dev/null"
  [ -z "$output" ]
}

@test "session-budget-guard: low context on the recompute call emits nothing" {
  need jq
  sb_session 20000
  sb_prime
  run sb
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "session-budget-guard: near-full 200K context emits an orange compact nudge" {
  need jq
  sb_session 190000
  sb_prime
  run sb
  [ "$status" -eq 0 ]
  [[ "$(echo "$output" | jq -r '.systemMessage')" == "[orange]"* ]]
  [ -f /tmp/claude-ctxnudge-${SID}-hard ]
}

@test "session-budget-guard: same band is announced once per session" {
  need jq
  sb_session 190000
  sb_prime
  run sb
  [ -n "$output" ]
  sb_prime
  run sb
  [ -z "$output" ]
}

@test "session-budget-guard: advisory only, never emits a block decision" {
  need jq
  sb_session 195000
  sb_prime
  run sb
  [[ "$output" != *'"decision"'* ]]
}

@test "session-budget-guard: missing transcript exits 0 silently" {
  need jq
  sb_prime
  run sb
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- skill-quality-gate -----------------------------------------------------

mk_skill() { # $1 = name, $2 = body (full file content)
  mkdir -p "$BATS_TEST_TMPDIR/skills/$1"
  printf '%s' "$2" > "$BATS_TEST_TMPDIR/skills/$1/SKILL.md"
  SKILL="$BATS_TEST_TMPDIR/skills/$1/SKILL.md"
}
GOOD_BODY() {
  printf -- '---\nname: %s\ndescription: x\n---\n# T\n\n## Steps\n1. a\n\n## Stop conditions\nhalt\n\nDone when: ok\n' "$1"
  for i in $(seq 1 30); do echo "line $i"; done
}
qg() { printf '{"tool_name":"%s","tool_input":{"file_path":"%s"}}' "${2:-Write}" "$1" | bash "$H/skill-quality-gate.sh"; }
have_yaml() { python3 -c 'import yaml' 2>/dev/null || python -c 'import yaml' 2>/dev/null || skip "PyYAML not installed"; }

@test "skill-quality-gate: empty stdin exits 0" {
  run bash -c "printf '' | bash '$H/skill-quality-gate.sh'"
  [ "$status" -eq 0 ]
}

@test "skill-quality-gate: malformed JSON stdin exits 0" {
  run bash -c "printf 'junk' | bash '$H/skill-quality-gate.sh'"
  [ "$status" -eq 0 ]
}

@test "skill-quality-gate: non-SKILL.md file is ignored" {
  echo x > "$BATS_TEST_TMPDIR/README.md"
  run qg "$BATS_TEST_TMPDIR/README.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "skill-quality-gate: non-edit tool is ignored" {
  mk_skill good "$(GOOD_BODY good)"
  run qg "$SKILL" Read
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "skill-quality-gate: well-formed skill passes with no output" {
  have_yaml
  mk_skill good "$(GOOD_BODY good)"
  run qg "$SKILL"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "skill-quality-gate: unclosed code fence blocks with exit 2" {
  mk_skill fence "$(GOOD_BODY fence)
\`\`\`
code"
  run bash -c "printf '{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"%s\"}}' '$SKILL' | bash '$H/skill-quality-gate.sh' 2>&1"
  [ "$status" -eq 2 ]
  [[ "$output" == *"odd code-fence count"* ]]
}

@test "skill-quality-gate: invalid YAML frontmatter blocks with exit 2" {
  have_yaml
  mk_skill bad "---
name: bad
description: a: b: [unclosed
---
body
"
  run bash -c "printf '{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"%s\"}}' '$SKILL' | bash '$H/skill-quality-gate.sh' 2>&1"
  [ "$status" -eq 2 ]
  [[ "$output" == *"not valid YAML"* ]]
}

@test "skill-quality-gate: SKILL_GATE_BYPASS=1 lets a broken skill through" {
  mk_skill fence2 "$(GOOD_BODY fence2)
\`\`\`
code"
  SKILL_GATE_BYPASS=1 run qg "$SKILL"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "skill-quality-gate: thin skill warns via systemMessage and exits 0" {
  mk_skill thin "---
name: thin
description: x
---
# tiny
"
  run qg "$SKILL"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"systemMessage"'* ]]
  [[ "$output" == *"under 30 lines"* ]]
}

@test "skill-quality-gate: name that differs from dir warns" {
  have_yaml
  mk_skill dirname "$(GOOD_BODY othername)"
  run qg "$SKILL"
  [ "$status" -eq 0 ]
  [[ "$output" == *"!= dir 'dirname'"* ]]
}

# --- statusline -------------------------------------------------------------

sl() {
  [ -x "$BATS_TEST_TMPDIR/stub/rtk" ] || { printf '#!/usr/bin/env bash\nexit 1\n' > "$BATS_TEST_TMPDIR/stub/rtk"; chmod +x "$BATS_TEST_TMPDIR/stub/rtk"; }
  printf '%s' "$1" | PATH="$BATS_TEST_TMPDIR/stub:$PATH" bash "$H/statusline.sh"
}

@test "statusline: renders project and ctx percent, truncating decimals" {
  need jq
  CLAUDE_PROJECT_DIR=/x/myproj run sl '{"context_window":{"used_percentage":42.7}}'
  [ "$status" -eq 0 ]
  [ "$output" = "[myproj] ctx:42%" ]
}

@test "statusline: rtk savings cache is written even when ~/.claude does not exist" {
  need jq
  cat > "$BATS_TEST_TMPDIR/stub/rtk" <<'STUB'
#!/usr/bin/env bash
echo '{"summary":{"total_saved":500}}'
STUB
  chmod +x "$BATS_TEST_TMPDIR/stub/rtk"
  rm -rf "$HOME/.claude"
  CLAUDE_PROJECT_DIR=/x/p run sl '{"context_window":{"used_percentage":5}}'
  [ "$output" = "[p] ctx:5%  ↓500tok" ]
  [ -f "$HOME/.claude/.rtk-savings.cache" ]
}

@test "statusline: empty stdin shows ctx:? and exits 0" {
  need jq
  CLAUDE_PROJECT_DIR=/x/myproj run sl ''
  [ "$status" -eq 0 ]
  [ "$output" = "[myproj] ctx:?" ]
}

@test "statusline: malformed JSON shows ctx:? and exits 0" {
  need jq
  CLAUDE_PROJECT_DIR=/x/myproj run sl 'not json'
  [ "$status" -eq 0 ]
  [ "$output" = "[myproj] ctx:?" ]
}

@test "statusline: opus model appends the APEX warning" {
  need jq
  CLAUDE_PROJECT_DIR=/x/p run sl '{"model":{"id":"claude-Opus-4"},"context_window":{"used_percentage":5}}'
  [[ "$output" == *"APEX"* ]]
  [[ "$output" == *"/model sonnet"* ]]
}

@test "statusline: sonnet model has no APEX warning" {
  need jq
  CLAUDE_PROJECT_DIR=/x/p run sl '{"model":{"id":"claude-sonnet-5"},"context_window":{"used_percentage":5}}'
  [[ "$output" != *"APEX"* ]]
}

@test "statusline: fresh cache supplies rtk savings" {
  need jq
  mkdir -p "$HOME/.claude"
  echo -n "12K" > "$HOME/.claude/.rtk-savings.cache"
  CLAUDE_PROJECT_DIR=/x/p run sl '{"context_window":{"used_percentage":5}}'
  [ "$output" = "[p] ctx:5%  ↓12Ktok" ]
}

@test "statusline: rtk gain output is formatted as K and cached" {
  need jq
  cat > "$BATS_TEST_TMPDIR/stub/rtk" <<'STUB'
#!/usr/bin/env bash
echo '{"summary":{"total_saved":2600}}'
STUB
  chmod +x "$BATS_TEST_TMPDIR/stub/rtk"
  CLAUDE_PROJECT_DIR=/x/p run sl '{"context_window":{"used_percentage":5}}'
  [ "$output" = "[p] ctx:5%  ↓3Ktok" ]
  [ "$(cat "$HOME/.claude/.rtk-savings.cache")" = "3K" ]
}

@test "statusline: rtk gain over a million is formatted as M" {
  need jq
  cat > "$BATS_TEST_TMPDIR/stub/rtk" <<'STUB'
#!/usr/bin/env bash
echo '{"summary":{"total_saved":2500000}}'
STUB
  chmod +x "$BATS_TEST_TMPDIR/stub/rtk"
  CLAUDE_PROJECT_DIR=/x/p run sl '{"context_window":{"used_percentage":5}}'
  [[ "$output" == *"↓2.5Mtok"* ]]
}

# --- check-harness-drift ----------------------------------------------------

drift() { bash "$H/check-harness-drift.sh" "$@"; }
mk_trees() {
  LIVE="$BATS_TEST_TMPDIR/live"; TRK="$BATS_TEST_TMPDIR/trk"
  mkdir -p "$LIVE/hooks" "$LIVE/agents" "$TRK/hooks" "$TRK/agents"
}

@test "check-harness-drift: identical trees exit 0 with no output" {
  mk_trees
  echo a > "$LIVE/hooks/x.sh"; echo a > "$TRK/hooks/x.sh"
  echo b > "$LIVE/agents/y.md"; echo b > "$TRK/agents/y.md"
  run drift "$LIVE" "$TRK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "check-harness-drift: edited live file reports DRIFT and exits 1" {
  mk_trees
  echo a > "$LIVE/hooks/x.sh"; echo different > "$TRK/hooks/x.sh"
  run drift "$LIVE" "$TRK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"DRIFT      hooks/x.sh"* ]]
}

@test "check-harness-drift: live-only file reports UNTRACKED and exits 1" {
  mk_trees
  echo a > "$LIVE/agents/new.md"
  run drift "$LIVE" "$TRK"
  [ "$status" -eq 1 ]
  [[ "$output" == *"UNTRACKED  agents/new.md"* ]]
}

@test "check-harness-drift: live-only rtk-rewrite.sh is excluded" {
  mk_trees
  echo a > "$LIVE/hooks/rtk-rewrite.sh"
  run drift "$LIVE" "$TRK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "check-harness-drift: missing tree prints SKIP and exits 0" {
  run drift "$BATS_TEST_TMPDIR/nope" "$BATS_TEST_TMPDIR/nada"
  [ "$status" -eq 0 ]
  [[ "$output" == "SKIP:"* ]]
}

@test "check-harness-drift: HOME defaults are used when no args are given" {
  mkdir -p "$HOME/.claude/hooks" "$HOME/.claude-env/hooks"
  echo a > "$HOME/.claude/hooks/z.sh"
  run drift
  [ "$status" -eq 1 ]
  [[ "$output" == *"UNTRACKED  hooks/z.sh"* ]]
}

# --- check-idempotency ------------------------------------------------------

idem_setup() {
  FAKE="$BATS_TEST_TMPDIR/root"
  mkdir -p "$FAKE/hooks"
  cp "$H/check-idempotency.sh" "$FAKE/hooks/"
  LOG="$FAKE/.harness/runtime/idempotency.jsonl"
}
idem() { printf '%s' "$1" | bash "$FAKE/hooks/check-idempotency.sh"; }

@test "check-idempotency: Write tool is logged with a stderr hint, exit 0" {
  need jq
  idem_setup
  run bash -c "printf '%s' '{\"tool_name\":\"Write\"}' | bash '$FAKE/hooks/check-idempotency.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"HINT: state-check before mutation"* ]]
  [ "$(jq -r '.event' "$LOG")" = "unverified-mutation" ]
  [ "$(jq -r '.tool' "$LOG")" = "Write" ]
}

@test "check-idempotency: mutating Bash command (git push) is logged" {
  need jq
  idem_setup
  run idem '{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}'
  [ "$status" -eq 0 ]
  [ "$(jq -r '.command' "$LOG")" = "git push origin main" ]
}

@test "check-idempotency: read-only Bash command is not logged" {
  need jq
  idem_setup
  run idem '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}'
  [ "$status" -eq 0 ]
  [ ! -s "$LOG" ]
}

@test "check-idempotency: non-mutating tool is not logged" {
  need jq
  idem_setup
  run idem '{"tool_name":"Read","tool_input":{"file_path":"/x"}}'
  [ "$status" -eq 0 ]
  [ ! -s "$LOG" ]
}

@test "check-idempotency: empty stdin exits 0 without logging" {
  need jq
  idem_setup
  run idem ''
  [ "$status" -eq 0 ]
  [ ! -s "$LOG" ]
}

@test "check-idempotency: malformed JSON exits 0 without logging" {
  need jq
  idem_setup
  run idem 'not json'
  [ "$status" -eq 0 ]
  [ ! -s "$LOG" ]
}

@test "check-idempotency: missing jq fails open with exit 0" {
  idem_setup
  run bash -c "printf '%s' '{\"tool_name\":\"Write\"}' | PATH='$BATS_TEST_TMPDIR/stub' /bin/bash '$FAKE/hooks/check-idempotency.sh'"
  [ "$status" -eq 0 ]
  [ ! -e "$LOG" ]
}
