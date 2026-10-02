#!/usr/bin/env bats
# tests/context-hooks.bats - context lifecycle hooks: snapshot-compact, reinject-compact,
# reorder-context, session-start-load, session-end-flush, compaction-guard, context-guard.
# Hermetic: hooks run from a copy of hooks/ in $BATS_TEST_TMPDIR (ROOT-relative state
# lands in the copy) and HOME/BRAIN_ROOT point inside the tmpdir, never the real ~/.claude.

setup() {
  export REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export FAKE="$BATS_TEST_TMPDIR/root"
  export HOME="$BATS_TEST_TMPDIR/home"
  export BRAIN_ROOT="$BATS_TEST_TMPDIR/brain"
  mkdir -p "$FAKE/hooks" "$FAKE/.harness/runtime" "$HOME"
  cp -R "$REPO_ROOT/hooks/." "$FAKE/hooks/"
  RT="$FAKE/.harness/runtime"
}

hook() { local h="$1"; shift; bash "$FAKE/hooks/$h.sh" "$@"; }
need() { command -v "$1" >/dev/null 2>&1 || skip "$1 not installed"; }

# --- snapshot-compact -------------------------------------------------------

@test "snapshot-compact: JSON payload is wrapped with ts and saved, exit 0" {
  run bash -c "printf '%s' '{\"trigger\":\"auto\"}' | bash '$FAKE/hooks/snapshot-compact.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PreCompact snapshot written:"* ]]
  f="$(ls "$RT"/compact/pre-*.json)"
  [ "$(jq -r '.payload.trigger' "$f")" = "auto" ]
  [ -n "$(jq -r '.ts' "$f")" ]
}

@test "snapshot-compact: non-JSON payload is saved to .raw with a note" {
  run bash -c "printf '%s' 'not json {' | bash '$FAKE/hooks/snapshot-compact.sh' 2>&1"
  [ "$status" -eq 0 ]
  raw="$(ls "$RT"/compact/pre-*.json.raw)"
  [ "$(cat "$raw")" = "not json {" ]
  [[ "$(jq -r '.note' "$RT"/compact/pre-*.json)" == *"non-json payload"* ]]
}

@test "snapshot-compact: empty stdin still exits 0 and writes a snapshot" {
  run bash -c "printf '' | bash '$FAKE/hooks/snapshot-compact.sh' 2>&1"
  [ "$status" -eq 0 ]
  [ -n "$(ls "$RT"/compact/ 2>/dev/null)" ]
}

# --- reinject-compact -------------------------------------------------------

@test "reinject-compact: emits CORE.md from BRAIN_ROOT with header and footer" {
  mkdir -p "$BRAIN_ROOT"; printf 'brain core rule\n' > "$BRAIN_ROOT/CORE.md"
  run hook reinject-compact
  [ "$status" -eq 0 ]
  [[ "$output" == *"Re-injected CORE memory (PostCompact)"* ]]
  [[ "$output" == *"brain core rule"* ]]
  [[ "$output" == *"Re-injected by hooks/reinject-compact.sh"* ]]
}

@test "reinject-compact: falls back to the repo example CORE.md when BRAIN_ROOT has none" {
  mkdir -p "$FAKE/claude/memory-structure/examples"; printf 'example core\n' > "$FAKE/claude/memory-structure/examples/CORE.md"
  run hook reinject-compact
  [ "$status" -eq 0 ]
  [[ "$output" == *"example core"* ]]
}

@test "reinject-compact: BRAIN_ROOT CORE.md wins over the example fallback" {
  mkdir -p "$BRAIN_ROOT" "$FAKE/claude/memory-structure/examples"
  printf 'brain wins\n' > "$BRAIN_ROOT/CORE.md"; printf 'example loses\n' > "$FAKE/claude/memory-structure/examples/CORE.md"
  run hook reinject-compact
  [[ "$output" == *"brain wins"* ]]
  [[ "$output" != *"example loses"* ]]
}

@test "reinject-compact: no CORE.md anywhere logs postcompact-no-core, prints nothing, exit 0" {
  run hook reinject-compact
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(jq -r '.event' "$RT/trajectory.jsonl")" = "postcompact-no-core" ]
}

