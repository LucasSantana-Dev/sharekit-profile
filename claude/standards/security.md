# Security

## General

- Never commit secrets, bearer tokens, credential files, or raw headers.
- Treat config, memory stores, logs, and MCP definitions as potentially sensitive.
- Use least privilege when credentials are required.
- Validate inputs at boundaries.
- Prefer `unknown` over `any` when types affect safety.
- Before merge or release, check for high/critical dependency risk when dependencies changed.
- If a likely secret is exposed, contain it first and avoid repeating it in outputs.

## Shell and API secrets on macOS (personal machine, not any repo)

- Never store API keys as plaintext `export KEY="literal"` lines in `~/.zshrc`, `~/.config/zsh/secrets.zsh`, or any dotfile that can be version-controlled. Store them in the macOS login Keychain.
- Load secrets by consumer class. `.zshrc` exports do NOT reach GUI-launched apps (Claude Desktop) or launchd/MCP processes, because those do not source `.zshrc`.
  - CLI-only secrets (e.g. `NEON_API_KEY`, `HELICONE_API_KEY`): lazy `security find-generic-password` lookup in `~/.config/zsh/secrets.zsh`, copying the `METRICS_SNAPSHOT_TOKEN` pattern in `~/.zshrc` (guard with `command -v security`, fall back with `2>/dev/null || true`). Never export an empty string; the fallback must be silent.
  - GUI/MCP-consumed secrets (e.g. `ANTHROPIC_API_KEY`, `NOTION_API_KEY`, `GREPTILE_API_KEY`): set into the global login environment with `launchctl setenv` from a `~/Library/LaunchAgents/*.plist` (RunAtLoad), so Spotlight/Finder-launched apps and the MCP servers they spawn inherit them. Alternative for per-server keys: put the secret in the consuming MCP server's config file with `chmod 600`.
- Which key is consumed where is an assumption: verify per key before migrating, and reclassify if a GUI/MCP tool needs a "CLI-only" key.
- Rotate every previously-plaintext or otherwise exposed key at its provider before storing new values. Rotation is a separate prerequisite step, done first.
- Keep `security` calls few or lazy (about 30-150ms each); if new-tab latency becomes noticeable, use lazy-on-first-use functions or background prefetch.
- `security` fails (guarded, silent) in a locked Keychain or headless SSH. A headless, CI or cron job needing a secret must get it another way (GH Actions secrets, Vault), not Keychain.
- Keychain is macOS-only and single-user. A second machine or a secret shared with a collaborator needs a vault-based tool (sops+age or 1Password `op`) instead.
- direnv is per-project env only and does not encrypt; never treat it as a secret store.
- If the shell secrets file is git-tracked: `git rm --cached` it, add it to `.gitignore`, and scrub history if already pushed.

### Migration (operator-performed)

Steps involve raw secret values; the assistant never runs them.

1. Rotate each exposed key at its provider and get fresh values.
2. `security add-generic-password -s '<name>' -a "$USER" -w '<new-value>'` per key.
3. Replace plaintext `export`s with the guarded lazy `security` lookup for CLI-only keys.
4. For GUI/MCP keys: add a `~/Library/LaunchAgents/*.plist` that runs `launchctl setenv` per key at login, then `launchctl load` it. Re-launch the GUI app and verify it sees them.
5. Test a fresh shell and a GUI-launched MCP call.
