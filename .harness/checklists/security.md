# Security Checklist

Verify each item before committing code that touches security-relevant paths.

- [ ] All external input is validated at the trust boundary, not deep in the handler
- [ ] No secrets hardcoded — all credentials via environment variables or secret manager
- [ ] Auth checks are present on every route that touches user data
- [ ] No user-controlled string used in a file path, command, or SQL query
- [ ] Error responses do not leak stack traces or internal state
- [ ] CORS, CSP, and rate-limiting headers are set on public endpoints
- [ ] Dependencies introduced have no known advisories (npm audit / pip audit checked)
