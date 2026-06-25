# Security Skills

`secure` before any deploy touching auth, secrets, or infra. `security-sweep` (composite) for a full pass. `socket-audit` specifically for supply-chain risk in npm dependencies. `sonar-check` before pushing to gated branches.

---

## /secure

Run a security-first pass for config, credentials, dependency risk, and unsafe operational shortcuts.

**Audits:**
- Secrets in code (hardcoded API keys, tokens, passwords)
- Unsafe bash (hardcoded credentials, no validation)
- Dependency risk (outdated packages, known CVEs)
- Auth configuration (weak defaults, missing verification)

**When to use:** Before any deploy touching auth, secrets, or infra

**Output:** Security findings + remediation steps

---

## /security-audit

Broad security audit across secrets, dependencies, code paths, and OWASP risks.

**Coverage:**
- Secrets detection (hardcoded, env vars)
- Dependency audit (npm audit, known CVEs)
- Code path analysis (dangerous functions, unsafe patterns)
- OWASP Top 10 (injection, XSS, auth, etc.)
- Access control (hardcoded admin, missing RLS)

**When to use:** Full security review; before release

**Output:** Findings organized by severity + CVSS scores

---

## /security-scan

Run concrete security scanning steps including Trivy, npm audit, and secrets detection.

**Tools:**
- Trivy (container image scanning)
- npm audit (dependency vulnerabilities)
- git-secrets (credential detection)
- Semgrep (pattern-based scanning)

**When to use:** Automated security gate; CI integration

**Output:** Scan results + pass/fail per tool

---

## /security-sweep ⭐⭐ **Composite**

Full security pass: security-audit + socket-audit + semgrep + code-security (in parallel).

**Parallel audits:**
1. **security-audit:** Secrets, dependencies, code paths, OWASP
2. **socket-audit:** Supply-chain risk (Socket.dev on npm deps)
3. **semgrep:** Pattern-based static analysis (custom + standard rules)
4. **code-security:** OWASP Top 10 implementation

**Reconciles:** All findings into severity-ranked list

**When to use:** Before security-relevant deploy; full security review

**Output:** Comprehensive security findings + remediation plan

---

## /security-best-practices

Implement OWASP Top 10 protections and security best practices.

**Covers:**
- A1: Injection prevention (parameterized queries, input validation)
- A2: Broken authentication (strong auth, session management)
- A3: Sensitive data exposure (encryption, secrets management)
- A4: XML external entities (XXE) prevention
- A5: Broken access control (authz, RLS)
- A6: Security misconfiguration (defaults, hardening)
- A7: XSS prevention (sanitization, CSP)
- A8: Insecure deserialization
- A9: Using components with known vulnerabilities
- A10: Insufficient logging & monitoring

**When to use:** Writing auth, API, or infra code

**Output:** Security checklist + implementation patterns

---

## /semgrep

Run Semgrep static analysis scans and create custom detection rules.

**Capabilities:**
- Built-in rule library (OWASP, security patterns)
- Custom rule creation (regex + AST matching)
- Multi-language support (Python, JS, Java, Go, etc.)
- CI integration (fail builds on violations)

**When to use:** Automated pattern scanning; before pushing to gated branch

**Output:** Semgrep findings + pass/fail verdict

---

## /socket-audit

Run Socket.dev supply chain security audit on npm dependencies for malicious packages and typosquatting.

**Detects:**
- Malicious packages (known malware)
- Typosquatting (package name similarity)
- Behavior anomalies (unusual access patterns)
- Dependency risk scoring

**When to use:** Before npm install in production; dependency review

**Output:** Socket.dev findings + risk scores

---

## /sonar-check

Pre-push SonarCloud gate preflight — scans for ReDoS, SSRF, and coverage gaps.

**Checks:**
- Regular expression denial of service (ReDoS) patterns
- Server-side request forgery (SSRF) vulnerabilities
- Coverage gaps (lines/branches untested)
- Code smells + maintainability issues

**When to use:** Before pushing to gated branch (protected main, release)

**Output:** Sonar findings + gate pass/fail verdict

---

## /config-drift-detect

Audit project gates (jest/vitest thresholds, tsconfig strictness, eslint, husky, Sonar, branch protection) for drift.

**Audits:**
- Test coverage thresholds (should be high + consistent)
- TypeScript strictness (should enforce strict mode)
- ESLint rules (should be consistent across team)
- Husky hooks (pre-commit checks enabled)
- Sonar quality gate (should block low-quality PRs)
- GitHub branch protection (should require reviews)

**When to use:** Security + quality gate verification; before release

**Output:** Drift findings + recommended fixes

---

**Last updated:** 2026-06-25
