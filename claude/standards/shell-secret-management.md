# Decision: shell/API secret management on macOS (personal env)

Status: accepted · date: 2026-05-31 · scope: personal machine (not any repo) · revisit_after: when a revisit trigger below fires

## Context

API keys were stored as plaintext `export KEY="literal"` lines in `~/.zshrc`
(5: `ANTHROPIC_API_KEY`, `NEON_API_KEY`, `HELICONE_API_KEY`, `NOTION_API_KEY`,
`GREPTILE_API_KEY`) and in `~/.config/zsh/secrets.zsh` (more — enumerate that file
directly). Plaintext in a (version-controllable) dotfile is the problem. A working
precedent already exists at `~/.zshrc:187` — `METRICS_SNAPSHOT_TOKEN` is loaded from
the macOS login Keychain via `security find-generic-password`, guarded by a
`command -v security` check and `… 2>/dev/null || true` fallback.

Solo developer, single macOS (Apple Silicon) machine, no secret-sharing, no current
multi-machine need.

## Decision

Store all such secrets in the **macOS login Keychain**; load them by **consumer class**,
because `.zshrc` exports do NOT reach GUI-launched apps (Claude Desktop) or
launchd/MCP processes (they don't source `.zshrc`):

- **CLI-only secrets** (e.g. `NEON_API_KEY`, `HELICONE_API_KEY`) → lazy `security`
  lookup in `~/.config/zsh/secrets.zsh`, copying the existing line-187 pattern
  (silent fallback; never export an empty string).
- **GUI/MCP-consumed secrets** (e.g. `ANTHROPIC_API_KEY`, `NOTION_API_KEY`,
  `GREPTILE_API_KEY`) → set into the **global login environment** via
  `launchctl setenv` from a `~/Library/LaunchAgents/*.plist` (RunAtLoad), so
  Spotlight/Finder-launched Claude Desktop and the MCP servers it spawns inherit them.
  Alternatively, put the secret directly in the consuming MCP server's config file
  (`chmod 600`), which is the more explicit option for per-server keys.

This split is an **assumption** (which key is consumed where) — verify per key before
migrating; correct the classification if a GUI/MCP tool turns out to need a
"CLI-only" key.

Rotation of every previously-plaintext key is a SEPARATE, prerequisite action
(they were exposed in plaintext, and additionally in an assistant transcript on
2026-05-31). Do rotation first, then store the new values.

## Alternatives considered

- **sops + age** (`age` installed, `sops` not) — encrypted file commit-able to dotfiles
  git. Rejected: more moving parts + a master key to guard + per-shell decrypt latency;
  overkill for solo single-machine.
- **Bitwarden `bw` CLI** (installed) — rejected: needs unlock/session at shell init,
  awkward for new tabs/headless; better for cross-app/team vaults.
- **1Password `op`** (not installed) — best-in-class `op run`/secret-refs, but a new
  vendor + subscription; not justified solo.
- **direnv** (installed, hooked) — per-project env, but does NOT encrypt; a complement,
  not a store.
- **Status quo plaintext** — rejected (the problem).

## Consequences

Positive: no new dependencies; native; fast enough; reuses an established pattern.
Negative / accept: ~30–150ms per `security` call → keep the count low or lazy-load if
new-tab latency becomes noticeable; `security` fails (guarded, silent) in locked
Keychain / headless SSH — fine for interactive dev, but a headless job needing a secret
must get it another way; the GUI/launchd wiring is an extra one-time setup step per
GUI-consumed key.

## Revisit when

- A second machine is added (Keychain is macOS-only + single-user) → reconsider sops+age
  or `op` for cross-machine sync.
- Secrets must be shared with a collaborator → vault-based tool.
- A CI/headless/cron path needs one of these secrets → that path needs its own mechanism
  (GH Actions secrets / Vault), not Keychain.
- New-tab shell latency becomes annoying → switch CLI secrets to lazy-on-first-use
  functions or background prefetch.

## Migration (operator-performed — involves raw secret values; assistant does not run these)

1. **Rotate** each exposed key at its provider; get fresh values.
2. `security add-generic-password -s '<name>' -a "$USER" -w '<new-value>'` per key.
3. Replace plaintext `export`s in `~/.zshrc` + `~/.config/zsh/secrets.zsh` with the
   guarded lazy `security` lookup (line-187 pattern) for CLI-only keys.
4. For GUI/MCP keys: add a `~/Library/LaunchAgents/*.plist` that runs `launchctl setenv`
   per key at login (mirrors the `rc()` PATH pattern); `launchctl load` it. Re-launch
   Claude Desktop and verify it sees them.
5. If `~/.config/zsh/secrets.zsh` is git-tracked: `git rm --cached` it + `.gitignore` it
   (and scrub history if already pushed).
6. Test a fresh shell + a GUI-launched MCP call.
