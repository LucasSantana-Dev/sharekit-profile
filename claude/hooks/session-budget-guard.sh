#!/usr/bin/env bash
set -uo pipefail

# PostToolUse hook: session context-health nudge (USAGE-PLAN aware).
#
# We operate on a Claude subscription / usage plan — NOT pay-per-token billing.
# Therefore this hook does NOT compute a dollar cost and does NOT coerce a stop/handoff.
# (The previous version fabricated $ from API list pricing and forced a checkpoint at a
#  "$250 runaway" threshold — meaningless on a usage plan, and it interrupted real work.)
#
# Division of responsibility:
#   - rate-limit-watch.sh  -> the REAL usage guard: reads anthropic-ratelimit-*-remaining
#       headers (the actual plan constraint) and is the ONLY hook allowed to tell the agent
#       to pause/handoff, and only when genuine headroom is low.
#   - this hook            -> a soft, ADVISORY context-window hygiene nudge (non-redundant:
#       rate-limit-watch does not look at context size). Emits systemMessage only — never an
#       agent directive. The user decides whether to /compact.

command -v jq &>/dev/null || exit 0
SESSION_ID=$(jq -r '.session_id // empty' 2>/dev/null || echo "")
[[ -z "$SESSION_ID" ]] && exit 0

CACHE_CALLS="/tmp/claude-ctxnudge-calls-${SESSION_ID}.txt"
RECOMPUTE_INTERVAL=25
# Concurrent PostToolUse invocations (parallel subagents) race this counter: a reader can
# catch the file mid-truncate and feed garbage/empty into arithmetic. Sanitize the read and
# write via mv (atomic) so a partial state is never observable. Occasional lost increments
# are fine — the counter only paces an advisory nudge.
COUNT=$(cat "$CACHE_CALLS" 2>/dev/null | tr -dc '0-9'); COUNT=${COUNT:-0}
CALL_COUNT=$(( COUNT + 1 ))
TMP_CALLS="${CACHE_CALLS}.$$"; echo "$CALL_COUNT" > "$TMP_CALLS" && mv -f "$TMP_CALLS" "$CACHE_CALLS"
(( CALL_COUNT % RECOMPUTE_INTERVAL != 0 )) && exit 0

JSONL=$(find ~/.claude/projects -name "${SESSION_ID}.jsonl" 2>/dev/null | head -1)
[[ -z "$JSONL" || ! -f "$JSONL" ]] && exit 0

