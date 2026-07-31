# Gateway Mapping: .harness/llm-policy.json to Enforcement

The harness declares policy; the gateway enforces it. Soft enforcement lives
in `hooks/check-llm-policy.sh` (local, advisory); hard enforcement (budgets,
model restrictions, rate limits) only works at the gateway because harness-side
settings cannot stop a direct provider key.

**Shadow-AI caveat:** any engineer holding a raw provider key bypasses every
layer below. Org adoption requires gateway-issued keys only, with direct
provider keys rotated out.

Reference minimal implementation: `warp/openrouter-proxy.js` in this repo.

---

## LiteLLM Proxy

| llm-policy.json | LiteLLM config |
|-----------------|----------------|
| `tiers.<role>.allowed_models` | `model_max_budget` + per-key `models` list on the virtual key issued to that role |
| `budgets.<scope>.max_usd` / `window` | `max_budget` + `budget_duration` (30s-30d) at key/user/team scope; multiple concurrent windows supported ($10/day AND $100/month) |
| `enforcement: fail-closed` | `fail_closed_budget_enforcement: true` (default Redis counter can under-report after restart) |
| `fallback_chain` | `fallbacks` in router config; zero-cost tier = model entry with `input_cost_per_token: 0` / `output_cost_per_token: 0`, which skips budget checks |
| `attribution_tags` | `metadata` / `tags` on the virtual key, surfaced in spend logs for chargeback |

Minimal example:

```yaml
model_list:
  - model_name: sonnet-tier
    litellm_params:
      model: anthropic/claude-sonnet-4-5
  - model_name: free-fallback
    litellm_params:
      model: ollama/qwen3
      input_cost_per_token: 0
      output_cost_per_token: 0
litellm_settings:
  fallbacks: [{"sonnet-tier": ["free-fallback"]}]
  fail_closed_budget_enforcement: true
```

## OpenRouter Organizations (Guardrails)

| llm-policy.json | OpenRouter org control |
|-----------------|------------------------|
| `tiers.<role>.allowed_models` | Model/provider restrictions per member and per API key |
| `budgets.<scope>` | Spending limits per member; key budgets layer on top of member budgets |
| `fallback_chain` | Provider routing preferences per key (no cross-account fallback; zero-cost tier = free model variants, e.g. `:free` suffix models) |
| `attribution_tags` | Unified usage tracking per key; chargeback = per-key export |

This profile already declares OpenRouter as the fallback provider: org installs
should use org-scoped keys, not personal ones, or the guardrails do not apply.

## Portkey

| llm-policy.json | Portkey control |
|-----------------|-----------------|
| `tiers.<role>.allowed_models` | Model whitelist guardrail + RBAC role |
| `budgets.<scope>` | Per-route quotas / rate limits |
| `enforcement` | Guardrail mode (block vs warn) maps to fail-closed/fail-open |
| `attribution_tags` | Metadata properties per request, feeding showback reports |

---

Sources: docs.litellm.ai/docs/proxy/users, openrouter.ai/docs/guides/features/guardrails,
portkey.ai governance docs (research track 9, verified 2026-07-30).
