#!/usr/bin/env node
/**
 * Secret masking utilities, extracted from OmniRoute (diegosouzapw/OmniRoute,
 * MIT license, src/mitm/maskSecrets.ts @ 84b1e5e12f238269e698f400766230f985f4a07b,
 * 2026-08-03). Mechanical TS->JS port (type annotations stripped only, zero
 * logic changes). Reviewed for a security-review request in this session:
 * https://github.com/diegosouzapw/OmniRoute - no network calls, pure string
 * transforms.
 *
 * Applied to all headers/bodies before any log or broadcast.
 * Regex patterns are pre-compiled (order matters: BEARER first).
 *
 * Pattern sources: plano 11 §4.8 (origin: llm-interceptor proxy.py:310)
 */
import { pathToFileURL } from "node:url";

// Pre-compiled regex patterns; ORDER IS SIGNIFICANT (BEARER must run first).
// BEARER matches the token after a standalone "Bearer ", NOT only after a
// literal "authorization:" prefix. sanitizeHeaders() masks header *values*
// ("Bearer <token>") with the key already stripped, so a prefix-anchored regex
// never fired there and short/opaque-but-<40 tokens leaked into the inspector
// (found by the AgentBridge live capture). The char class is bounded + linear
// (no nested quantifiers) to stay ReDoS-safe.
const BEARER = /(\bBearer\s+)[A-Za-z0-9._~+/-]+=*/gi;
const SK_KEY = /\b(sk|ak|pk)-[A-Za-z0-9_-]{16,}\b/g;
const LONG_TOKEN = /\b[A-Za-z0-9_-]{40,}\b/g;
// Pure-hex runs (git SHA-1, sha256 digests, other fixed-length hex identifiers)
// are not secrets; only mask LONG_TOKEN matches that aren't plain hex.
const PURE_HEX = /^[0-9a-f]+$/i;

/**
 * Mask secrets in a string value.
 * - Bearer tokens: replaces the token after any "Bearer " with "***"
 * - sk-/ak-/pk- keys: keeps first 6 chars + last 2 chars
 * - Long opaque tokens (>=40 chars, not pure hex): keeps first 4 chars + last 2 chars
 */
export function maskSecret(value) {
  return value
    .replace(BEARER, "$1***")
    .replace(SK_KEY, (m) => `${m.slice(0, 6)}…${m.slice(-2)}`)
    .replace(LONG_TOKEN, (m) => (PURE_HEX.test(m) ? m : `${m.slice(0, 4)}…${m.slice(-2)}`));
}

// CLI mode: stdin -> maskSecret -> stdout. Lets block-secret-reads.sh (bash)
// reuse this exact detection logic instead of re-deriving the same regexes
// a third time. Guarded so `import` from another module never runs this.
// pathToFileURL normalizes percent-encoding/spaces so this guard doesn't
// silently mismatch on paths containing spaces (import.meta.url is always
// percent-encoded; a raw `file://${argv[1]}` literal is not).
if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  let input = "";
  process.stdin.setEncoding("utf8");
  process.stdin.on("data", (chunk) => (input += chunk));
  process.stdin.on("end", () => process.stdout.write(maskSecret(input)));
}
