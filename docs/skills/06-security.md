# Security Skills

Use `secure` before work touching auth, secrets, credentials, infra, dependency changes, user input, MCP definitions, memory stores, or deployment. Tool-specific wrappers such as `security-audit`, `security-scan`, and `semgrep` are folded into `secure` and `quality-gates`.

---

## /secure

Security-first pass for code, config, credentials, dependencies, unsafe operational shortcuts, and release risk.

**Audits:**
- Hardcoded secrets, private keys, bearer tokens, and secret-bearing files.
- Unsafe shell, file I/O, path traversal, command injection, eval/exec, insecure deserialization.
- Auth/session regressions, missing authorization, weak defaults, missing rate limits.
- Web risks: XSS, SQL injection, CSRF, CORS, CSP/HSTS, insecure headers.
- Infra risks: IAM wildcards, public buckets, open security groups, root containers, privileged pods.
- Dependency and supply-chain risk: CVEs, typosquatting, install scripts, lockfile drift.

**Evidence sources when configured:** Semgrep, Snyk/Socket/npm audit, Sonar/SonarCloud, GitHub code scanning, Sentry, CI security jobs.

**Stop conditions:**
- Live credential found in tracked files: halt, name secret type and location, provide containment steps without exposing the value.
- Critical vulnerability such as RCE, auth bypass, or data exfiltration: mark P0 and block release.
- Scanner unavailable: state fallback; do not mark that surface clear.

---

## /quality-gates security scope

Use `/quality-gates security` or full `/quality-gates` when security evidence is part of merge readiness. It should run repository-native checks first, then configured scanners.

---

## /quality-assurance security sweep

Use `/quality-assurance` for broad security-relevant releases that need sequencing across `secure`, tests, CI, docs, deployment checks, and post-deploy monitoring.

**Last updated:** 2026-07-01
