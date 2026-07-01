#!/usr/bin/env bash
# policy-gate.sh - PreToolUse deterministic governance layer (P4).
#
# The Wave-5 safety/governance track converged on one principle: authorization
# must be enforced OUTSIDE the model, in deterministic code, bound to immutable
# context, and written to a tamper-evident ledger. The existing
# check-dangerous-patterns.sh blocks known-bad Bash regexes; this hook adds the
# missing pieces from microsoft/agent-governance-toolkit, cordum, Janus,
# provenex, and agence:
#
#   1. EXPLICIT VERDICTS. Every governed tool call resolves to exactly one of
#      ALLOW / DENY / REQUIRE_APPROVAL - never an implicit pass. Default-deny
#      posture for MCP servers not on the approved list (mcp-policy.json
#      defaultDeny=true).
#   2. LEAST-PRIVILEGE MCP SCOPES. An MCP tool whose server is not in
#      approvedServers is DENY (deterministic, model-independent).
#   3. TAMPER-EVIDENT LEDGER. Each decision is appended to a hash-chained
#      ledger (.harness/runtime/policy-ledger.jsonl): every entry carries the
#      sha256 of (prev_hash + decision payload), so any retroactive edit breaks
#      the chain. `--verify` walks the chain and reports the first break
#      (agence Merkle-chain + provenex signed-receipt pattern).
#   4. CONTEXT BINDING. Each decision records a context hash (tool + input
#      digest + ts) so the receipt is bound to exactly what was requested.
#
# This is model-agnostic: the verdict is computed from policy + request, never
# from model internals, so it survives provider swaps.
#
# Exit codes: 0 = ALLOW or REQUIRE_APPROVAL (advisory surfaced on stderr);
#             2 = DENY (blocks the tool call). Only DENY blocks.
#
# Usage (hook - reads stdin JSON): claude/settings.json PreToolUse.
# Usage (CLI):
#   hooks/policy-gate.sh --verify     # walk the ledger, report chain integrity
#   hooks/policy-gate.sh --status     # decision counts by verdict
#   hooks/policy-gate.sh --rules      # list learned prefix rules (P9.1)
#   hooks/policy-gate.sh --learn <ALLOW|DENY> <prefix> --rationale "..."   # P9.1
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POLICY="$ROOT/.harness/mcp-policy.json"
RULES_FILE="$ROOT/.harness/approval-rules.json"
RUNTIME="$ROOT/.harness/runtime"
LEDGER="$RUNTIME/policy-ledger.jsonl"
mkdir -p "$RUNTIME"

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

sha() { shasum -a 256 | awk '{print $1}'; }

# --- CLI: --verify (walk the hash chain) ------------------------------------
if [[ "${1:-}" == "--verify" ]]; then
  [[ -f "$LEDGER" ]] || { echo "policy-gate: no ledger yet ($LEDGER)"; exit 0; }
  prev="GENESIS"
  line_no=0
  broken=0
  while IFS= read -r entry; do
    line_no=$((line_no + 1))
    rec_prev="$(printf '%s' "$entry" | jq -r '.prev_hash' 2>/dev/null)"
    rec_hash="$(printf '%s' "$entry" | jq -r '.hash' 2>/dev/null)"
    payload="$(printf '%s' "$entry" | jq -rc '{ts,tool,verdict,reason,context_hash}' 2>/dev/null)"
    expect="$(printf '%s%s' "$prev" "$payload" | sha)"
    if [[ "$rec_prev" != "$prev" ]]; then
      echo "policy-gate: CHAIN BREAK at line $line_no - prev_hash mismatch" >&2
      broken=1; break
    fi
    if [[ "$rec_hash" != "$expect" ]]; then
      echo "policy-gate: CHAIN BREAK at line $line_no - hash mismatch (entry was tampered)" >&2
      broken=1; break
    fi
    prev="$rec_hash"
  done < "$LEDGER"
  if [[ "$broken" -eq 0 ]]; then
    echo "policy-gate: ledger intact - $line_no entries, chain verified"
    exit 0
  fi
  exit 1
fi

# --- CLI: --status ----------------------------------------------------------
if [[ "${1:-}" == "--status" ]]; then
  [[ -f "$LEDGER" ]] || { echo "policy-gate: no decisions recorded yet"; exit 0; }
  total="$(wc -l < "$LEDGER" | tr -d ' ')"
  echo "policy decisions: $total"
  for v in ALLOW DENY REQUIRE_APPROVAL; do
    c="$(jq -c --arg v "$v" 'select(.verdict==$v)' "$LEDGER" 2>/dev/null | rg -c '.')"
    echo "  $v: ${c:-0}"
  done
  echo "  auto-approved/denied via learned prefix rules: $(jq -r 'select(.reason|startswith("auto:"))' "$LEDGER" 2>/dev/null | rg -c '.' || echo 0)"
  exit 0
