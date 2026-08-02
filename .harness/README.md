# `.harness/` — Declarative Governance Directory

`.harness/` is the machine-readable governance layer for the sharekit-profile
operator harness. It converts the prose security rules scattered across
`AGENTS.md` into diffable, CI-enforceable, machine-readable code.

## Contents

| File | Role |
|------|------|
| `manifest.json` | Harness identity + sha256 fingerprints of security-critical config files |
| `mcp-policy.json` | Declarative MCP governance policy: default-deny, dangerous patterns, approved servers, tool budgets |

## Source of truth vs mirror

- **`.harness/*.json` is the source of truth.** CI enforces it.
- **`AGENTS.md` is the human-readable mirror.** When the policy changes, update
  both — but the JSON wins on conflict because it is what the hooks and audit
  scripts actually evaluate.

## Lifecycle

### Editing policy

1. Modify `.harness/mcp-policy.json` (add a pattern, approve a server, change a
   budget, etc.).
2. Regenerate fingerprints (see below).
3. Commit both files in the same change so the manifest stays consistent with
   the policy it certifies.

### Regenerating fingerprints

```bash
bash scripts/regen-manifest.sh
```

Recomputes sha256 for every tracked file, updates only the entries that
changed (targeted string replace — doesn't reformat or reserialize the rest
of the file), bumps `generated_at`, and re-stages `manifest.json` if it
changed. Idempotent: no-op if nothing drifted. Runs automatically in
`.husky/pre-commit` before `check-harness-manifest.sh`, so a commit that
edits a tracked file no longer needs a manual rehash step — it self-heals
and the check passes.

Manual `shasum -a 256 <file>` + hand-paste still works as a fallback if the
script is unavailable, but should not be needed in normal flow.

## Policy drop-in fragments (`policy.d/`)

`.harness/policy.d/*.json` lets platform, security, and team policies compose
without editing one shared file (mirrors Claude Code's `managed-settings.d/`
pattern). `scripts/merge-policy-fragments.sh` merges all fragments into a
single effective policy JSON on stdout.

Merge semantics:

1. Fragments load in lexicographic filename order. Use numeric prefixes
   (`10-platform.json`, `20-security.json`) so precedence is deterministic.
2. Objects merge recursively.
3. Arrays union (concatenate + dedupe), so deny lists from every layer apply.
4. Scalars: the fragment with the higher prefix wins.
5. Fail-closed: any fragment that is not a valid JSON object aborts the merge
   with exit 1 and no output.

`check-harness-manifest.sh` validates every fragment as JSON and fingerprints
each one individually once it has a `manifest.json` entry; fragments without an
entry emit a warning until the manifest records them.

## Verifiers

### `scripts/check-harness-manifest.sh`

Runs in CI and via the `audit-deep` skill. It:

1. Recomputes sha256 for every file listed in `manifest.json` and compares
   against the recorded fingerprint. Any mismatch → exit 1 with a clear error.
2. Grep-checks policy invariants on `mcp-policy.json`:
   - `defaultDeny` is `true`
   - `dangerousPatterns` array is non-empty
   - `approvedServers` array is non-empty
3. Exits 0 only if all checks pass.

### `hooks/check-dangerous-patterns.sh`

A PreToolUse hook (Claude Code / OpenCode) that:

1. Reads `.harness/mcp-policy.json` and extracts the `dangerousPatterns` array.
2. Reads the incoming tool invocation JSON from stdin.
3. If the tool is not `Bash`, exits 0 (allow) — this hook only governs Bash.
4. Regex-matches the Bash `command` field against each dangerous pattern.
5. On any match: prints a warning to stderr and `exit 2` (Claude Code hook
   convention for "block this tool call").
6. On no match: `exit 0` (allow).
7. If `mcp-policy.json` is missing, exits 0 with a warning (fail-open for
   policy file absence, fail-closed for dangerous commands when policy exists).

## How CI gates read it

The `audit-deep` composite skill runs `scripts/check-harness-manifest.sh` as
one of its sub-checks. A non-zero exit surfaces as a CRITICAL finding in the
reconciled audit report, blocking the "clean" health score.

## Relationship to AGENTS.md prose rules

The "NEVER run these commands" list in `AGENTS.md` and the `dangerousPatterns`
array in `mcp-policy.json` describe the same constraint in two languages:

- `AGENTS.md` — natural language, read by the model at prompt time.
- `mcp-policy.json` — regex, read by the hook at tool-execution time.

The JSON is authoritative. If a pattern is added to the JSON it should also be
documented in `AGENTS.md`, but the JSON is what actually blocks the command.

## Origin

Adopted from the [ruflo meta-harness](https://github.com/ruvnet/ruflo) pattern:
a declarative governance directory that turns prose rules into diffable,
CI-enforceable, machine-readable code.