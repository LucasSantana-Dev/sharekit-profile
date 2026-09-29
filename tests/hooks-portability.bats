#!/usr/bin/env bats
# Portability + behavior tests for the shipped claude/hooks. Every test runs a copy of the
# hooks under a temp HOME, with a minimal PATH, through /bin/bash (3.2 on stock macOS), so
# nothing writes into the repo and bash-4-only constructs fail here the way they do on a Mac.

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  TMP_HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$TMP_HOME/.claude" "$BATS_TEST_TMPDIR/repo"
  cp -R "$REPO_ROOT/claude/hooks" "$TMP_HOME/.claude/hooks"
  H="$TMP_HOME/.claude/hooks"
  if [ -x /bin/bash ] && /bin/bash -c '[ "${BASH_VERSINFO[0]}" -le 3 ]' 2>/dev/null; then
    SH=/bin/bash
  else
    SH=bash
  fi
  GH_PATH="$(dirname "$(command -v python3)"):/usr/bin:/bin"
  cd "$BATS_TEST_TMPDIR/repo"
  git init -q -b main
  git -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init
  git remote add origin https://github.com/example/scratch.git
}

# hook <script> <json>: run a hook with a clean environment, stdout+stderr in $output.
hook() {
  printf '%s' "$2" | env -i HOME="$TMP_HOME" PATH="$GH_PATH" "$SH" "$H/$1"
}

bash_payload() {  # bash_payload <command> [session_id]
  python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]},"session_id":sys.argv[2],"cwd":sys.argv[3]}))' \
    "$1" "${2:-t}" "$BATS_TEST_TMPDIR/repo"
}

@test "check-pr-automation-halt: parses under the stock shell and allows git status" {
  "$SH" -n "$H/check-pr-automation-halt.sh"
  run hook check-pr-automation-halt.sh "$(bash_payload 'git status')"
  [ "$status" -eq 0 ]
}

@test "check-pr-automation-halt: blocks a Claude co-author trailer" {
  run hook check-pr-automation-halt.sh "$(bash_payload 'git commit -m "x

Co-Authored-By: Claude <noreply@anthropic.com>"')"
  [ "$status" -eq 2 ]
}

@test "check-pr-automation-halt: allows a human co-author whose name contains bot (Talbot)" {
  run hook check-pr-automation-halt.sh "$(bash_payload 'git commit -m "x

Co-Authored-By: Jane Talbot <jane@example.com>"')"
  [ "$status" -eq 0 ]
}

@test "check-pr-automation-halt: blocks direct push to main" {
  run hook check-pr-automation-halt.sh "$(bash_payload 'git push origin main')"
  [ "$status" -eq 2 ]
}

@test "check-stuck-loop: blocks the 3rd identical make build, per session only" {
  run hook check-stuck-loop.sh "$(bash_payload 'make build' A)"; [ "$status" -eq 0 ]
  run hook check-stuck-loop.sh "$(bash_payload 'make build' A)"; [ "$status" -eq 0 ]
  run hook check-stuck-loop.sh "$(bash_payload 'make build' A)"; [ "$status" -eq 2 ]
  run hook check-stuck-loop.sh "$(bash_payload 'make build' B)"; [ "$status" -eq 0 ]
}

@test "check-stuck-loop: git push tolerates 7 repeats and blocks the 8th" {
  for i in 1 2 3 4 5 6 7; do
    run hook check-stuck-loop.sh "$(bash_payload 'git push origin feat' S)"
    [ "$status" -eq 0 ]
  done
  run hook check-stuck-loop.sh "$(bash_payload 'git push origin feat' S)"
  [ "$status" -eq 2 ]
  run hook check-stuck-loop.sh "$(bash_payload 'git push origin feat' OTHER)"
  [ "$status" -eq 0 ]
}

@test "eval-run: skips a task whose hook file is not installed" {
  [ ! -f "$H/check-dangerous-patterns.sh" ]
  run env -i HOME="$TMP_HOME" PATH="$GH_PATH" "$SH" "$H/eval-run.sh" --eval portability --variant with --split seen
  [ "$status" -eq 0 ]
  [[ "$output" == *"skip dp-rmrf-root: check-dangerous-patterns.sh not installed"* ]]
}

@test "check-read-only-subagent: reads tool_input.subagent_type (Explore + write perms blocks)" {
  run hook check-read-only-subagent.sh '{"tool_name":"Agent","tool_input":{"subagent_type":"Explore","prompt":"look"},"permissions":"Write,Edit"}'
  [ "$status" -eq 2 ]
  run hook check-read-only-subagent.sh '{"agent_type":"code-reviewer","allowed_tools":"Read,Grep"}'
  [ "$status" -eq 0 ]
}