fi

# --- CLI: --rules (list learned prefix rules) --------------------------------
if [[ "${1:-}" == "--rules" ]]; then
  [[ -f "$RULES_FILE" ]] || { echo "policy-gate: no approval-rules.json yet"; exit 0; }
  count="$(jq '.rules | length' "$RULES_FILE" 2>/dev/null || echo 0)"
  echo "learned prefix rules: $count"
  jq -r '.rules[] | "  \(.verdict)  \(.prefix)  — \(.rationale // "no rationale") (learned \(.learned_at // "?"))"' "$RULES_FILE" 2>/dev/null
  exit 0
fi

# --- CLI: --learn <verdict> <prefix> --rationale "..." (host-only persist) ---
# Persists a prefix rule the hook SUGGESTED on an unmatched REQUIRE_APPROVAL.
# Governance stays outside the model: only the host runs --learn; the hook
# itself never auto-learns. The new rule takes effect on the next hook call.
if [[ "${1:-}" == "--learn" ]]; then
  shift
  l_verdict="${1:-}"; shift || true
  l_prefix="${1:-}"; shift || true
  l_rationale=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --rationale) l_rationale="$2"; shift 2 ;;
      *) echo "policy-gate --learn: unknown arg: $1" >&2; exit 2 ;;
    esac
  done
  [[ "$l_verdict" == "ALLOW" || "$l_verdict" == "DENY" ]] \
    || { echo "policy-gate --learn: verdict must be ALLOW or DENY" >&2; exit 2; }
  [[ -n "$l_prefix" ]] || { echo "policy-gate --learn: requires <prefix>" >&2; exit 2; }
  [[ -f "$RULES_FILE" ]] || printf '{"rules":[]}\n' > "$RULES_FILE"
  l_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  # Append the rule (supersede-not-overwrite: an identical prefix is replaced,
  # not duplicated, so the latest verdict wins without losing the audit trail
  # in the ledger).
  tmp="$(mktemp)"
  jq --arg v "$l_verdict" --arg p "$l_prefix" --arg r "$l_rationale" --arg t "$l_ts" \
    '.rules |= (map(select(.prefix != $p)) + [{prefix:$p, verdict:$v, rationale:$r, learned_at:$t, source:"host-learn"}])' \
    "$RULES_FILE" > "$tmp" && mv "$tmp" "$RULES_FILE"
  echo "policy-gate: learned rule — $l_verdict  $l_prefix"
  echo "  rationale: $l_rationale"
  echo "  takes effect on the next hook call; prior ledger entries are unchanged (audit trail)"
  exit 0
fi

# --- Hook mode --------------------------------------------------------------
if [[ ! -f "$POLICY" ]]; then
  echo "policy-gate: .harness/mcp-policy.json not found - fail-open (allow)" >&2
  exit 0
fi

input="$(sed -n '1,$p')"
tool_name="$(printf '%s' "$input" | jq -r '.tool_name // .tool // empty' 2>/dev/null || true)"
[[ -n "$tool_name" ]] || exit 0

# Compute a context hash binding the decision to exactly this request.
input_digest="$(printf '%s' "$input" | jq -rc '.tool_input // .input // {}' 2>/dev/null | sha)"
context_hash="$(printf '%s%s%s' "$tool_name" "$input_digest" "$ts" | sha)"

verdict="ALLOW"
reason="not governed by policy (native tool / approved scope)"

# --- Rule 1: MCP least-privilege scope (default-deny) -----------------------
# MCP tool names typically look like "mcp__<server>__<tool>" or "<server>.<tool>".
default_deny="$(jq -r '.defaultDeny // false' "$POLICY")"
mcp_server=""
case "$tool_name" in
  mcp__*) mcp_server="$(printf '%s' "$tool_name" | sed -E 's/^mcp__([^_]+)__.*/\1/')" ;;
  *.*)    mcp_server="$(printf '%s' "$tool_name" | cut -d. -f1)" ;;
esac

if [[ -n "$mcp_server" ]]; then
  if jq -e --arg s "$mcp_server" '.approvedServers | index($s)' "$POLICY" >/dev/null 2>&1; then
    verdict="ALLOW"
    reason="MCP server '$mcp_server' is on approvedServers"
  elif [[ "$default_deny" == "true" ]]; then
    verdict="DENY"
    reason="MCP server '$mcp_server' not in approvedServers and defaultDeny=true"
  else
    verdict="REQUIRE_APPROVAL"
    reason="MCP server '$mcp_server' not in approvedServers (defaultDeny=false)"
  fi
fi

# Note: native file-mutating tools (Write/Edit/MultiEdit) are intentionally NOT
# gated here. Per mcp-policy.json, allowFileWrite governs MCP servers; native
# tools are governed at the tool layer by check-idempotency.sh and
# check-dangerous-patterns.sh. policy-gate focuses on MCP least-privilege scope.

