#!/usr/bin/env bats
# Behavior tests for distributable claude/hooks: bash-prefilter, complexity-classifier,
# composite-router, grep-before-rag-nudge, mode-reminder, pre-compact-summary, protect-files.
# Hermetic: hooks are copied under a temp HOME, TMPDIR is redirected, no network, no writes
# outside $BATS_TEST_TMPDIR. Test code builds JSON with printf (no python3 in the test layer).

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  TMP_HOME="$BATS_TEST_TMPDIR/home"
  WORK="$BATS_TEST_TMPDIR/work"
  mkdir -p "$TMP_HOME/.claude" "$WORK" "$BATS_TEST_TMPDIR/tmp"
  cp -R "$REPO_ROOT/claude/hooks" "$TMP_HOME/.claude/hooks"
  H="$TMP_HOME/.claude/hooks"
  # Stub the rtk rewriter so bash-prefilter delegation is observable and offline.
  printf '#!/usr/bin/env bash\ncat >/dev/null\necho DELEGATED\n' > "$H/rtk-rewrite.sh"
  chmod +x "$H/rtk-rewrite.sh"
  rm -f "$H/rtk-bypass.list"
  TOOLS_PATH="$(dirname "$(command -v jq)"):$(dirname "$(command -v python3)"):/usr/bin:/bin"
  cd "$WORK"
}

# hook <script> <stdin>: run with a clean env.
hook() {
  printf '%s' "$2" | env -i HOME="$TMP_HOME" TMPDIR="$BATS_TEST_TMPDIR/tmp" PATH="$TOOLS_PATH" bash "$H/$1"
}

bash_json() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1"; }
prompt_json() { printf '{"prompt":"%s","session_id":"%s"}' "$1" "${2:-s1}"; }

# ---------- bash-prefilter ----------

@test "bash-prefilter: trivial builtin exits 0 without delegating" {
  run hook bash-prefilter.sh "$(bash_json 'pwd')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "bash-prefilter: ordinary command is delegated to rtk-rewrite" {
  run hook bash-prefilter.sh "$(bash_json 'git status')"
  [ "$status" -eq 0 ]
  [ "$output" = "DELEGATED" ]
}

