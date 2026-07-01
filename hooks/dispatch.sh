#!/usr/bin/env bash
# dispatch.sh - deterministic orchestration substrate (P4 multi-agent).
#
# The Wave-5 multi-agent track converged on one hard rule: NO LLM DECIDES WHAT
# FIRES NEXT. Routing and state transitions live in a deterministic substrate
# (division-sh/swarm + Malphite10 + SMALL protocol + tascade). Bounded LLM
# workers execute individual steps; the substrate owns the state machine so
# the model can't silently re-order, skip gates, or self-promote.
#
# This hook is the deterministic router. It reads a task descriptor, resolves
# the next step from a fixed state machine, and emits a dispatch packet telling
# a bounded worker exactly what to run and where to hand off. It subsumes and
# coordinates the P2 proposer/evaluator pair (propose.sh + eval-baseline.sh):
# those are bounded workers that the router invokes, not peers that decide.
#
# State machine (the ONLY source of truth for transitions):
#
#   intake -> triage -> plan -> [research] -> implement -> review_gate
#                                                      -> eval -> merge_gate
#                                                      -> BLOCKED (retry/escalate)
#                                                                  -> done | failed
#
# review_gate and merge_gate are the two human-in-the-loop checkpoints. The
# model cannot transition past either without an explicit allow from the host
# agent. BLOCKED is a first-class state (not a failure) - it means a worker
# needs input and the router parked it rather than guessing.
#
# Usage:
#   hooks/dispatch.sh <task-id> --intake "<task>"   # create a task at intake
#   hooks/dispatch.sh <task-id> --advance           # advance to next state
#   hooks/dispatch.sh <task-id> --block "<reason>"  # park as BLOCKED
#   hooks/dispatch.sh <task-id> --allow-gate <name> # pass a review/merge gate
#   hooks/dispatch.sh <task-id> --status            # print task state
#   hooks/dispatch.sh --list                         # list all tasks + states
#
# Exit 0 always (dispatch is advisory; gates are enforced by the host agent).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME="$ROOT/.harness/runtime/dispatch"
LEDGER="$RUNTIME/tasks.jsonl"
mkdir -p "$RUNTIME"

# Deterministic transition table: state -> next state on --advance.
# Gates (review_gate, merge_gate) are NOT advanced past by --advance alone;
# they require --allow-gate. BLOCKED does not advance on --advance.
declare -A NEXT=(
  [intake]=triage
  [triage]=plan
  [plan]=research
  [research]=implement
  [implement]=review_gate
  [review_gate]=eval
  [eval]=merge_gate
  [merge_gate]="done"
)
# Gates: states that require an explicit allow before advancing.
declare -A IS_GATE=(
  [review_gate]=1
  [merge_gate]=1
)

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

task_id=""
action=""
arg=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --list)
      [[ -s "$LEDGER" ]] || { echo "no tasks yet"; exit 0; }
      # Print the LATEST state line per task (last write wins).
      mapfile -t lines < <(jq -r '[.task_id,.state,.ts,.summary] | @tsv' "$LEDGER" 2>/dev/null)
      declare -A latest
      for l in "${lines[@]}"; do
        id="$(printf '%s' "$l" | cut -f1)"
        latest["$id"]="$l"
      done
      for id in "${!latest[@]}"; do
        printf '%s\n' "${latest[$id]}"
      done | sort
      exit 0 ;;
    --intake) action="intake"; arg="$2"; shift 2 ;;
    --advance) action="advance"; shift ;;
    --block) action="block"; arg="$2"; shift 2 ;;
    --allow-gate) action="allow_gate"; arg="$2"; shift 2 ;;
    --status) action="status"; shift ;;
    *) task_id="$1"; shift ;;
  esac
done

die() { echo "dispatch: $*" >&2; exit 2; }

[[ -n "$task_id" ]] || die "usage: dispatch.sh <task-id> --intake <task> | --advance | --block <reason> | --allow-gate <name> | --status | --list"
[[ -n "$action" ]] || die "no action given for task $task_id"

# --- Load current state (last record for this task) ------------------------
current_state=""
summary=""
if [[ -s "$LEDGER" ]]; then
  rec="$(rg "\"task_id\":\"$task_id\"" "$LEDGER" 2>/dev/null | tail -1)"
  if [[ -n "$rec" ]]; then
    current_state="$(printf '%s' "$rec" | jq -r '.state // empty' 2>/dev/null)"
    summary="$(printf '%s' "$rec" | jq -r '.summary // empty' 2>/dev/null)"
  fi
fi

case "$action" in
  intake)
    [[ -z "$current_state" ]] || die "task $task_id already exists (state=$current_state)"
    [[ -n "$arg" ]] || die "intake requires a task summary"
    new_state="intake"
    summary="$arg"
    ;;
  advance)
    [[ -n "$current_state" ]] || die "task $task_id not found (use --intake first)"
    # BLOCKED does not advance silently.
    [[ "$current_state" == "BLOCKED" ]] && die "task $task_id is BLOCKED; resolve the blocker or --allow-gate"
    # Gates require an explicit allow.
    [[ -n "${IS_GATE[$current_state]:-}" ]] && die "task $task_id is at gate $current_state; use --allow-gate $current_state to pass"
    new_state="${NEXT[$current_state]:-done}"
    [[ -z "${NEXT[$current_state]:-}" ]] && die "task $task_id is terminal ($current_state); nothing to advance"
    ;;
  block)
    [[ -n "$current_state" ]] || die "task $task_id not found"
    [[ -n "$arg" ]] || die "block requires a reason"
    new_state="BLOCKED"
    summary="${summary} | BLOCKED: $arg"
    ;;
  allow_gate)
    [[ -n "$current_state" ]] || die "task $task_id not found"
    [[ -n "${IS_GATE[$current_state]:-}" ]] || die "task $task_id is not at a gate (state=$current_state)"
    [[ "$arg" == "$current_state" ]] || die "gate mismatch: at $current_state, asked to pass $arg"
    new_state="${NEXT[$current_state]}"
    ;;
  status)
    [[ -n "$current_state" ]] || { echo "task $task_id not found"; exit 0; }
    echo "task:    $task_id"
    echo "state:   $current_state"
    echo "summary: $summary"
    echo "ts:      $ts"
    exit 0
    ;;
esac

# --- Emit the dispatch packet (append-only ledger) --------------------------
worker=""
case "$new_state" in
  intake|triage|plan)      worker="host" ;;
  research|implement)      worker="bounded-worker" ;;
  review_gate|merge_gate)  worker="host (gate)" ;;
  eval)                    worker="bounded-worker" ;;
  done)                    worker="none" ;;
  BLOCKED)                 worker="host (unblock)" ;;
esac

jq -nc \
  --arg ts "$ts" \
  --arg task_id "$task_id" \
  --arg state "$new_state" \
  --arg summary "$summary" \
  --arg worker "$worker" \
  '{ts:$ts, event:"dispatch", task_id:$task_id, state:$state, summary:$summary, worker:$worker}' \
  >> "$LEDGER"

echo "dispatch: task=$task_id state=$current_state -> $new_state (worker=$worker)" >&2
[[ "$new_state" == "BLOCKED" ]] && echo "  BLOCKED is a first-class park; resolve then --advance or --allow-gate" >&2
exit 0
