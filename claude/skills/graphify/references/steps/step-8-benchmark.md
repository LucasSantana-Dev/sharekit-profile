# Step 8 - Token reduction benchmark

Only if `total_words` from `graphify-out/.graphify_detect.json` is greater than 5,000.

```bash
graphify benchmark
```

Print the output directly in chat. If `total_words <= 5000`, skip silently - the graph value is structural clarity, not token compression, for small corpora.
