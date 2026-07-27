# Dangerous Commands & Safe Alternatives (Streamer Mode)

Everything printed to the terminal is broadcast. Rule of thumb: if a command's output CAN contain a secret, token, IP, or hostname, either don't run it, narrow it, or redirect it to a file.

## Banned → Safe Alternative

| Banned on stream | Why it leaks | Safe alternative |
|---|---|---|
| `env`, `printenv` | Dumps every env var incl. keys | `test -n "$VAR" && echo set` |
| `echo $API_KEY` (any secret var) | Direct value exposure | `test -n "$API_KEY" && echo set` |
| `cat .env`, `cat *.pem`, `cat ~/.netrc` | Direct file exposure | `test -f .env && echo exists`; `grep -c '=' .env` (count only) |
| `git remote -v`, `git config --list` | HTTPS remotes can embed PATs | `git remote > /tmp/out` (names only); token check: `git config --get-regexp 'remote\..*\.url' > /tmp/out` then report yes/no |
| `curl -v`, `curl -i` | Prints Authorization headers, cookies | `curl -s URL -o /tmp/response`; inspect file with narrow grep |
| `docker inspect <id>` | Env vars, mounts, network config | `docker inspect --format '{{.State.Status}}' <id>` (narrow format) |
| `docker compose config` | Renders interpolated secrets | `docker compose config --quiet` (validation only) |
| `kubectl get secret -o yaml`, `kubectl describe secret` | Base64 secrets are trivially decoded | `kubectl get secrets` (names only) |
| `aws configure list`, `aws sts get-caller-identity` | Access key IDs, account ID | Verify auth by exit code: `aws sts get-caller-identity > /dev/null && echo authed` |
| `gcloud auth list`, `az account show` | Account emails, tenant/subscription IDs | Redirect to file, report authed yes/no |
| `history` | Past commands often contain inline secrets | Don't display; `history \| grep -c <term>` if counting needed |
| `ps aux`, `ps -ef` | Process args can carry passwords/DSNs | `pgrep -l <name>` |
| `ifconfig`, `ipconfig`, `ip addr`, `netstat`, `ss` | IPs (public+private), MACs, open ports | Report "network up/down" by exit code; details to file |
| `hostname`, `whoami`, `who` | Machine/user identity | Avoid; use placeholders in output |
| `ssh -v` | Prints hostnames, key paths, banners | Plain `ssh` with output to file if debugging needed |
| `npm config list`, `cat .npmrc` | Registry auth tokens | `npm config get registry` (single non-secret key) |
| `gh auth status` | Token scopes + account | `gh auth status > /tmp/out 2>&1; echo $?` |
| `printenv \| grep …`, `env \| grep …` | Still prints matched values | `env \| grep -c PATTERN` (count) or check specific var with `test -n` |
| `set` (bash builtin, no args) | Dumps vars + functions | Never on stream |

## Sensitive File Patterns — never open on screen

`.env*`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `id_rsa*`, `id_ed25519*`, `.pgpass`, `.netrc`, `.npmrc`, `.pypirc`, `.aws/credentials`, `.aws/config`, `kubeconfig`, `.kube/config`, `.docker/config.json`, `secrets.*`, `credential*`, `token*`, `.git-credentials`, `wrangler.toml` (can hold secrets inline), `serviceAccount*.json`, `*.tfvars`, `.terraform/`.

Existence/permission checks OK: `test -f`, `ls -l <file>`, `stat -f '%Sp' <file>`.

## Sensitive Data Categories — mask if unavoidable

| Category | Mask as |
|---|---|
| API keys / tokens | first 4 chars + `***` (e.g. `sk-ab***`) |
| IPs — public AND private (10.*, 172.16-31.*, 192.168.*) | `<server-ip>`, `<lan-ip>` |
| Hostnames / internal DNS | `<host>`, `<internal-host>` |
| MAC addresses | `<mac>` |
| Email addresses | `<email>` |
| Cloud account IDs (AWS/GCP/Azure) | `<account-id>` |
| DB connection strings / DSNs | `<db-url>` |
| JWT payloads | never decode on stream |
| Client/employer names in paths | `<client>/project` |
| Ports of internal services | keep only if needed; prefer `<port>` |

## Leak Vectors Beyond Commands

- **Error traces**: stack traces print absolute paths (`/Users/<name>/clients/<client>/…`), internal hosts, sometimes tokens in URLs. Summarize errors; never paste raw.
- **Package files**: `package.json` `publishConfig`, lockfile registry URLs can embed tokens.
- **Git**: `git log` author emails; `git show` of a commit that touched a secrets file; `git stash show -p`.
- **Clipboard/paste**: user-pasted logs may carry secrets — if pasted content contains one, trigger the active-exposure interrupt (see SKILL.md), never quote it back.
- **CI logs fetched locally** (`gh run view --log`): may echo unmasked secrets from misconfigured workflows — redirect to file.

## Real-World Stakes (why this matters)

- Twitch 2021 breach: 6,600 secrets in repos incl. 194 AWS keys (GitGuardian).
- Exposed AWS key → 50 EC2 miners, $3,000 in 3 days; exposed OpenAI key → $12,000 weekend bill (DEV Community incident reports).
- Viewers copy on-screen keys within seconds; automated scrapers watch popular coding streams. Interrupt-and-rotate beats silence when a secret is already visible.