# --- reorder-context --------------------------------------------------------

reorder() { printf '%s' "$1" | bash "$FAKE/hooks/reorder-context.sh" 2>&1; }

@test "reorder-context: rag tool chunks are interleaved with best at both ends" {
  run reorder '{"tool_name":"mcp__rag-index__query","tool_response":{"chunks":[{"id":"a","score":0.9},{"id":"b","score":0.8},{"id":"c","score":0.7},{"id":"d","score":0.6}]}}'
  [ "$status" -eq 0 ]
  [[ "$output" == *"reordered 4 chunks"* ]]
  [ "$(jq -c '[.reordered_chunks[].id]' "$RT"/reordered-chunks/*.json)" = '["a","c","d","b"]' ]
  [ "$(jq -r '.chunk_count' "$RT"/reordered-chunks/*.json)" = "4" ]
}

@test "reorder-context: accepts a bare array response and sorts unsorted input by score" {
  run reorder '{"tool_name":"recall","tool_response":[{"id":"lo","score":0.1},{"id":"hi","score":0.9},{"id":"mid","score":0.5}]}'
  [ "$status" -eq 0 ]
  [ "$(jq -c '[.reordered_chunks[].id]' "$RT"/reordered-chunks/*.json)" = '["hi","lo","mid"]' ]
}

@test "reorder-context: non-retrieval tool is ignored with no digest" {
  run reorder '{"tool_name":"Bash","tool_response":{"chunks":[{"id":"a","score":1}]}}'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -z "$(ls "$RT"/reordered-chunks 2>/dev/null)" ]
}

@test "reorder-context: more than 50 chunks is skipped" {
  big="$(jq -nc '{tool_name:"recall",tool_response:{chunks:[range(0;51)|{id:.,score:.}]}}')"
  run reorder "$big"
  [ "$status" -eq 0 ]
  [ -z "$(ls "$RT"/reordered-chunks 2>/dev/null)" ]
}

@test "reorder-context: malformed JSON exits 0 with no digest" {
  run reorder 'not json {'
  [ "$status" -eq 0 ]
  [ -z "$(ls "$RT"/reordered-chunks 2>/dev/null)" ]
}

@test "reorder-context: empty stdin exits 0" {
  run reorder ''
  [ "$status" -eq 0 ]
}

@test "reorder-context: retrieval tool with empty chunk list writes no digest" {
  run reorder '{"tool_name":"recall","tool_response":{"chunks":[]}}'
  [ "$status" -eq 0 ]
  [ -z "$(ls "$RT"/reordered-chunks 2>/dev/null)" ]
}

# --- session-start-load -----------------------------------------------------

@test "session-start-load: loads CORE.md and appends a start boundary marker" {
  mkdir -p "$BRAIN_ROOT"; printf 'start core\n' > "$BRAIN_ROOT/CORE.md"
  run bash -c "bash '$FAKE/hooks/session-start-load.sh' 2>/dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CORE memory (SessionStart load)"* ]]
  [[ "$output" == *"start core"* ]]
  [ "$(jq -r '.direction' "$RT/trajectory.jsonl")" = "start" ]
}

@test "session-start-load: no CORE.md prints nothing but still writes the boundary, exit 0" {
  run bash -c "bash '$FAKE/hooks/session-start-load.sh' 2>/dev/null"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(jq -r '.event' "$RT/trajectory.jsonl")" = "session-boundary" ]
}

@test "session-start-load: flywheel log older than 7 days warns on stderr" {
  touch -t 202001010000 "$RT/cycle-old.log"
  run bash -c "bash '$FAKE/hooks/session-start-load.sh' 2>&1 >/dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" == *"flywheel silent"* ]]
  [[ "$output" == *"cycle-old.log"* ]]
}

@test "session-start-load: fresh flywheel log does not warn" {
  touch "$RT/cycle-new.log"
  run bash -c "bash '$FAKE/hooks/session-start-load.sh' 2>&1 >/dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" != *"flywheel silent"* ]]
}

