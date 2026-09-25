#!/usr/bin/env bats
# tests for hooks/memory-scope-gate.sh + .harness/memory-scopes.json

setup() {
  export REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export TEST_TMP="$BATS_TEST_TMPDIR/memscope-$$"
  mkdir -p "$TEST_TMP/repo/.harness"
  cd "$TEST_TMP/repo"
  git init -q
  git config user.email "userA@example.com"
  git config user.name "User A"
  cp "$REPO_ROOT/.harness/memory-scopes.json" .harness/
}

gate() {  # gate <tool> <path> <content>
  printf '{"tool_name":"%s","tool_input":{"file_path":"%s","content":"%s"}}' "$1" "$2" "$3" \
    | bash "$REPO_ROOT/hooks/memory-scope-gate.sh"
}

@test "memory-scope-gate: no policy file fails open" {
  rm .harness/memory-scopes.json
  run gate Write "$TEST_TMP/repo/.agents/memory/note.md" "hello"
  [ "$status" -eq 0 ]
}

@test "memory-scope-gate: non-memory tool passes" {
  run gate Bash "n/a" "ls -la"
  [ "$status" -eq 0 ]
}

@test "memory-scope-gate: personal-scope write allowed" {
  run gate Write "$TEST_TMP/repo/.claude/projects/x/memory/note.md" "session learning"
  [ "$status" -eq 0 ]
}

@test "memory-scope-gate: team-scope write without private tags allowed" {
  run gate Write "$TEST_TMP/repo/.agents/memory/shared.md" "curated team learning"
  [ "$status" -eq 0 ]
}

@test "memory-scope-gate: CROSS-USER LEAK - private-tagged note blocked from team scope" {
  # User A's private-tagged session note must never reach the team-scope file
  # that user B's context injection reads.
  run gate Write "$TEST_TMP/repo/.agents/memory/shared.md" "salary talk <private>do not share</private>"
  [ "$status" -eq 2 ]
  [[ "$output" == *"never promotes"* ]]
}

@test "memory-scope-gate: content referencing personal memory path blocked from team scope" {
  run gate Write "$TEST_TMP/repo/.agents/memory/shared.md" "see /Users/b/.claude/projects/x/memory/secret.md"
  [ "$status" -eq 2 ]
}

@test "memory-scope-gate: policy schema declares 3 scopes with defaultDeny" {
  run jq -r '.defaultDeny, (.scopes | keys | join(","))' "$REPO_ROOT/.harness/memory-scopes.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"true"* ]]
  [[ "$output" == *"org,personal,team"* ]]
}

# --- client rules (shelfmark registry) ---------------------------------------

client_setup() {  # an "acme" client rooted at $TEST_TMP/acme, with a lexicon
  mkdir -p "$TEST_TMP/acme/memory" "$TEST_TMP/acme/.client" "$TEST_TMP/home/.claude/projects/p/memory"
  printf 'walrus\n# comment\n' > "$TEST_TMP/acme/.client/lexicon.txt"
  # shelfmark writes resolved roots (macOS: /var -> /private/var), and so must the fixture
  jq -n --arg r "$(cd "$TEST_TMP/acme" && pwd -P)" '{acme: {db: "x", roots: [$r]}}' > "$TEST_TMP/clients.json"
  export SHELFMARK_CLIENTS="$TEST_TMP/clients.json"
  export MEMORY_REVIEW_QUEUE="$TEST_TMP/queue.jsonl"
  unset RAG_CLIENT
  GENERAL="$TEST_TMP/home/.claude/projects/p/memory/note.md"
}

@test "client: general memory write while client active needs knowledge tag" {
  client_setup; cd "$TEST_TMP/acme"
  run gate Write "$GENERAL" "---\nname: x\n---\nacme bills on the fifth"
  [ "$status" -eq 2 ]
  [[ "$output" == *"working for client 'acme'"* ]]
}

@test "client: technical lesson with knowledge tag may stay general" {
  client_setup; cd "$TEST_TMP/acme"
  run gate Write "$GENERAL" "---\nname: x\nknowledge: technical\n---\nmake retries idempotent"
  [ "$status" -eq 0 ]
  [[ "$output" != *"permissionDecision"* ]]
}

