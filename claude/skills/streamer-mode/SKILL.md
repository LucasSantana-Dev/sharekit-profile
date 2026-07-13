---
name: streamer-mode
description: Behavioral safety mode for when the user is live streaming or screen sharing — never print secrets, env vars, tokens, IPs, hostnames, or terminal-sensitive data on screen; substitute safe command alternatives; defer security findings to a private file instead of announcing them on stream. Use when the user says "streamer mode", "I'm streaming", "I'm live", "going live", "screen sharing", "recording my screen", "on stream", or "presenting/demo on Zoom/Meet".
triggers:
  - streamer mode
  - I'm streaming
  - going live
  - screen sharing
  - screen share
  - recording my screen
  - on stream
  - presenting my screen
metadata:
  owner: global-agents
  tier: contextual
  canonical_source: ~/.agents/skills/streamer-mode/SKILL.md
---

# Streamer Mode

Everything the agent prints — tool output, file reads, command results, error messages — is visible to a live audience. Treat the terminal as a public broadcast until the user says the stream is over.

## Use When

- User announces they are streaming, screen sharing, recording, presenting, or demoing.
- User asks for "streamer mode", "safe mode for stream", "hide secrets while I share my screen".

## Do Not Use When

- Auditing a repo for leaked secrets (use `security-audit` / `secure`).
- Redacting data in files or commits (that is content work, not a session mode).

## Activation

1. Confirm mode is ON in one short line. Stays on until user says "stop streamer mode" / "stream over" / "done streaming".
2. Run the pre-flight sweep SILENTLY (output to file, never stdout) and report only pass/fail per item, never values:
   - `.env*` or credential-pattern files in cwd? (`ls` check only — never open them)
   - Git remotes with embedded tokens? (`git config --get-regexp 'remote\..*\.url' > /tmp/…` then check for `https://.*@` — report "1 remote has an embedded token, fix after stream", never print the URL)
   - Shell prompt / OS notifications likely exposing hostname or messages? Remind once: enable OS Do-Not-Disturb, Discord streamer mode.

## Core Rules (while ON)

1. **Never run commands that print secrets or network identity.** Full table with safe alternatives: `references/dangerous-commands.md`. Headline bans: `env`, `printenv`, `echo $ANY_SECRET`, `cat .env*`, `git remote -v`, `curl -v`, `docker inspect` (unfiltered), `kubectl get/describe secret`, `aws configure list`, `aws sts get-caller-identity`, `gcloud auth list`, `history`, `ps aux`, `ifconfig`/`ipconfig`/`netstat` (IPs).
2. **Never open sensitive files on screen.** Read/cat output is visible. Patterns: `.env*`, `*.pem`, `*.key`, `id_rsa*`, `.pgpass`, `.netrc`, `.npmrc`, `.aws/credentials`, `kubeconfig`, anything named `secret*`/`credential*`. Existence checks (`test -f`) and counts (`grep -c`) are fine.
3. **Check existence, not value:** `test -n "$VAR" && echo set` instead of `echo $VAR`.
4. **Redirect verbose output to file, grep narrowly:** `cmd > /tmp/out 2>&1` then extract only the non-sensitive line needed.
5. **Mask anything sensitive you must mention:** `sk-ab***`, `<server-ip>`, `<internal-host>`, `<client>`. Applies to IPs (public AND private), hostnames, MAC addresses, email addresses, cloud account IDs, DB connection strings, JWT contents, client names in file paths.
6. **Error output is a leak vector.** If a command fails, summarize the error in your own words; do not paste raw traces that contain hosts, paths with client names, or tokens.
7. **Prefer SSH-style references and placeholders in examples** — never real remotes, real accounts, real endpoints.

## Security Findings Protocol

If you notice a vulnerability, misconfiguration, or exposed secret while working:

- **Default — silent defer.** Append the finding to `~/.claude/streamer-findings/<YYYY-MM-DD>.md` (create dir if needed) via redirected shell write (never Write-tool preview, never echo the content). On screen say only: "Noted one item for your post-stream review — saved privately."
- **Exception — active exposure.** If a credential or secret is visible on screen RIGHT NOW (already printed, in an open file, in a pasted log), interrupt immediately: name the category and location ("an API key is visible in the output above — rotate it after the stream, viewers may have captured it"), but NEVER repeat or quote the value itself.
- Never enumerate vulnerabilities, attack vectors, or "here's how someone could exploit this" on stream.

## Deactivation

On "stream over" / "stop streamer mode": confirm mode OFF, then surface the private findings file contents and walk through deferred items (rotation steps first).

## Outputs / Evidence

- One-line ON confirmation + pre-flight pass/fail summary (no values).
- Private findings file when anything was deferred.
- OFF confirmation + deferred-findings debrief.

## Failure / Stop Conditions

- If a task genuinely requires viewing a secret (e.g., debugging an auth header), stop and tell the user to do that step off-stream — do not proceed with masking tricks that still flash the value.
- Mode is session-scoped; if a new session starts and the user is still streaming, they must re-activate.

## Load These Resources

- `references/dangerous-commands.md` — full banned-command table with safe alternatives + sensitive-file patterns.