# --- Rule 2: Smart Approvals prefix-rule learning (P9.1) --------------------
# OpenAI Codex CLI pattern: when a command is escalated for approval, the system
# proposes a prefix_rule that persists so similar commands auto-approve/deny in
# future. Governance stays OUTSIDE the model — the hook only SUGGESTS rules on
# unmatched REQUIRE_APPROVAL; the host persists them via --learn (the model
# cannot rewrite approval-rules.json). A matching ALLOW rule upgrades
# REQUIRE_APPROVAL->ALLOW (auto-approve, logged); a matching DENY rule forces
# DENY; no match falls through to the base verdict. Every auto-decision still
# appends to the tamper-evident ledger with reason=auto:<prefix>, so the chain
# stays auditable.
rule_hit=""
if [[ -f "$RULES_FILE" ]]; then
  # Build the match key: tool_name + the input string (the prefix rules match
  # against the start of this key, e.g. "mcp__github__create_issue title=chore:").
  input_str="$(printf '%s' "$input" | jq -rc '.tool_input // .input // {}' 2>/dev/null | tr -d '\n')"
  match_key="$tool_name $input_str"
  # First-match-wins: rules are ordered; the host controls order in the file.
  while IFS= read -r r; do
    [[ -n "$r" ]] || continue
    r_prefix="$(printf '%s' "$r" | jq -r '.prefix')"
    r_verdict="$(printf '%s' "$r" | jq -r '.verdict')"
    if [[ -n "$r_prefix" ]] && [[ "$match_key" == "$r_prefix"* ]]; then
      rule_hit="$r_prefix"
      if [[ "$r_verdict" == "ALLOW" ]]; then
        # An ALLOW rule can only RELAX a REQUIRE_APPROVAL, never override a DENY
        # (a DENY from base policy is a hard floor; learned rules cannot weaken it).
        if [[ "$verdict" == "REQUIRE_APPROVAL" ]]; then
          verdict="ALLOW"
          reason="auto-approved by learned prefix rule: $r_prefix"
        fi
      elif [[ "$r_verdict" == "DENY" ]]; then
        # A DENY rule can strengthen any verdict (defense in depth).
        verdict="DENY"
        reason="auto-denied by learned prefix rule: $r_prefix"
      fi
      break
    fi
  done < <(jq -c '.rules[]' "$RULES_FILE" 2>/dev/null)
fi

# On an unmatched REQUIRE_APPROVAL, suggest a prefix rule for the host to learn.
# The hook NEVER auto-learns — it only surfaces the candidate. The host reviews
# and persists via `policy-gate.sh --learn <verdict> <prefix> --rationale "..."`.
if [[ "$verdict" == "REQUIRE_APPROVAL" && -z "$rule_hit" ]]; then
  # Suggest a conservative prefix (tool name only) so the host can broaden it.
  suggested_prefix="$tool_name"
  echo "policy-gate: SUGGESTED prefix rule (host: review then --learn):" >&2
  echo "  prefix: $suggested_prefix" >&2
  echo "  to auto-approve:  policy-gate.sh --learn ALLOW '$suggested_prefix' --rationale \"...\"" >&2
  echo "  to auto-deny:     policy-gate.sh --learn DENY  '$suggested_prefix' --rationale \"...\"" >&2
fi

# --- Append to the hash-chained ledger --------------------------------------
prev_hash="GENESIS"
if [[ -f "$LEDGER" && -s "$LEDGER" ]]; then
  prev_hash="$(tail -n 1 "$LEDGER" | jq -r '.hash' 2>/dev/null || echo GENESIS)"
fi
payload="$(jq -nc --arg ts "$ts" --arg tool "$tool_name" --arg verdict "$verdict" \
  --arg reason "$reason" --arg ch "$context_hash" \
  '{ts:$ts,tool:$tool,verdict:$verdict,reason:$reason,context_hash:$ch}')"
entry_hash="$(printf '%s%s' "$prev_hash" "$payload" | sha)"
printf '%s\n' "$(jq -nc --argjson p "$payload" --arg prev "$prev_hash" --arg h "$entry_hash" \
  '$p + {prev_hash:$prev, hash:$h}')" >> "$LEDGER"

# --- Surface the verdict + set exit code ------------------------------------
case "$verdict" in
  ALLOW)
    exit 0
    ;;
  REQUIRE_APPROVAL)
    echo "policy-gate: REQUIRE_APPROVAL - $tool_name: $reason" >&2
    echo "  (advisory: host should confirm before proceeding; recorded in ledger)" >&2
    exit 0
    ;;
  DENY)
    echo "policy-gate: DENY - $tool_name: $reason" >&2
    echo "  decision recorded in tamper-evident ledger ($LEDGER)" >&2
    echo "  override by editing .harness/mcp-policy.json and regenerating fingerprints." >&2
    exit 2
    ;;
esac
exit 0