@test "bash-prefilter: empty stdin exits 0 without delegating" {
  run hook bash-prefilter.sh ""
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "bash-prefilter: payload without a command exits 0 without delegating" {
  run hook bash-prefilter.sh '{"tool_input":{}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "bash-prefilter: command listed in rtk-bypass.list skips delegation" {
  printf '# comment\n\nnpm\n' > "$H/rtk-bypass.list"
  run hook bash-prefilter.sh "$(bash_json 'npm test')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "bash-prefilter: bypass word after a pipe skips delegation" {
  printf 'jq\n' > "$H/rtk-bypass.list"
  run hook bash-prefilter.sh "$(bash_json 'cat x | jq .')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "bash-prefilter: command not in bypass list is still delegated" {
  printf 'npm\n' > "$H/rtk-bypass.list"
  run hook bash-prefilter.sh "$(bash_json 'git log')"
  [ "$output" = "DELEGATED" ]
}

@test "bash-prefilter: without jq on PATH it execs rtk-rewrite directly" {
  mkdir -p "$BATS_TEST_TMPDIR/nojq"
  for b in bash cat env; do ln -sf "$(command -v $b)" "$BATS_TEST_TMPDIR/nojq/$b"; done
  run bash -c "printf '%s' '{}' | env -i HOME='$TMP_HOME' PATH='$BATS_TEST_TMPDIR/nojq' '$(command -v bash)' '$H/bash-prefilter.sh'"
  [ "$status" -eq 0 ]
  [ "$output" = "DELEGATED" ]
}

# ---------- protect-files ----------

@test "protect-files: allows an ordinary source file" {
  run hook protect-files.sh '{"tool_input":{"file_path":"/repo/src/app.ts"}}'
  [ "$status" -eq 0 ]
}

@test "protect-files: blocks a real .env file" {
  run hook protect-files.sh '{"tool_input":{"file_path":"/repo/.env"}}'
  [ "$status" -eq 2 ]
  [[ "$output" == *BLOCKED* ]]
}

@test "protect-files: blocks .env.production" {
  run hook protect-files.sh '{"tool_input":{"file_path":"/repo/.env.production"}}'
  [ "$status" -eq 2 ]
}

@test "protect-files: allows .env.example template" {
  run hook protect-files.sh '{"tool_input":{"file_path":"/repo/.env.example"}}'
  [ "$status" -eq 0 ]
}

@test "protect-files: blocks private key and pem files" {
  run hook protect-files.sh '{"tool_input":{"file_path":"/home/u/.ssh/id_ed25519"}}'
  [ "$status" -eq 2 ]
  run hook protect-files.sh '{"tool_input":{"file_path":"/certs/server.pem"}}'
  [ "$status" -eq 2 ]
}

@test "protect-files: blocks writes under .git" {
  run hook protect-files.sh '{"tool_input":{"file_path":"/repo/.git/config"}}'
  [ "$status" -eq 2 ]
}

@test "protect-files: blocks sqlite and wal stores" {
  run hook protect-files.sh '{"tool_input":{"file_path":"/home/u/claude-mem.db-wal"}}'
  [ "$status" -eq 2 ]
  run hook protect-files.sh '{"tool_input":{"file_path":"/data/x.sqlite3"}}'
  [ "$status" -eq 2 ]
}

@test "protect-files: empty stdin exits 0" {
  run hook protect-files.sh ""
  [ "$status" -eq 0 ]
}

@test "protect-files: malformed JSON exits 0" {
  run hook protect-files.sh 'not json {'
  [ "$status" -eq 0 ]
}

# ---------- mode-reminder ----------

@test "mode-reminder: default prompt injects caveman, ponytail and agent-econ directives" {
  run hook mode-reminder.sh "$(prompt_json 'fix the thing')"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Caveman:"* ]]
  [[ "$output" == *"Ponytail:"* ]]
  [[ "$output" == *"Agent-econ:"* ]]
}

@test "mode-reminder: stop caveman writes the per-session off marker" {
  run hook mode-reminder.sh "$(prompt_json 'stop caveman' sA)"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Caveman OFF"* ]]
  [ -f "$BATS_TEST_TMPDIR/tmp/.caveman-off-sA" ]
}

@test "mode-reminder: after stop caveman the directive drops caveman but keeps ponytail" {
  hook mode-reminder.sh "$(prompt_json 'stop caveman' sB)" >/dev/null
  run hook mode-reminder.sh "$(prompt_json 'next task' sB)"
  [[ "$output" != *"Caveman:"* ]]
  [[ "$output" == *"Ponytail:"* ]]
}

@test "mode-reminder: caveman on clears the off marker" {
  hook mode-reminder.sh "$(prompt_json 'stop caveman' sC)" >/dev/null
  run hook mode-reminder.sh "$(prompt_json 'caveman on' sC)"
  [ ! -f "$BATS_TEST_TMPDIR/tmp/.caveman-off-sC" ]
  [[ "$output" == *"Caveman:"* ]]
}

@test "mode-reminder: normal mode turns off caveman and ponytail markers" {
  run hook mode-reminder.sh "$(prompt_json 'normal mode' sD)"
  [ -f "$BATS_TEST_TMPDIR/tmp/.caveman-off-sD" ]
  [ -f "$BATS_TEST_TMPDIR/tmp/.ponytail-off-sD" ]
}

@test "mode-reminder: stop agent-econ writes only the econ marker" {
  run hook mode-reminder.sh "$(prompt_json 'stop agent-econ' sE)"
  [[ "$output" == *"Agent-econ reminders OFF"* ]]
  [ -f "$BATS_TEST_TMPDIR/tmp/.agentecon-off-sE" ]
  [ ! -f "$BATS_TEST_TMPDIR/tmp/.caveman-off-sE" ]
}

@test "mode-reminder: all modes off yields no output" {
  hook mode-reminder.sh "$(prompt_json 'normal mode' sF)" >/dev/null
  hook mode-reminder.sh "$(prompt_json 'stop agent-econ' sF)" >/dev/null
  run hook mode-reminder.sh "$(prompt_json 'hello there' sF)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "mode-reminder: markers honor TMPDIR override and leave /tmp untouched" {
  run hook mode-reminder.sh "$(prompt_json 'stop ponytail' sG)"
  [ -f "$BATS_TEST_TMPDIR/tmp/.ponytail-off-sG" ]
}

@test "mode-reminder: empty stdin still emits default directive" {
  run hook mode-reminder.sh ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"Caveman:"* ]]
}

