# Warp Terminal — OpenRouter Custom Inference Endpoint

Warp's built-in custom inference endpoint feature drops the `Authorization` header
(issue #11598), so direct OpenRouter access from Warp fails. This Cloudflare
Worker injects the key server-side and forwards to OpenRouter.

## Deployed endpoint

- **URL:** `https://openrouter-warp-proxy.uiforge.workers.dev/v1`
- **API key:** any value (the Worker ignores it; auth comes from the secret)
- **Secret:** `OPENROUTER_API_KEY` stored via `wrangler secret put`
- **Account:** uiforge (Cloudflare account `712118840109d834d5e99925fd172432`)

## Adding models in Warp

In Warp: **Settings → Add custom inference endpoint**, then add each model ID
from the catalog below. The endpoint is OpenAI-compatible, so Warp can use any
OpenRouter model ID.

## Recommended model catalog

Curated by tier (matches the operator harness efficiency policy — match model
strength to task). All verified working through the proxy on 2026-06-29.

### Coding tier (Sonnet-class — implementation, feature work)

| Model ID | Context | Notes |
| --- | --- | --- |
| `anthropic/claude-sonnet-4.6` | 1000000 | Primary coding model |
| `anthropic/claude-sonnet-4.5` | 1000000 | Stable fallback |
| `openai/gpt-5.4` | 1050000 | OpenAI flagship |
| `openai/gpt-5.3-codex` | 400000 | Code-tuned, cost-efficient |
| `deepseek/deepseek-v4-pro` | 1048576 | Strong open-weight coder |
| `qwen/qwen3-coder-next` | 262144 | Qwen coding specialist |

### Reasoning tier (Opus-class — architecture, critic, ADRs)

| Model ID | Context | Notes |
| --- | --- | --- |
| `anthropic/claude-opus-4.7` | 1000000 | Deepest reasoning |
| `anthropic/claude-opus-4.6` | 1000000 | Stable reasoning |
| `x-ai/grok-4.3` | 1000000 | xAI flagship |
| `openai/gpt-5.4-pro` | 1050000 | OpenAI pro tier |
| `openai/gpt-5.5-pro` | 1050000 | Newest OpenAI pro |

### Fast tier (Haiku-class — mechanical, formatting, lookups)

| Model ID | Context | Notes |
| --- | --- | --- |
| `anthropic/claude-haiku-latest` | 200000 | Cheapest Claude |
| `openai/gpt-5.4-mini` | 400000 | Fast OpenAI |
| `openai/gpt-5.4-nano` | 400000 | Cheapest OpenAI |
| `google/gemini-3.5-flash` | 1048576 | Fast Gemini, huge context |
| `google/gemini-3.1-flash-lite` | 1048576 | Cheapest Gemini |
| `deepseek/deepseek-v4-flash` | 1048576 | Fast open-weight |
| `qwen/qwen3.6-flash` | 1000000 | Fast Qwen |

### Specialized

| Model ID | Context | Notes |
| --- | --- | --- |
| `google/gemini-3.1-pro-preview` | 1048576 | Gemini Pro, multimodal |
| `mistralai/mistral-medium-3-5` | 262144 | EU-hosted, GDPR-friendly |
| `x-ai/grok-4.20` | 2000000 | Largest context window |
| `qwen/qwen3.7-max` | 1000000 | Qwen flagship |

## Redeploy

```bash
cd warp/
npx wrangler deploy
```

To rotate the key:

```bash
cd warp/
npx wrangler secret put OPENROUTER_API_KEY   # paste sk-or-v1-...
```

## Notes

- The Worker adds `HTTP-Referer` (set to the sharekit-profile repo) and
  `X-Title: Warp Terminal` headers so OpenRouter attributes traffic correctly.
- OpenRouter prepaid credits are consumed per request. Monitor balance at
  https://openrouter.ai/settings/credits.
- Streaming responses are passed through unchanged.
