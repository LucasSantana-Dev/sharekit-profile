#!/usr/bin/env node
/**
 * Header sanitization for safe logging/broadcasting, extracted from OmniRoute
 * (diegosouzapw/OmniRoute, MIT license, src/mitm/sanitizeHeaders.ts @
 * 84b1e5e12f238269e698f400766230f985f4a07b, 2026-08-03). Mechanical TS->JS
 * port: type annotations stripped, and the one external import
 * (isForbiddenUpstreamHeaderName, from src/shared/constants/upstreamHeaders.ts
 * in the source repo) inlined below since it's a single small denylist — no
 * other logic changes. https://github.com/diegosouzapw/OmniRoute
 */
import { pathToFileURL } from "node:url";

// Hop-by-hop / framing headers that must never be forwarded or logged verbatim.
const FORBIDDEN_UPSTREAM = new Set(
  ["host", "connection", "content-length", "keep-alive", "proxy-connection",
   "transfer-encoding", "te", "trailer", "upgrade"].map((s) => s.toLowerCase())
);

function isForbiddenUpstreamHeaderName(name) {
  return FORBIDDEN_UPSTREAM.has(String(name).trim().toLowerCase());
}

/**
 * Header names whose values must be masked (case-insensitive).
 * These carry credentials/tokens that must not appear in logs or broadcasts.
 */
const SECRET_HEADER_NAMES = new Set([
  "authorization",
  "cookie",
  // `set-cookie` is the RESPONSE-side credential header, upstream session/CSRF
  // cookies must be masked too, else they leak verbatim into inspector JSON.
  "set-cookie",
  "x-api-key",
  "api-key",
  "bearer",
  "proxy-authorization",
]);

function isSecretHeader(name) {
  return SECRET_HEADER_NAMES.has(name.toLowerCase());
}

/**
 * Sanitize HTTP headers for safe logging/broadcasting.
 *
 * - Removes headers in the upstream denylist (hop-by-hop, Host, etc.)
 * - Fully redacts values of authorization/cookie/key headers ("[REDACTED]")
 * - Coerces array values to comma-joined strings
 * - Returns a plain Record<string, string> (never undefined values)
 */
export function sanitizeHeaders(headers) {
  const result = {};

  for (const [key, value] of Object.entries(headers)) {
    if (value === undefined || value === null) continue;

    const lowerKey = key.toLowerCase();

    // Remove denylist headers (hop-by-hop, framing)
    if (isForbiddenUpstreamHeaderName(lowerKey)) continue;

    // Normalize array values
    const strValue = Array.isArray(value) ? value.join(", ") : String(value);

    // Mask secret header values
    if (isSecretHeader(lowerKey)) {
      // Every secret header name can carry a short, shape-invisible credential
      // (short Basic auth, short custom API keys, short cookies) that maskSecret's
      // format heuristics (Bearer / sk- / >=40-char) do NOT catch, so redact fully
      // rather than relying on shape heuristics (SECURITY_AUDIT M6, CodeRabbit).
      result[lowerKey] = "[REDACTED]";
    } else {
      result[lowerKey] = strValue;
    }
  }

  return result;
}

// CLI mode: redact secret-shaped "Header-Name: value" occurrences found in
// free-form text on stdin - a pasted `curl -v`/HTTP transcript (one header per
// line), a header embedded inline inside a quoted shell arg (e.g.
// `curl -H "Cookie: session=abc123"`), or a JSON-body-shaped occurrence (e.g.
// `curl -d '{"Cookie": "session=abc123"}'`, optional quote before the colon
// and before the value). Word-boundary search across the whole input, not
// line-anchored, so all three shapes match. Value is read up to the next
// quote/newline. Built from the exact same SECRET_HEADER_NAMES set as
// sanitizeHeaders() - distinct from that function itself, which sanitizes a
// parsed headers OBJECT for outbound forwarding and also strips hop-by-hop
// headers entirely (Host/Connection/...), which would silently delete content
// from arbitrary text. This mode only ever rewrites a matched value, never
// drops anything.
const SECRET_HEADER_ALT = [...SECRET_HEADER_NAMES].map((n) => n.replace(/-/g, "\\-")).join("|");
const SECRET_HEADER_OCCURRENCE = new RegExp(`\\b(${SECRET_HEADER_ALT})"?(\\s*:\\s*)"?([^\\n"']*)`, "gi");

export function redactHeaderText(text) {
  return text.replace(SECRET_HEADER_OCCURRENCE, (_match, name, sep) => `${name}${sep}[REDACTED]`);
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  let input = "";
  process.stdin.setEncoding("utf8");
  process.stdin.on("data", (chunk) => (input += chunk));
  process.stdin.on("end", () => process.stdout.write(redactHeaderText(input)));
}
