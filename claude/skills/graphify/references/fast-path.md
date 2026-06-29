# Fast Path - Use existing graph

If `graphify-out/graph.json` exists, the graph is already built.

**Before doing anything else**, check whether `graphify-out/graph.json` exists. The expected location is `graphify-out/graph.json` relative to the **current working directory** (i.e. the project root where you are running commands).

**Fast path triggers:** If it exists AND the user's request is a natural-language question about the codebase (e.g. "How does X work?", "What calls Y?", "Trace the data flow through Z") and NOT an explicit rebuild command (`--update`, `--cluster-only`, or a bare path/URL that implies fresh extraction):

**Skip Steps 1–5 entirely and jump straight to `/graphify query`.** Run `graphify query "<question>"` immediately. Do not run detect. Do not check corpus size. Do not ask the user to narrow. The graph is already built — use it.

This bypasses the full pipeline and answers questions directly using the existing graph. This is the primary way to use graphify once a graph has been built.
