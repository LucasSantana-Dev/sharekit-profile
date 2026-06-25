---
name: secure
description: |
  Run a security-first pass for secrets/credentials, code vulnerabilities, configuration risks, and operational shortcuts.
  
  Trigger for: reviewing/merging code touching auth/secrets/config/deployment/MCP, OWASP assessment, credential hygiene check, unsafe code patterns, infrastructure security (Terraform/K8s/Docker), dependency risk.
triggers:
  - secure
  - security review
  - secret hygiene
  - auth change
  - OWASP review
---

# secure

Composite security audit covering credential exposure, code injection risks (SQL/XSS/command/path traversal), config misconfigs, and supply chain hygiene. Consolidates operational security (secrets, auth, deployment), web security (HTTPS/CORS/CSRF/rate-limit), and secure coding patterns across 10+ languages.

See `/standards/security.md` for hardline security rules. Detailed patterns live in `references/best-practices.md` and `references/secure-coding.md`.

---

## Preamble — RAG pre-flight

Before scanning, query prior security findings for this repo:

```bash
graphify query "security scan <repo-name> vulnerability" --budget 300
```

- If result shows a security scan for the same repo within 7 days → surface it, ask user to confirm whether to run fresh or review cached findings.
- If no recent match → proceed to Phase 1.

**Why:** Duplicate scans 12 hours apart waste compute and create noisy reports. Cached recent findings let you skip redundant work and focus on new code changes instead.

Done when: cached scan surfaced or no match found (proceed).

---

## Phase 1: RAG check for prior findings

**Done when:** No new findings OR all prior triaged/accepted risks listed.

Query knowledge brain for previous security findings on this codebase or similar patterns:
```bash
python3 ~/.claude/rag-index/query.py "security findings accepted risks" --top 5 --scope memory --fast
```

If prior audit exists: compare scope (same files? same risk categories?). If this is a re-check after fixes, confirm fixes applied.

**Halt if:** External HD unmounted — RAG unreachable.
```bash
mount | grep -q "${DEV_ROOT}" || { echo "BLOCKED: External HD unmounted — RAG unavailable"; exit 1; }
```

---

## Phase 2: Credential and secret exposure scan

**Done when:** Confirmed no live credentials in tracked files, or containment steps executed if found.

Check for inline tokens, API keys, bearer headers, hardcoded passwords, .env/.pem/.p12 modifications, private keys:
```bash
git diff --cached --unified=3 | grep -iE '(api[_-]?key|secret|token|password|bearer|aws_access|private[_-]?key|pem|p12)' | head -20
git status --short | grep -E '\.(env|pem|p12|key)$'
```

**STOP & CONTAIN if found:** Halt immediately. Surface secret type (not value), file/line. Execute:
```bash
git reset <file>           # Unstage
git checkout -- <file>     # Discard
git log -p --all -- <file> | grep -i secret  # Audit history
```

---

## Phase 3: Code security (input/injection/deser)

**Done when:** 
- Code review completed for all modified files touching user input, database, file paths, or code execution.
- Evidence: git diff output scanned; no instances of unsafe patterns found OR confirmed safe (e.g., parameterized query confirmed in use).
- If patterns found: refactored and re-verified.

For each language in the diff, check `references/secure-coding.md` §(N) patterns:
- **Python/JS/Java/Go:** SQL concatenation (+, format, f-string, template literals) → parameterized queries required
- **Command execution:** shell=True + user input, exec(...) with user vars → use array form only
- **HTML output:** innerHTML, unescaped templates → textContent / DOM methods / template engines with auto-escape
- **File paths:** user-controlled paths without validation → hardcoded or allowlisted only
- **Code eval:** eval/exec with user input → forbidden; static strings only
- **Deserialization:** pickle.loads, ObjectInputStream, Marshal.load, YAML.load with untrusted data → JSON or safe_load
- **XML:** XXE enabled by default in Java/Python → explicit disallow-doctype-decl or defusedxml

---

## Critic gate (after vulnerabilities catalogued)

Before proceeding to fix/remediation, dispatch ONE read-only critic agent to challenge the findings:

```bash
Agent({
  description: "Adversarial security findings review",
  subagent_type: "critic",
  prompt: "Challenge these vulnerability findings: Which might be false positives? Which severity ratings are miscalibrated? What OWASP Top 10 category was NOT checked? What secret pattern was missed by the scanner? [INSERT FINDINGS HERE]"
})
```

