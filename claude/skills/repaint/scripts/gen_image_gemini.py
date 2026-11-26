"""Generate or edit an image via the Gemini API (key from GEMINI_API_KEY, never printed).

This script is provider-specific and optional: any image-generation model with a references
or image-editing mode works the same way (send a prompt, optionally send reference images,
get an image back). Swap the endpoint and payload shape below for another provider if that
is what the project already uses.

usage: python3 gen_image_gemini.py "<prompt>" <output.png> [--model M] [--ref img1.png --ref img2.png]

--ref sends reference images along with the prompt (edit, vary a pose, or copy the style of
an official asset). The default model is set by DEFAULT_MODEL below.
"""
import argparse
import base64
import json
import mimetypes
import os
import sys
import urllib.error
import urllib.request

DEFAULT_MODEL = "gemini-2.5-flash-image"

p = argparse.ArgumentParser()
p.add_argument("prompt")
p.add_argument("output")
p.add_argument("--model", default=DEFAULT_MODEL)
p.add_argument("--ref", action="append", default=[])
a = p.parse_args()

api_key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
if not api_key:
    sys.exit("no GEMINI_API_KEY in the environment")

parts = [{"text": a.prompt}]
for ref_path in a.ref:
    mime = mimetypes.guess_type(ref_path)[0] or "image/png"
    with open(ref_path, "rb") as f:
        parts.append({"inline_data": {"mime_type": mime, "data": base64.b64encode(f.read()).decode()}})

body = json.dumps({
    "contents": [{"parts": parts}],
    "generationConfig": {"responseModalities": ["TEXT", "IMAGE"]},
}).encode()
req = urllib.request.Request(
    f"https://generativelanguage.googleapis.com/v1beta/models/{a.model}:generateContent",
    data=body,
    headers={"x-goog-api-key": api_key, "Content-Type": "application/json"},
)
try:
    resp = json.load(urllib.request.urlopen(req, timeout=180))
except urllib.error.HTTPError as e:
    err = json.loads(e.read() or b"{}").get("error", {})
    sys.exit(f"ERROR {e.code} {err.get('status')}: {err.get('message', '')[:300]}")

images, texts = 0, []
for cand in resp.get("candidates", []):
    for part in cand.get("content", {}).get("parts", []):
        data = part.get("inlineData") or part.get("inline_data")
        if data:
            dest = a.output if images == 0 else a.output.replace(".png", f"-{images}.png")
            with open(dest, "wb") as f:
                f.write(base64.b64decode(data["data"]))
            print("saved:", dest)
            images += 1
        elif part.get("text"):
            texts.append(part["text"].strip())
if texts:
    print("model text:", " ".join(texts)[:300])
usage = resp.get("usageMetadata", {})
print("tokens:", usage.get("promptTokenCount"), "in,", usage.get("candidatesTokenCount"), "out")
if not images:
    sys.exit("no image in the response (reason: %s)" % [c.get("finishReason") for c in resp.get("candidates", [])])