@test "session-start-load: drift between HOME/.claude and HOME/.claude-env warns but exits 0" {
  mkdir -p "$HOME/.claude/hooks" "$HOME/.claude-env/hooks"
  printf 'a\n' > "$HOME/.claude/hooks/x.sh"; printf 'b\n' > "$HOME/.claude-env/hooks/x.sh"
  run bash -c "bash '$FAKE/hooks/session-start-load.sh' 2>&1 >/dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" == *"harness drift detected"* ]]
}

@test "session-start-load: ignores stdin (empty input is fine)" {
  run bash -c "printf '' | bash '$FAKE/hooks/session-start-load.sh' 2>&1"
  [ "$status" -eq 0 ]
}

# --- session-end-flush ------------------------------------------------------

@test "session-end-flush: summarizes tool-call events into record, index, pending and end marker" {
  cat > "$RT/trajectory.jsonl" <<'J'
{"ts":"t1","event":"tool-call","tool":"Bash","outcome":"ok"}
{"ts":"t2","event":"tool-call","tool":"Bash","outcome":"error"}
{"ts":"t3","event":"tool-call","tool":"Edit","outcome":"blocked"}
{"ts":"t4","event":"other"}
J
  run hook session-end-flush
  [ "$status" -eq 0 ]
  [[ "$output" == *"SessionEnd: session record written"* ]]
  rec="$(ls "$RT"/sessions/session-*.json)"
  [ "$(jq -r '.tool_calls' "$rec")" = "3" ]
  [ "$(jq -r '.errors' "$rec")" = "1" ]
  [ "$(jq -r '.blocked' "$rec")" = "1" ]
  [ "$(wc -l < "$RT/sessions/index.jsonl" | tr -d ' ')" = "1" ]
  [ "$(wc -l < "$RT/pending-distill.jsonl" | tr -d ' ')" = "1" ]
  [ "$(tail -n 1 "$RT/trajectory.jsonl" | jq -r '.direction')" = "end" ]
}

@test "session-end-flush: top_tools counts tools ordered by count desc, max 5" {
  {
    printf '%s\n' '{"ts":"t1","event":"tool-call","tool":"Bash","outcome":"ok"}'
    printf '%s\n' '{"ts":"t2","event":"tool-call","tool":"Bash","outcome":"ok"}'
    printf '%s\n' '{"ts":"t3","event":"tool-call","tool":"Read","outcome":"ok"}'
    for t in A B C D E; do printf '{"ts":"x","event":"tool-call","tool":"%s","outcome":"ok"}\n' "$t"; done
  } > "$RT/trajectory.jsonl"
  run hook session-end-flush
  [ "$status" -eq 0 ]
  rec="$(ls "$RT"/sessions/session-*.json)"
  [ "$(jq -c '.top_tools[0]' "$rec")" = '{"count":2,"tool":"Bash"}' ]
  [ "$(jq -r '.top_tools | length' "$rec")" = "5" ]
}

@test "session-end-flush: missing trajectory yields a zeroed record and exit 0" {
  rm -f "$RT/trajectory.jsonl"
  run hook session-end-flush
  [ "$status" -eq 0 ]
  rec="$(ls "$RT"/sessions/session-*.json)"
  [ "$(jq -r '.tool_calls' "$rec")" = "0" ]
  [ "$(jq -c '.top_tools' "$rec")" = "[]" ]
}

@test "session-end-flush: malformed trajectory lines do not crash the hook" {
  printf 'garbage {{{\n' > "$RT/trajectory.jsonl"
  run hook session-end-flush
  [ "$status" -eq 0 ]
  [ -f "$RT/pending-distill.jsonl" ]
}

# --- compaction-guard -------------------------------------------------------

@test "compaction-guard: writes directive and jsonl marker, never blocks" {
  run bash -c "printf '%s' '{}' | bash '$FAKE/hooks/compaction-guard.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"directive written (0 at-risk pairs)"* ]]
  d="$(ls "$RT"/compact/directive-*.md)"
  grep -q 'No unpaired tool calls detected' "$d"
  grep -q 'threshold not assessed' "$d"
  [ "$(jq -r '.event' "$RT/compaction-guard.jsonl")" = "compaction-directive" ]
}

