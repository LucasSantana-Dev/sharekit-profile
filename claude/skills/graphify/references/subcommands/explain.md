# /graphify explain

Give a plain-language explanation of a single node - everything connected to it.

```bash
graphify explain "NODE_NAME"
```

Replace `NODE_NAME` with the concept the user asked about. Then write a 3-5 sentence explanation of what this node is, what it connects to, and why those connections are significant. Use the source locations as citations.

After writing the explanation, save it back:

```bash
$(cat graphify-out/.graphify_python) -m graphify save-result --question "Explain NODE_NAME" --answer "ANSWER" --type explain --nodes NODE_NAME
```