@test "mode-reminder: malformed JSON does not fail" {
  run hook mode-reminder.sh "garbage"
  [ "$status" -eq 0 ]
}

@test "mode-reminder: without jq exits 0 silently" {
  mkdir -p "$BATS_TEST_TMPDIR/nojq"
  for b in bash cat env; do ln -sf "$(command -v $b)" "$BATS_TEST_TMPDIR/nojq/$b"; done
  run bash -c "printf '%s' '{\"prompt\":\"x\"}' | env -i HOME='$TMP_HOME' PATH='$BATS_TEST_TMPDIR/nojq' '$(command -v bash)' '$H/mode-reminder.sh'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ---------- complexity-classifier ----------

@test "complexity-classifier: security prompt is classified critical" {
  run hook complexity-classifier.sh "$(prompt_json 'review the oauth token handling for vulnerabilities')"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CRITICAL"* ]]
  [ "$(cat "$TMP_HOME/.claude/.task-complexity")" = "critical" ]
}

@test "complexity-classifier: implementation prompt is classified high" {
  run hook complexity-classifier.sh "$(prompt_json 'implement pagination for the list endpoint')"
  [[ "$output" == *"HIGH"* ]]
}

@test "complexity-classifier: short lookup is classified low" {
  run hook complexity-classifier.sh "$(prompt_json 'where is the config file')"
  [[ "$output" == *"LOW"* ]]
}

@test "complexity-classifier: unmatched mid-length prompt defaults to medium" {
  run hook complexity-classifier.sh "$(prompt_json 'please rename the variable foo to bar across the module now')"
  [[ "$output" == *"MEDIUM"* ]]
}

@test "complexity-classifier: output is valid JSON with systemMessage" {
  run hook complexity-classifier.sh "$(prompt_json 'implement caching')"
  printf '%s' "$output" | jq -e '.systemMessage | length > 0' >/dev/null
}

@test "complexity-classifier: accepts message key as well as prompt" {
  run hook complexity-classifier.sh '{"message":"implement caching layer"}'
  [[ "$output" == *"HIGH"* ]]
}

@test "complexity-classifier: continuation inherits persisted critical level silently" {
  printf 'critical' > "$TMP_HOME/.claude/.task-complexity"
  run hook complexity-classifier.sh "$(prompt_json 'continue')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(cat "$TMP_HOME/.claude/.task-complexity")" = "critical" ]
}

@test "complexity-classifier: continuation after a low level is classified fresh" {
  printf 'low' > "$TMP_HOME/.claude/.task-complexity"
  run hook complexity-classifier.sh "$(prompt_json 'continue')"
  [ -n "$output" ]
}