# SMART, factor-aware thresholds — set from the four inputs the operator named:
#   provider/model    -> WINDOW   (opus/1m/any session >200K => 1,000,000; else 200,000;
#                                   message.model lacks the '[1m]' tag, so infer by family+size)
#   initial context   -> FLOOR    (first assistant turn's input+cache = the re-injected baseline:
#                                   system prompt + CLAUDE.md + memory + tools + 1st user msg;
#                                   in a compacted/resumed session this is the summary baseline)
#   subagents work    -> SUBAGENTS (count of Task/Agent/Workflow dispatches — their returned
#                                   reports land back in-context, so reserve more headroom)
#   current occupancy -> CTX      (most recent assistant turn's input+cache_read+cache_write)
#
# We trigger on ABSOLUTE REMAINING headroom (window - ctx), not a fixed %: a complex task needs
# room to finish + survive a subagent round-trip, and that room is an absolute count.
#
# CALIBRATED 2026-06-15 against 52 real main-session JSONLs / 36 compaction events (calib_ctx.py):
#   - Built-in auto-compact fired no earlier than ~92% occupancy (clustered ~99%). So `hard` must
#     clear 92% with margin -> base hard reserve 0.13*usable puts hard at ~88% on a typical 1M
#     session (~4pp / ~40K runway below the built-in floor). Old 0.10 fired at ~91% — too close.
#   - Floors are heavy + bimodal (1M median 8.6%, up to 20%; 200K median 47%). A reserve term that
#     grows with floor-ABOVE-NORM (0.10*window) makes heavy-baseline sessions warn earlier, where
#     working room is genuinely scarcer; additive (not max) so it composes across both regimes.
#   - Subagent dispatches: >=6 was useless (62% of sessions hit it). Top quartile is ~20, and
#     subagent-heavy sessions peak markedly higher (1M 64% vs 32%) -> SUB_HEAVY=20 adds reserve so
#     warnings fire before a sudden return-jump.
# Bands: ~79%/88% soft/hard on a typical 1M session; earlier when floor is heavy or subagents many.
READOUT=$(JSONL="$JSONL" python3 -c "
import json, os
ctx=0; floor=0; model='sonnet'; subagents=0
_SUB={'task','agent','workflow'}
try:
    with open(os.environ['JSONL']) as f:
        for line in f:
            line=line.strip()
            if not line: continue
            try: e=json.loads(line)
            except Exception: continue
            if e.get('type')!='assistant' or e.get('isSidechain'): continue
            m=e.get('message',{}); u=m.get('usage',{})
            for blk in (m.get('content') or []):
                if isinstance(blk,dict) and blk.get('type')=='tool_use' and str(blk.get('name','')).lower() in _SUB:
                    subagents+=1
            if not u: continue
            model=(m.get('model') or model).lower()
            cur=u.get('input_tokens',0)+u.get('cache_read_input_tokens',0)+u.get('cache_creation_input_tokens',0)
            if floor==0 and cur>0: floor=cur   # first turn carrying usage = the injected baseline
            ctx=cur
except Exception:
    pass
window = 1_000_000 if ('1m' in model or 'opus' in model or ctx > 200_000) else 200_000
floor  = min(max(floor,0), window-1)
usable = window - floor
remaining = window - ctx
# Calibrated additive reserves (see header). Each term maps to a measured quantity:
floor_excess = max(0, floor - 0.10*window)        # baseline beyond the ~10%-of-window norm
sub_bump     = (0.05*usable if subagents >= 20 else 0.0)  # top-quartile orchestration load
hard = 0.13*usable + 0.50*floor_excess + sub_bump          # -> ~88% on a typical 1M session
soft = hard + 0.10*usable                                  # gentle heads-up ~9pp earlier
hard = min(hard, 0.85*usable); soft = min(soft, 0.92*usable)  # never pin to always-fire
band = 'hard' if remaining <= hard else ('soft' if remaining <= soft else '')
pct = int(100*ctx/window) if window else 0
print(f'{band} {pct} {round(ctx/1000)} {round(floor/1000)} {subagents}')
" 2>/dev/null) || exit 0

read -r band PCT CTX_K FLOOR_K SUBN <<<"$READOUT"
[[ -z "${band:-}" || ! "${PCT:-x}" =~ ^[0-9]+$ ]] && exit 0
FLAG="/tmp/claude-ctxnudge-${SESSION_ID}-${band}"
[[ -f "$FLAG" ]] && exit 0
touch "$FLAG"

SUBNOTE=""; (( SUBN >= 20 )) && SUBNOTE=" ${SUBN} subagent runs — reserve widened."
if [[ "$band" == "hard" ]]; then
  jq -n --arg p "$PCT" --arg k "$CTX_K" --arg f "$FLOOR_K" --arg s "$SUBNOTE" '{systemMessage: ("[orange] Context ~" + $p + "% (~" + $k + "K used, ~" + $f + "K is fixed project baseline)." + $s + " Headroom is getting tight for complex work — /compact at the next clean breakpoint to stay ahead of the built-in auto-compact. (Usage plan: context hygiene, not cost.)")}'
else
  jq -n --arg p "$PCT" --arg k "$CTX_K" --arg f "$FLOOR_K" --arg s "$SUBNOTE" '{systemMessage: ("[yellow] Context ~" + $p + "% (~" + $k + "K used, ~" + $f + "K fixed baseline)." + $s + " Consider /compact at a clean breakpoint if this task is wrapping up.")}'
fi
exit 0
