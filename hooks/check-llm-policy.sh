#!/usr/bin/env bash
# check-llm-policy.sh - soft local enforcement of .harness/llm-policy.json.
#
# Declarative, gateway-agnostic LLM policy: model tier allowlist per agent
# role, budget ceilings per scope, fallback chain with zero-cost-tier
# semantics, enforcement mode, attribution tags. defaultDeny idiom mirrors
# mcp-policy.json: a model on no tier allowlist is a violation.
#
# SOFT enforcement by default: when an agent requests a model above its
# role's tier (or a model on no allowlist), this hook warns on stderr and
# exits 0. HARD enforcement is gateway-delegated by design (Claude Code
# availableModels/enforceAvailableModels since v2.1.175, OpenRouter spend
# limits, opencode-go quota): the gateway, not a local hook, can actually
# block a model or cut off a budget. Setting "enforcement": "fail-closed"
# in the policy makes this hook exit 2 on violation for hosts that wire
# hook exit codes into the model path.
#
# Budget ceilings are never checked here: a local hook never sees metered
# cost. They are declared in the policy for the gateway to enforce.
#
# Exit codes: 0 = allow or advisory warn (fail-open);
#             2 = policy violation under enforcement=fail-closed.
#
# Input (stdin JSON): {"model": "...", "agent_role": "...", "scope": "..."}
# Policy override for tests: LLM_POLICY_FILE env var.
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/shared/common.sh"

POLICY="${LLM_POLICY_FILE:-$ROOT/.harness/llm-policy.json}"

if [[ ! -f "$POLICY" ]]; then
  echo "check-llm-policy: .harness/llm-policy.json not found - fail-open (allow)" >&2
  exit 0
fi

read_hook_stdin
model="$(hook_field "$HOOK_INPUT" ".model // .tool_input.model")"
[[ -n "$model" ]] || exit 0

role="$(hook_field "$HOOK_INPUT" ".agent_role // .role // .subagent_type")"
role="${role:-default}"

tier_rank() {
  case "$1" in
    zero-cost) echo 0 ;;
    haiku)     echo 1 ;;
    sonnet)    echo 2 ;;
    opus)      echo 3 ;;
    *)         echo -1 ;;
  esac
}

# Resolve the model to a tier: exact allowlist match first, then a name
# substring heuristic (haiku/sonnet/opus) for provider variants.
model_tier=""
while IFS= read -r tier; do
  [[ -n "$tier" ]] || continue
  if jq -e --arg t "$tier" --arg m "$model" \
    '.tiers[$t].models // [] | index($m)' "$POLICY" >/dev/null 2>&1; then
    model_tier="$tier"
    break
  fi
done < <(jq -r '.tiers | keys[]' "$POLICY" 2>/dev/null)

if [[ -z "$model_tier" ]]; then
  lc_model="$(printf '%s' "$model" | tr '[:upper:]' '[:lower:]')"
  case "$lc_model" in
    *haiku*)  model_tier="haiku" ;;
    *sonnet*) model_tier="sonnet" ;;
    *opus*)   model_tier="opus" ;;
  esac
fi

default_deny="$(jq -r '.defaultDeny // false' "$POLICY")"
enforcement="$(jq -r '.enforcement // "fail-open"' "$POLICY")"

violation=""
if [[ -z "$model_tier" ]]; then
  if [[ "$default_deny" == "true" ]]; then
    violation="model '$model' is on no tier allowlist and defaultDeny=true"
  fi
else
  role_tier="$(jq -r --arg r "$role" \
    '.roleTiers[$r] // .roleTiers["default"] // "sonnet"' "$POLICY")"
  model_rank="$(tier_rank "$model_tier")"
  role_rank="$(tier_rank "$role_tier")"
  if [[ "$model_rank" -gt "$role_rank" && "$role_rank" -ge 0 ]]; then
    violation="role '$role' is capped at tier '$role_tier' but requested '$model' (tier '$model_tier')"
  fi
fi

if [[ -n "$violation" ]]; then
  echo "check-llm-policy: WARN - $violation" >&2
  echo "  soft enforcement (fail-open): request allowed; hard enforcement is delegated to the gateway." >&2
  if [[ "$enforcement" == "fail-closed" ]]; then
    echo "  enforcement=fail-closed in llm-policy.json: blocking." >&2
    exit 2
  fi
fi
exit 0
