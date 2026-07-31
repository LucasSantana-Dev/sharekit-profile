#!/usr/bin/env python3
"""mock_router_model.py — offline OpenRouter stub for tests/evals.bats.

Serves POST /chat/completions on 127.0.0.1:MOCK_PORT. Parses the router prompt,
finds the embedded "User request:" text, and answers with the expected skill
from the eval datasets (MOCK_MODE=oracle) or a fixed wrong answer
(MOCK_MODE=always_none). Lets the gate mechanics be tested without network.

Usage: MOCK_PORT=18099 MOCK_MODE=oracle python3 mock_router_model.py
"""
from __future__ import annotations

import glob
import json
import os
import re
from http.server import BaseHTTPRequestHandler, HTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
DATASET_GLOB = os.path.join(HERE, "..", "..", "evals", "routing",
                            "dataset", "routing_*.jsonl")
PORT = int(os.environ.get("MOCK_PORT", "18099"))
MODE = os.environ.get("MOCK_MODE", "oracle")
_REQ_RX = re.compile(r"User request:\n(.*?)\n\nAnswer with only", re.DOTALL)


def load_oracle() -> dict[str, str]:
    oracle: dict[str, str] = {}
    for path in sorted(glob.glob(DATASET_GLOB)):
        for line in open(path):
            d = json.loads(line)
            oracle[" ".join(d["prompt"].split())] = d["expected"]
    return oracle


ORACLE = load_oracle()


class Handler(BaseHTTPRequestHandler):
    def do_POST(self) -> None:  # noqa: N802
        length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(length) or b"{}")
        prompt = body["messages"][0]["content"]
        m = _REQ_RX.search(prompt)
        request_text = " ".join(m.group(1).split()) if m else ""
        if MODE == "always_none":
            answer = "none"
        else:
            answer = ORACLE.get(request_text, "none")
        payload = json.dumps({
            "choices": [{"message": {"role": "assistant", "content": answer}}]
        }).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, *args) -> None:
        pass


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