@test "client: writing to the client's own vault is always allowed" {
  client_setup; cd "$TEST_TMP/acme"
  run gate Write "$TEST_TMP/acme/memory/rule.md" "acme walrus billing rule"
  [ "$status" -eq 0 ]
  [[ "$output" != *"permissionDecision"* ]]
  [ ! -f "$MEMORY_REVIEW_QUEUE" ]
}

@test "client: no active client means no client rule" {
  client_setup; cd "$TEST_TMP/repo"
  run gate Write "$GENERAL" "plain note, no frontmatter"
  [ "$status" -eq 0 ]
}

@test "client: RAG_CLIENT=none switches client rules off" {
  client_setup; cd "$TEST_TMP/acme"
  RAG_CLIENT=none run gate Write "$GENERAL" "plain note"
  [ "$status" -eq 0 ]
}

@test "client: RAG_CLIENT activates the client outside its roots" {
  client_setup; cd "$TEST_TMP/repo"
  RAG_CLIENT=acme run gate Write "$GENERAL" "plain note"
  [ "$status" -eq 2 ]
}

@test "client: lexicon hit asks the operator and queues review, never silent" {
  client_setup; cd "$TEST_TMP/acme"
  run gate Write "$GENERAL" "---\nknowledge: technical\n---\nthe Walrus rule taught us to validate dates"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision":"ask"'* ]]
  run jq -r '.client + " " + (.terms | join(","))' "$MEMORY_REVIEW_QUEUE"
  [ "$output" = "acme walrus" ]
}

@test "client: Edit on an existing tagged general note reads frontmatter from disk" {
  client_setup; cd "$TEST_TMP/acme"
  printf -- '---\nknowledge: behavioral\n---\nold\n' > "$GENERAL"
  run bash -c 'printf "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"%s\",\"new_string\":\"new line\"}}" "$1" | bash "$2"' _ "$GENERAL" "$REPO_ROOT/hooks/memory-scope-gate.sh"
  [ "$status" -eq 0 ]
}

@test "client: no registry means client rules are inert" {
  client_setup; rm "$SHELFMARK_CLIENTS"; cd "$TEST_TMP/acme"
  run gate Write "$GENERAL" "plain note"
  [ "$status" -eq 0 ]
}

gate_json() {  # gate_json <payload json>
  printf '%s' "$1" | bash "$REPO_ROOT/hooks/memory-scope-gate.sh"
}

@test "client: writing into another client's vault is blocked" {
  client_setup; mkdir -p "$TEST_TMP/beta/memory"
  jq -n --arg a "$(cd "$TEST_TMP/acme" && pwd -P)" --arg b "$(cd "$TEST_TMP/beta" && pwd -P)" \
    '{acme: {db: "x", roots: [$a]}, beta: {db: "y", roots: [$b]}}' > "$SHELFMARK_CLIENTS"
  cd "$TEST_TMP/acme"
  run gate Write "$TEST_TMP/beta/memory/rule.md" "acme pricing notes"
  [ "$status" -eq 2 ]
  [[ "$output" == *"client 'beta'"* ]]
}

@test "client: general vault outside ~/.claude still needs the tag" {
  client_setup; mkdir -p "$TEST_TMP/kb/memory"; cd "$TEST_TMP/acme"
  run gate Write "$TEST_TMP/kb/memory/note.md" "acme bills on the fifth"
  [ "$status" -eq 2 ]
}

@test "client: general vault matched case-insensitively on macOS" {
  [ "$(uname -s)" = Darwin ] || skip "case-insensitive file systems only"
  client_setup; mkdir -p "$TEST_TMP/KB/Memory"; cd "$TEST_TMP/acme"
  run gate Write "$TEST_TMP/KB/Memory/note.md" "acme bills on the fifth"
  [ "$status" -eq 2 ]
}

@test "client: non-markdown file in a memory dir is not a note" {
  client_setup; cd "$TEST_TMP/acme"
  run gate Write "$TEST_TMP/home/.claude/projects/p/memory/.harvest-manifest.jsonl" "{}"
  [ "$status" -eq 0 ]
}

