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
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POLICY="$ROOT/.harness/mcp-policy.json"
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
    c="$(jq -c --arg v "$v" 'select(.verdict==$v)' "$LEDGER" 2>/dev/null | grep -c . )"
    echo "  $v: ${c:-0}"
  done
  exit 0
fi

# --- Hook mode --------------------------------------------------------------
if [[ ! -f "$POLICY" ]]; then
  echo "policy-gate: .harness/mcp-policy.json not found - fail-open (allow)" >&2
  exit 0
fi

input="$(cat)"
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