- If critic identifies ≥1 miscategorized or missed vulnerability class → revise findings before proceeding.
- Minor concerns (e.g., "scanner missed foo pattern but it's not in the diff") → log as `[CRITIC NOTE]` inline, proceed.

**Why:** Security researchers are prone to self-doubt under pressure. An adversarial agent forces defense of every finding and surfaces blind spots (unchecked categories, false positives) before resource is spent on fixes.

Done when: critic verdict returned and incorporated; all ≥MEDIUM findings re-verified or marked false positive.

---

## Phase 4: Config, deployment, and infrastructure

**Done when:** 
- Config files (Terraform, K8s, Docker, env templates, GitHub Actions, nginx/Apache) scanned.
- Evidence: grep / linting output showing no wildcard perms, unencrypted transit, missing CSRF tokens; or mitigations documented.
- All infrastructure code diffs reviewed for the checklist items below.

Check for:
- CORS *, open SG (0.0.0.0/0), IAM wildcards, public RDS/S3
- HTTP-only URLs, disabled TLS, cert validation skip (verify=False, InsecureSkipVerify: true)
- Auth endpoints unguarded by rate limit
- CSRF token disabled or missing from state-change requests
- Missing HSTS, CSP, X-Frame-Options headers
- Docker: FROM scratch, no USER directive
- Kubernetes: runAsRoot, privileged: true, allowPrivilegeEscalation: true
- GitHub Actions: secrets in plaintext, untrusted action @latest, overly permissive GITHUB_TOKEN
- Terraform/HCL: unencrypted EBS, S3 versioning disabled, IAM wildcards

See `references/best-practices.md §(1–10)` and `references/secure-coding.md §Infrastructure` for checklists.

---

## Phase 5: Dependencies and supply chain

**Done when:** npm audit / pip audit clean, OR documented CVEs with explicit accept rationale.

```bash
npm audit --json 2>/dev/null | jq '.metadata.vulnerabilities'
pip audit 2>/dev/null | head -20
cargo audit 2>/dev/null | head -20
```

Check for outdated versions with known CVEs, typosquatting (similar name to popular package), unmaintained packages. **Do not merge if critical/high CVEs remain unaddressed.**

---

## Phase 6: Release/deployment safety gates

**Done when:** 
- CI/CD pipeline output confirmed green (tests passing, linting passing, no security warnings).
- Evidence: Link to CI run showing all checks passed; no skipped tests or disabled security gates.
- Deploy logs (if applicable) scanned: no credentials, no warnings, tagged/reviewed.

Checklist:
- Skipping tests or security checks in CI?
- Secrets in workflow logs or build artifacts?
- Untagged or unreviewed deployments?
- Dangerous shortcuts (--skip-verify, --no-checks)?

---

## Output format

Signal-first: verdict first line, then findings by severity (top 3 inline; bulk gated).

```
CLEAR — no risks found

or

RISK FOUND:
  P0 (blocks merge): [what, where, why]
  P1 (must fix before merge): [what, severity reason]
  P2+ (should fix, non-blocking): [what]

Safe to merge if: [list of conditions, or "P0/P1 resolved"]
Triaged/Accepted: [list any prior-approved risks re-confirmed]
Containment steps: [exact commands if credential exposed]
```

**If P0 or live credential found:** Do NOT clear verdict without confirming fix + re-check.

---

## Common Rationalizations — Refute with Evidence

| Rationalization | Reality |
|---|---|
| "This is an internal service — the attack surface is small" | Most breaches come from internal services that 'didn't need' security review. Assume all services are reachable from the internet eventually. |
| "The secret is already rotated so I don't need to log it" | Rotation proves exposure happened; the window and path are still unaudited. Document containment steps regardless. |
| "This severity is Medium — we can fix it later" | Medium findings in auth/session/cryptography handling are High in disguise. Re-assess in threat context, do not defer. |
| "The critic is being paranoid about this pattern" | Security critics are adversarial by design. Refute with evidence (code audit, threat model, threat intel), not dismissal. |
| "I'll skip the RAG pre-flight for a quick scan" | A duplicate scan 12 hours after the last one wastes compute and pollutes reports. Query first. |

---

## References

- `references/best-practices.md` — HTTPS/CORS/CSRF/rate-limit/auth/headers; OWASP checklist
- `references/secure-coding.md` — SQL/XSS/command/path/eval/deser/XXE by language; infrastructure code
- `/standards/security.md` — hardline rules: no secrets in git, least privilege, input validation, secure defaults