@test "client: invalid registry blocks memory writes" {
  client_setup; printf '{not json' > "$SHELFMARK_CLIENTS"; cd "$TEST_TMP/acme"
  run gate Write "$GENERAL" "plain note"
  [ "$status" -eq 2 ]
  [[ "$output" == *"registry"* ]]
  printf '{"acme": {"roots": "/x"}}' > "$SHELFMARK_CLIENTS"
  run gate Write "$GENERAL" "plain note"
  [ "$status" -eq 2 ]
}

@test "client: MultiEdit content is scanned for lexicon terms" {
  client_setup; cd "$TEST_TMP/acme"
  printf -- '---\nknowledge: technical\n---\nold\n' > "$GENERAL"
  run gate_json "$(jq -cn --arg p "$GENERAL" '{tool_name: "MultiEdit", tool_input: {file_path: $p, edits: [{old_string: "old", new_string: "the walrus rule"}]}}')"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision":"ask"'* ]]
}

@test "client: Edit that removes the knowledge tag is blocked" {
  client_setup; cd "$TEST_TMP/acme"
  printf -- '---\nknowledge: behavioral\n---\nold\n' > "$GENERAL"
  run gate_json "$(jq -cn --arg p "$GENERAL" '{tool_name: "Edit", tool_input: {file_path: $p, old_string: "knowledge: behavioral", new_string: "type: finding"}}')"
  [ "$status" -eq 2 ]
}

@test "client: tag in an unclosed frontmatter does not count" {
  client_setup; cd "$TEST_TMP/acme"
  run gate Write "$GENERAL" "---\nname: x\nknowledge: technical\nacme bills on the fifth"
  [ "$status" -eq 2 ]
}

@test "client: CRLF, quoted and nested tags are accepted" {
  client_setup; cd "$TEST_TMP/acme"
  run gate Write "$GENERAL" "---\r\nknowledge: technical\r\n---\r\nmake retries idempotent"
  [ "$status" -eq 0 ]
  run gate Write "$GENERAL" "---\nknowledge: 'behavioral'\n---\nconfirm before deleting"
  [ "$status" -eq 0 ]
  run gate Write "$GENERAL" "---\nmetadata:\n  knowledge: technical\n---\nmake retries idempotent"
  [ "$status" -eq 0 ]
}

@test "client: lexicon ask never skips the private-tag rule" {
  client_setup; cd "$TEST_TMP/repo"
  RAG_CLIENT=acme run gate Write "$TEST_TMP/repo/.agents/memory/shared.md" "---\nknowledge: technical\n---\nwalrus <private>x</private>"
  [ "$status" -eq 2 ]
  [[ "$output" == *"never promotes"* ]]
}

@test "client: MCP memory tool asks while a client is active" {
  client_setup; cd "$TEST_TMP/acme"
  run gate_json '{"tool_name":"mcp__memory__create_entities","tool_input":{"entities":[{"name":"Walrus billing"}]}}'
  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision":"ask"'* ]]
  run jq -r '.terms | join(",")' "$MEMORY_REVIEW_QUEUE"
  [ "$output" = "walrus" ]
}

@test "client: review queue defaults to the client's own vault" {
  client_setup; unset MEMORY_REVIEW_QUEUE; cd "$TEST_TMP/acme"
  run gate Write "$GENERAL" "---\nknowledge: technical\n---\nthe walrus rule"
  [ "$status" -eq 0 ]
  [ -s "$TEST_TMP/acme/.client/review-queue.jsonl" ]
}

@test "client: unknown RAG_CLIENT warns and still gates" {
  client_setup; cd "$TEST_TMP/repo"
  RAG_CLIENT=ghost run gate Write "$GENERAL" "plain note"
  [ "$status" -eq 2 ]
  [[ "$output" == *"not in"* ]]
}

@test "deploy: the installed gate matches hooks/ and is wired for memory writes" {
  cmp "$REPO_ROOT/hooks/memory-scope-gate.sh" "$REPO_ROOT/claude/hooks/memory-scope-gate.sh"
  run jq -r '.hooks.PreToolUse[] | select(any(.hooks[]; .command | contains("memory-scope-gate.sh"))) | .matcher' "$REPO_ROOT/claude/settings.json"
  [ "$status" -eq 0 ]
  for t in Write Edit MultiEdit mcp__memory__create_entities; do
    [[ "$t" =~ ^($output)$ ]]
  done
}
