/**
 * OpenRouter auth-injecting proxy for Warp terminal.
 *
 * Warp's custom inference endpoint drops the Authorization header (issue #11598).
 * This Worker injects it server-side, then forwards to OpenRouter.
 *
 * Deploy:
 *   1. wrangler deploy warp/openrouter-proxy.js --name openrouter-warp-proxy
 *   2. wrangler secret put OPENROUTER_API_KEY  (paste sk-or-v1-...)
 *   3. In Warp: Settings → Add custom inference endpoint
 *      - URL: https://openrouter-warp-proxy.uiforge.workers.dev/v1
 *      - API key: anything (the Worker ignores it, uses the secret)
 *      - Models: see warp/MODELS.md for the curated catalog
 */

const OPENROUTER_BASE = "https://openrouter.ai/api";

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // Health check
    if (url.pathname === "/" || url.pathname === "/health") {
      return new Response("ok", { status: 200 });
    }

    // Rewrite path to OpenRouter. Incoming path already starts with /v1, and
    // OPENROUTER_BASE ends at /api, so concatenation yields /api/v1/... — no
    // double /v1.
    const target = OPENROUTER_BASE + url.pathname + url.search;

    // Clone request, inject auth
    const headers = new Headers(request.headers);
    headers.set("Authorization", `Bearer ${env.OPENROUTER_API_KEY}`);
    headers.set("HTTP-Referer", "https://github.com/LucasSantana-Dev/sharekit-profile");
    headers.set("X-Title", "Warp Terminal");

    const proxyReq = new Request(target, {
      method: request.method,
      headers,
      body: request.body,
      redirect: "follow",
    });

    return fetch(proxyReq);
  },
};
