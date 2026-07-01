---
name: secure
description: Run a security-first pass for config, credentials, dependency risk, unsafe code patterns, and unsafe operational shortcuts. Covers OWASP Top 10, secure coding, infrastructure config (Terraform/K8s/Docker/GitHub Actions), HTTPS/CORS/CSRF/rate limiting, and credential handling.
triggers:
  - secure
  - security review
  - secret hygiene
  - auth change
  - secure coding
  - OWASP review
  - code security check
  - infrastructure security
---

# secure

Use for any work touching secrets, auth, config, deployment, MCP definitions, memory stores, risky dependencies, user input handling, database queries, file operations, cryptography, or infrastructure code.

**Integrated guidance:** This skill now consolidates three security skill areas:
- **Operational security** (secrets, credentials, configs, deployment) — check list below
- **Web application & infrastructure best practices** (HTTPS, CORS, CSRF, rate limiting, auth) — see `references/best-practices.md`
- **Secure coding** (SQL injection, XSS, command injection, code patterns across 10+ languages) — see `references/secure-coding.md`

## Check list

### Credentials and secrets

- inline tokens, API keys, bearer headers, or credentials
- secret-bearing files accidentally modified (.env, .pem, .p12)
- hardcoded usernames, passwords, or API keys
- private keys or certificates committed to git

### Code security (when reviewing or writing code)

- SQL injection risk (string concatenation, format strings in queries)
- XSS risk (unescaped HTML output, innerHTML, user input in templates)
- Command injection (shell=True, shell expansions with user input)
- Path traversal (user-controlled file paths without validation)
- Code injection (eval, exec with user input)
- Insecure deserialization (pickle, ObjectInputStream, Marshal.load with untrusted data)
- XXE risk (XML parsers with external entity processing enabled)
- Hardcoded secrets or API keys in code

### Configuration and deployment

- overbroad permissions or unsafe defaults (CORS *, open security groups, IAM wildcards)
- unencrypted data in transit or at rest
- authentication/validation regressions
- missing rate limiting on auth endpoints
- CSRF protection disabled
- insecure headers or missing HSTS
- Docker containers running as root
- Kubernetes pods running as root or privileged

### Dependencies

- dependency vulnerabilities introduced or left unresolved
- outdated library versions with known CVEs
- supply chain risks (typosquatting, unmaintained packages, install scripts, unexpected network/file access)
- lockfile drift or unpinned critical runtime dependencies

### Static analysis and external signals

Use available scanners as evidence sources, not separate catalog entry points: Semgrep for pattern-based static analysis, Snyk/Socket/npm audit for dependency and supply-chain risk, Sonar/SonarCloud for quality-security hotspots, Sentry for production error signals, and GitHub/code scanning for CI-enforced findings. If a tool is unavailable, state the fallback and do not mark the surface clear.

### Release/deployment

- dangerous release shortcuts (skipping tests, disabling security checks)
- secrets exposed in build logs or CI workflows
- unreviewed or untagged deployments

## Output

Signal-first: verdict on the first line, then findings by severity.

```
CLEAR — no risks found

RISK FOUND:
  P0 (blocks merge): [what, where, why it blocks]
  P1 (must fix before merge): [what]
  P2+ (should fix, non-blocking): [what]

Safe to merge: [explicit list, or "nothing yet"]
Containment steps: [exact commands if credential exposure found]
```

## When to consult reference guides

**See `references/best-practices.md` when:**
- Adding authentication or session management
- Securing APIs (HTTPS, CORS, CSRF, rate limiting)
- Implementing web application security headers
- Setting up deployment-time security controls

**See `references/secure-coding.md` when:**
- Writing or reviewing code that handles user input
- Working with databases, file I/O, or external requests
- Using cryptography or secrets in code
- Checking for OWASP Top 10 vulnerabilities
- Infrastructure code (Terraform, Kubernetes, Docker, GitHub Actions)

## Failure / Stop Conditions

- If a live credential or secret is found exposed in tracked files: halt immediately, do not continue other checks. Surface the secret type (not value), the file/line, and containment steps. Do not proceed until contained.
- Do not clear a RISK FOUND verdict without confirming the fix was applied and re-checked.
- If code inspection reveals a critical vulnerability (RCE, auth bypass, data exfiltration), mark as P0 and do not proceed until remediated.
