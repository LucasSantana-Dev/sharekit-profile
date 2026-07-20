# Security

- Never commit secrets, bearer tokens, credential files, or raw headers.
- Treat config, memory stores, logs, and MCP definitions as potentially sensitive.
- Use least privilege when credentials are required.
- Validate inputs at boundaries.
- Prefer `unknown` over `any` when types affect safety.
- Before merge or release, check for high/critical dependency risk when dependencies changed.
- If a likely secret is exposed, contain it first and avoid repeating it in outputs.
