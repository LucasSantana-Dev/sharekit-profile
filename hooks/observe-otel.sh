#!/usr/bin/env bash
# observe-otel.sh — two-knob observability + context-breach scanning.
#
# Two-knob model (pdhoolia): a GLOBAL default verbosity + a PER-PROJECT
# override. Knob 1 = level (off|metrics|trace), knob 2 = destination
# (stderr|jsonl|otel). This hook is the local, optional starting point that
# matches the repo's no-cloud posture — wire a real OTEL exporter later by
# setting OTEL_EXPORTER_OTLP_ENDPOINT; until then it emits JSONL spans.
#
# Spans (GenAI semantic conventions, simplified):
#   - gen_ai.tool.call     (per PostToolUse)
#   - gen_ai.session.start (SessionStart)
#   - gen_ai.session.end   (SessionEnd)
#   - context.breach       (fired when estimated context > threshold)
#
# Context-breach scanning: if the trajectory log shows the agent is approaching
# the model's context window, emit a breach span + a stderr nudge so the host
# agent can compact. This is the early-warning system for "lost-in-the-middle"
# before it happens.
#
# Idempotent ±1 feedback scores: a feedback file records +1/-1 per session,
# written on explicit signal (not auto), so improvement is attributable.
#
# Usage:
#   As a hook (PostToolUse / SessionStart / SessionEnd) — reads stdin JSON.
#   hooks/observe-otel.sh feedback +1 "rationale"   # record idempotent score
#   hooks/observe-otel.sh status                     # print current knobs + last spans
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME="$ROOT/.harness/runtime"
SPANS="$RUNTIME/otel-spans.jsonl"
FEEDBACK="$RUNTIME/feedback.jsonl"
mkdir -p "$RUNTIME"

# --- Two-knob resolution -----------------------------------------------------
# Knob 1 (level): env OBSERVE_LEVEL > project file > global default "metrics".
# Knob 2 (destination): env OBSERVE_DEST > "jsonl" (local default).
level="${OBSERVE_LEVEL:-}"
if [[ -z "$level" ]] && [[ -f "$ROOT/.harness/observe.json" ]]; then
  level="$(jq -r '.level // empty' "$ROOT/.harness/observe.json" 2>/dev/null || true)"
fi
level="${level:-metrics}"
dest="${OBSERVE_DEST:-jsonl}"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- CLI subcommands (feedback / status) -----------------------------------
if [[ "${1:-}" == "feedback" ]]; then
  shift
  score="${1:-}"; rationale="${2:-}"
  [[ "$score" =~ ^[+-]?1$ ]] || { echo "observe-otel: feedback score must be +1 or -1" >&2; exit 2; }
  printf '{"ts":"%s","event":"feedback","score":%s,"rationale":"%s"}\n' \
    "$ts" "$score" "$rationale" >> "$FEEDBACK"
  echo "feedback recorded: $score ($rationale)"
  exit 0
fi

if [[ "${1:-}" == "status" ]]; then
  echo "observe-otel: level=$level dest=$dest"
  echo "spans: $SPANS ($(wc -l < "$SPANS" 2>/dev/null || echo 0) lines)"
  echo "feedback: $FEEDBACK ($(wc -l < "$FEEDBACK" 2>/dev/null || echo 0) scores)"
  if [[ -f "$SPANS" ]]; then
    echo "last 5 spans:"
    tail -5 "$SPANS" | bat -p --language json 2>/dev/null || tail -5 "$SPANS"
  fi
  exit 0
fi

# If level is off, do nothing (but still exit 0 — never block).
[[ "$level" == "off" ]] && exit 0

# --- Hook mode: read stdin JSON ---------------------------------------------
input="$(cat)"
tool_name="$(printf '%s' "$input" | jq -r '.tool_name // .tool // empty' 2>/dev/null || true)"
session_id="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null || true)"
hook_event="${OBSERVE_HOOK_EVENT:-PostToolUse}"

emit() {
  # emit <json> — write to the configured destination.
  local json="$1"
  case "$dest" in
    jsonl) printf '%s\n' "$json" >> "$SPANS" ;;
    stderr) printf '%s\n' "$json" >&2 ;;
    otel)
      # If an OTEL exporter is configured, ship via curl (best-effort, non-fatal).
      if [[ -n "${OTEL_EXPORTER_OTLP_ENDPOINT:-}" ]]; then
        curl -s -m 2 -X POST -H 'Content-Type: application/json' \
          -d "$json" "$OTEL_EXPORTER_OTLP_ENDPOINT/v1/traces" 2>/dev/null || true
      else
        printf '%s\n' "$json" >> "$SPANS"
      fi
      ;;
  esac
}

case "$hook_event" in
  PostToolUse)
    printf -v span '{"ts":"%s","name":"gen_ai.tool.call","session":"%s","tool":"%s"}' \
      "$ts" "$session_id" "$tool_name"
    emit "$span"
    ;;
  SessionStart)
    printf -v span '{"ts":"%s","name":"gen_ai.session.start","session":"%s"}' \
      "$ts" "$session_id"
    emit "$span"
    ;;
  SessionEnd)
    printf -v span '{"ts":"%s","name":"gen_ai.session.end","session":"%s"}' \
      "$ts" "$session_id"
    emit "$span"
    ;;
esac

# --- Context-breach scan (only on PostToolUse, only if trajectory exists) ----
TRAJ="$RUNTIME/trajectory.jsonl"
if [[ "$hook_event" == "PostToolUse" && -f "$TRAJ" ]]; then
  # Rough context estimate: sum of response lengths in the current session.
  # Threshold defaults to 120000 chars (~30k tokens); override via OBSERVE_CTX_LIMIT.
  ctx_limit="${OBSERVE_CTX_LIMIT:-120000}"
  est_ctx="$(jq -s 'map((.response|length) + (.input|length)) | add // 0' "$TRAJ" 2>/dev/null || echo 0)"
  if [[ "$est_ctx" -gt "$ctx_limit" ]]; then
    printf -v breach '{"ts":"%s","name":"context.breach","session":"%s","est_ctx":%s,"limit":%s}\n' \
      "$ts" "$session_id" "$est_ctx" "$ctx_limit"
    emit "$breach"
    printf 'observe-otel: context breach — est %s > limit %s; consider compacting.\n' \
      "$est_ctx" "$ctx_limit" >&2
  fi
fi

exit 0
