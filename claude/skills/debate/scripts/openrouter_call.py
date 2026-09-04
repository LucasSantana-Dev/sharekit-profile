#!/usr/bin/env python3
"""Call one or more OpenRouter models in parallel for a debate round.

Retrieves OPENROUTER_API_KEY from macOS Keychain (service name convention:
"OPENROUTER_API_KEY"), validates requested model slugs against OpenRouter's live
/models endpoint (slugs drift - do not trust training-data model names), dispatches
requests concurrently, and surfaces per-model failures individually instead of letting
one bad model kill the whole round.

Usage:
    python3 openrouter_call.py --prompt-file prompt.txt --models openai/gpt-5.5 google/gemini-3-pro-image ...
    python3 openrouter_call.py --prompt "inline prompt" --models deepseek/deepseek-v4-pro
    python3 openrouter_call.py --list-models openai google deepseek meta-llama   # discovery only

Writes one JSON object per line to stdout: {"model": ..., "label": ..., "text": ...}
or {"model": ..., "error": ...} on failure. Never raises on a single model's failure -
the caller decides whether a partial round is acceptable.
"""
import argparse
import concurrent.futures
import json
import subprocess
import sys

KEYCHAIN_SERVICE = "OPENROUTER_API_KEY"


def get_api_key():
    result = subprocess.run(
        ["security", "find-generic-password", "-s", KEYCHAIN_SERVICE, "-w"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        print(
            f"BLOCKED: no Keychain entry for service '{KEYCHAIN_SERVICE}'.\n"
            f"Missing: an OpenRouter API key stored via Keychain Access (service name "
            f"must be exactly '{KEYCHAIN_SERVICE}').\n"
            f"Next: add it, or proceed without OpenRouter (Claude-only round).",
            file=sys.stderr,
        )
        sys.exit(1)
    return result.stdout.strip()


def fetch_model_list(api_key):
    result = subprocess.run(
        ["curl", "-s", "https://openrouter.ai/api/v1/models",
         "-H", f"Authorization: Bearer {api_key}"],
        capture_output=True, text=True, timeout=30,
    )
    try:
        data = json.loads(result.stdout)
        return [m["id"] for m in data.get("data", [])]
    except Exception:
        return []


def call_model(api_key, model_id, prompt, max_tokens=600):
    body = json.dumps({
        "model": model_id,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": max_tokens,
    })
    result = subprocess.run(
        ["curl", "-s", "https://openrouter.ai/api/v1/chat/completions",
         "-H", f"Authorization: Bearer {api_key}",
         "-H", "Content-Type: application/json",
         "-d", body],
        capture_output=True, text=True, timeout=120,
    )
    try:
        data = json.loads(result.stdout)
    except Exception as e:
        return {"model": model_id, "error": f"non-JSON response: {e}: {result.stdout[:300]}"}
    if "error" in data:
        # Known shapes hit in practice: {"error":{"message":"Key limit exceeded ...","code":403}}
        # and {"error":{"message":"<slug> is not a valid model ID","code":400}}
        msg = data["error"].get("message", str(data["error"]))
        return {"model": model_id, "error": msg}
    try:
        text = data["choices"][0]["message"]["content"]
    except Exception as e:
        return {"model": model_id, "error": f"unexpected response shape: {e}: {json.dumps(data)[:300]}"}
    return {"model": model_id, "text": text}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--prompt", help="Inline prompt text")
    ap.add_argument("--prompt-file", help="Path to a file containing the prompt")
    ap.add_argument("--models", nargs="*", default=[], help="OpenRouter model slugs to call")
    ap.add_argument("--list-models", nargs="*", default=None,
                     help="Discovery only: list live model slugs matching these prefixes, then exit")
    ap.add_argument("--max-tokens", type=int, default=600)
    args = ap.parse_args()

    api_key = get_api_key()

    if args.list_models is not None:
        names = fetch_model_list(api_key)
        for prefix in args.list_models:
            matches = [n for n in names if n.startswith(prefix)]
            print(json.dumps({"prefix": prefix, "matches": matches[:10]}))
        return

    if not args.models:
        print("BLOCKED: no --models given and --list-models not requested.", file=sys.stderr)
        sys.exit(1)

    prompt = args.prompt
    if args.prompt_file:
        with open(args.prompt_file) as f:
            prompt = f.read()
    if not prompt:
        print("BLOCKED: no prompt given (--prompt or --prompt-file).", file=sys.stderr)
        sys.exit(1)

    # Validate slugs against the live list before spending a request on a guess.
    live_names = set(fetch_model_list(api_key))
    unknown = [m for m in args.models if live_names and m not in live_names]
    if unknown:
        print(
            f"WARNING: these model slugs were not found in OpenRouter's live /models list "
            f"(may still work if the list call itself failed, but likely to 400): {unknown}",
            file=sys.stderr,
        )

    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, len(args.models))) as ex:
        futures = [ex.submit(call_model, api_key, m, prompt, args.max_tokens) for m in args.models]
        for fut in futures:
            print(json.dumps(fut.result()))


if __name__ == "__main__":
    main()