@test "compaction-guard: utilization above 85 percent flags late compaction" {
  run bash -c "printf '%s' '{\"context_utilization\":\"92%\"}' | bash '$FAKE/hooks/compaction-guard.sh' 2>&1"
  [ "$status" -eq 0 ]
  grep -q 'firing LATE (92% > 85%)' "$RT"/compact/directive-*.md
}

@test "compaction-guard: utilization at or below 85 percent is within band" {
  run bash -c "printf '%s' '{\"usage\":{\"percent\":60}}' | bash '$FAKE/hooks/compaction-guard.sh' 2>&1"
  [ "$status" -eq 0 ]
  grep -q 'within/under the ~70-85% band' "$RT"/compact/directive-*.md
}

@test "compaction-guard: tool-call with no outcome is reported as an at-risk pair" {
  printf '%s\n' '{"event":"tool-call","tool":"Bash"}' '{"event":"tool-call","tool":"Edit","outcome":"ok"}' > "$RT/trajectory.jsonl"
  run bash -c "printf '' | bash '$FAKE/hooks/compaction-guard.sh' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"1 at-risk pairs"* ]]
  grep -q 'Bash: call with no recorded result' "$RT"/compact/directive-*.md
}

@test "compaction-guard: malformed payload exits 0 and notes no utilization" {
  run bash -c "printf '%s' 'not json {' | bash '$FAKE/hooks/compaction-guard.sh' 2>&1"
  [ "$status" -eq 0 ]
  grep -q 'threshold not assessed' "$RT"/compact/directive-*.md
}

@test "compaction-guard: --status with no directives says so" {
  run hook compaction-guard --status
  [ "$status" -eq 0 ]
  [ "$output" = "no compaction directives yet" ]
}

@test "compaction-guard: --status prints the latest directive" {
  mkdir -p "$RT/compact"; printf 'DIRECTIVE BODY\n' > "$RT/compact/directive-20260101T000000Z.md"
  run hook compaction-guard --status
  [ "$status" -eq 0 ]
  [[ "$output" == *"DIRECTIVE BODY"* ]]
}

# --- context-guard (needs rg) -----------------------------------------------

guard() { printf '%s' "$1" | bash "$FAKE/hooks/context-guard.sh" 2>&1; }

@test "context-guard: oversized response writes a digest and nudges on stderr" {
  need rg
  big="$(head -c 3000 /dev/zero | tr '\0' 'x')"
  run guard "{\"tool_name\":\"Bash\",\"tool_response\":\"$big\"}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"compact digest written"* ]]
  [ -n "$(ls "$RT"/tool-digests/*_Bash.digest)" ]
}

@test "context-guard: small response writes no digest" {
  need rg
  run guard '{"tool_name":"Bash","tool_response":"ok"}'
  [ "$status" -eq 0 ]
  [ -z "$(ls "$RT"/tool-digests 2>/dev/null)" ]
}

@test "context-guard: constraint words are appended to the recap file" {
  need rg
  run guard '{"tool_name":"Bash","tool_response":"you MUST run tests"}'
  [ "$status" -eq 0 ]
  grep -q 'you MUST run tests' "$RT/constraints-recap.md"
}

@test "context-guard: response without constraint words creates no recap" {
  need rg
  run guard '{"tool_name":"Bash","tool_response":"hello world"}'
  [ ! -f "$RT/constraints-recap.md" ]
}

@test "context-guard: read tools are marked static, others dynamic" {
  need rg
  guard '{"tool_name":"Read","tool_response":"x"}' >/dev/null
  guard '{"tool_name":"Bash","tool_response":"x"}' >/dev/null
  [ "$(sed -n 1p "$RT/cache-boundary.jsonl" | jq -r '.boundary')" = "static" ]
  [ "$(sed -n 2p "$RT/cache-boundary.jsonl" | jq -r '.boundary')" = "dynamic" ]
}

@test "context-guard: malformed JSON exits 0 and still logs a boundary" {
  need rg
  run guard 'not json {'
  [ "$status" -eq 0 ]
  [ "$(jq -r '.boundary' "$RT/cache-boundary.jsonl")" = "dynamic" ]
}

@test "context-guard: empty stdin exits 0" {
  need rg
  run guard ''
  [ "$status" -eq 0 ]
}