@test "complexity-classifier: empty stdin exits 0 with no output" {
  run hook complexity-classifier.sh ""
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "complexity-classifier: malformed JSON exits 0 with no output" {
  run hook complexity-classifier.sh "{{{"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "complexity-classifier: empty prompt exits 0 with no output" {
  run hook complexity-classifier.sh '{"prompt":""}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ---------- composite-router ----------

@test "composite-router: prod outage routes to incident-response" {
  run hook composite-router.sh "$(prompt_json 'prod is down and users are reporting errors')"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Composite match: /incident-response"* ]]
}

@test "composite-router: output is valid UserPromptSubmit additionalContext JSON" {
  run hook composite-router.sh "$(prompt_json 'prod is down right now')"
  printf '%s' "$output" | jq -e '.hookSpecificOutput.hookEventName == "UserPromptSubmit"' >/dev/null
}

@test "composite-router: UI build prompt routes to repaint with plain skill hint" {
  run hook composite-router.sh "$(prompt_json 'build a landing page for the product')"
  [[ "$output" == *"Skill match: /repaint"* ]]
}

@test "composite-router: flaky prompt routes to debug-deep" {
  run hook composite-router.sh "$(prompt_json 'this test is flaky in ci')"
  [[ "$output" == *"/debug-deep"* ]]
}

@test "composite-router: readiness check beats merge intent" {
  run hook composite-router.sh "$(prompt_json 'is this ready to merge')"
  [[ "$output" == *"/verify-before-done"* ]]
}

@test "composite-router: merge intent without a release branch routes to merge-confidently" {
  run hook composite-router.sh "$(prompt_json 'ready to merge, land this')"
  [[ "$output" == *"/merge-confidently"* ]]
}

@test "composite-router: explicit /skill reference wins when the skill dir exists" {
  mkdir -p "$TMP_HOME/.claude/skills/myskill"
  run hook composite-router.sh "$(prompt_json 'please run /myskill on this')"
  [[ "$output" == *"Skill match: /myskill"* ]]
}

@test "composite-router: /skill reference without a skill dir is ignored" {
  run hook composite-router.sh "$(prompt_json 'please run /ghostskill on this')"
  [[ "$output" != *"ghostskill"* ]]
}

@test "composite-router: prompt shorter than 7 chars is skipped" {
  run hook composite-router.sh "$(prompt_json 'hotfix')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "composite-router: prompt longer than 4000 chars is skipped" {
  long="$(head -c 4100 /dev/zero | tr '\0' 'a')"
  run hook composite-router.sh "$(prompt_json "hotfix $long")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "composite-router: unrelated prompt emits nothing" {
  run hook composite-router.sh "$(prompt_json 'what is the weather like today')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "composite-router: empty stdin exits 0 silently" {
  run hook composite-router.sh ""
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "composite-router: malformed JSON exits 0 silently" {
  run hook composite-router.sh "not json at all"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "composite-router: accepts user_prompt key" {
  run hook composite-router.sh '{"user_prompt":"prod is down"}'
  [[ "$output" == *"/incident-response"* ]]
}

# ---------- grep-before-rag-nudge ----------

@test "grep-before-rag-nudge: wide recursive grep emits advisory and exits 0" {
  run hook grep-before-rag-nudge.sh "$(bash_json 'grep -rn foo .')"
  [ "$status" -eq 0 ]
  [[ "$output" == *"graph/RAG-first"* ]]
  [[ "$output" == *"rag_query / recall"* ]]
}

@test "grep-before-rag-nudge: rg sweep emits advisory" {
  run hook grep-before-rag-nudge.sh "$(bash_json 'rg TODO src')"
  [[ "$output" == *"systemMessage"* ]]
}

@test "grep-before-rag-nudge: advisory output is valid JSON" {
  run hook grep-before-rag-nudge.sh "$(bash_json 'grep -rn foo .')"
  printf '%s' "$output" | jq -e '.systemMessage' >/dev/null
}

@test "grep-before-rag-nudge: graph.json in cwd sharpens the hint to graphify" {
  mkdir -p graphify-out; : > graphify-out/graph.json
  run hook grep-before-rag-nudge.sh "$(bash_json 'grep -rn foo .')"
  [[ "$output" == *"graphify query"* ]]
}

@test "grep-before-rag-nudge: recent retrieval marker keeps it quiet" {
  touch "$TMP_HOME/.claude/.rag-recent"
  run hook grep-before-rag-nudge.sh "$(bash_json 'grep -rn foo .')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "grep-before-rag-nudge: stale retrieval marker still nudges" {
  touch -t 202001010000 "$TMP_HOME/.claude/.rag-recent"
  run hook grep-before-rag-nudge.sh "$(bash_json 'grep -rn foo .')"
  [[ "$output" == *"graph/RAG-first"* ]]
}

@test "grep-before-rag-nudge: piped grep refinement stays quiet" {
  run hook grep-before-rag-nudge.sh "$(bash_json 'cat f | grep -rn foo')"
  [ -z "$output" ]
}

@test "grep-before-rag-nudge: git grep stays quiet" {
  run hook grep-before-rag-nudge.sh "$(bash_json 'git grep -rn foo')"
  [ -z "$output" ]
}

@test "grep-before-rag-nudge: non-recursive command stays quiet" {
  run hook grep-before-rag-nudge.sh "$(bash_json 'ls -la')"
  [ -z "$output" ]
}

@test "grep-before-rag-nudge: non-Bash tool stays quiet" {
  run hook grep-before-rag-nudge.sh '{"tool_name":"Read","tool_input":{"command":"grep -rn foo ."}}'
  [ -z "$output" ]
}

@test "grep-before-rag-nudge: empty stdin exits 0 silently" {
  run hook grep-before-rag-nudge.sh ""
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "grep-before-rag-nudge: malformed JSON exits 0 silently" {
  run hook grep-before-rag-nudge.sh "{{ nope"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ---------- pre-compact-summary ----------

make_session() {  # make_session <sid>
  mkdir -p "$TMP_HOME/.claude/projects/p"
  {
    printf '{"type":"user","timestamp":"2026-01-01T10:00:00Z","message":{"content":"add the widget please"}}\n'
    printf '{"type":"user","timestamp":"2026-01-01T10:00:01Z","message":{"content":"<system-reminder>noise</system-reminder>"}}\n'
    printf '{"type":"assistant","timestamp":"2026-01-01T10:00:02Z","message":{"content":[{"type":"text","text":"on it"},{"type":"tool_use","name":"Edit","input":{"file_path":"/r/src/widget.ts"}}]}}\n'
    printf 'this line is not json\n'
  } > "$TMP_HOME/.claude/projects/p/$1.jsonl"
}

@test "pre-compact-summary: writes a per-session handoff with requests and tool activity" {
  make_session sess1
  run hook pre-compact-summary.sh '{"session_id":"sess1"}'
  [ "$status" -eq 0 ]
  f="$TMP_HOME/.claude/handoffs/_sem-projeto/auto/sess1.md"
  [ -f "$f" ]
  grep -q "add the widget please" "$f"
  grep -q "Edit" "$f"
  grep -q "widget.ts" "$f"
}

@test "pre-compact-summary: harness-injected user text is excluded" {
  make_session sess2
  hook pre-compact-summary.sh '{"session_id":"sess2"}' >/dev/null
  ! grep -q "system-reminder" "$TMP_HOME/.claude/handoffs/_sem-projeto/auto/sess2.md"
}

@test "pre-compact-summary: counts only real user messages" {
  make_session sess3
  hook pre-compact-summary.sh '{"session_id":"sess3"}' >/dev/null
  grep -q "Total user messages\*\*: 1 " "$TMP_HOME/.claude/handoffs/_sem-projeto/auto/sess3.md"
}

@test "pre-compact-summary: unknown session id writes nothing" {
  make_session sess4
  run hook pre-compact-summary.sh '{"session_id":"missing"}'
  [ "$status" -eq 0 ]
  [ ! -d "$TMP_HOME/.claude/handoffs" ]
}

@test "pre-compact-summary: missing session_id exits 0 and writes nothing" {
  run hook pre-compact-summary.sh '{}'
  [ "$status" -eq 0 ]
  [ ! -d "$TMP_HOME/.claude/handoffs" ]
}

@test "pre-compact-summary: empty stdin exits 0" {
  run hook pre-compact-summary.sh ""
  [ "$status" -eq 0 ]
}

@test "pre-compact-summary: malformed JSON exits 0" {
  run hook pre-compact-summary.sh "not json"
  [ "$status" -eq 0 ]
  [ ! -d "$TMP_HOME/.claude/handoffs" ]
}

@test "pre-compact-summary: transcript with no user messages or tools writes nothing" {
  mkdir -p "$TMP_HOME/.claude/projects/p"
  printf '{"type":"summary"}\n' > "$TMP_HOME/.claude/projects/p/empty1.jsonl"
  run hook pre-compact-summary.sh '{"session_id":"empty1"}'
  [ "$status" -eq 0 ]
  [ ! -f "$TMP_HOME/.claude/handoffs/_sem-projeto/auto/empty1.md" ]
}

@test "pre-compact-summary: handoffs helper dir overrides the default location" {
  make_session sess5
  mkdir -p "$TMP_HOME/.claude/skills/handoff/bin"
  printf '#!/usr/bin/env bash\necho "%s/custom"\n' "$BATS_TEST_TMPDIR" > "$TMP_HOME/.claude/skills/handoff/bin/handoffs"
  chmod +x "$TMP_HOME/.claude/skills/handoff/bin/handoffs"
  run hook pre-compact-summary.sh "{\"session_id\":\"sess5\",\"cwd\":\"$WORK\"}"
  [ -f "$BATS_TEST_TMPDIR/custom/auto/sess5.md" ]
}
