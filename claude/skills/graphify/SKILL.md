---
name: graphify
description: "any input (code, docs, papers, images, videos) to knowledge graph. Use when user asks any question about a codebase, documents, or project content - especially if graphify-out/ exists, treat the question as a /graphify query."
triggers:
  - graphify
  - knowledge graph
  - build graph from
  - query the graph
  - graphify-out
---

# /graphify

Turn any folder of files into a navigable knowledge graph with community detection, an honest audit trail, and three outputs: interactive HTML, GraphRAG-ready JSON, and a plain-language GRAPH_REPORT.md.

## Command Reference

All invocation commands: `references/usage.md`

## What graphify is for

Drop any folder of code, docs, papers, images, or video into graphify and get a queryable knowledge graph. Persistent across sessions, honest audit trail (EXTRACTED/INFERRED/AMBIGUOUS), community detection surfaces cross-document connections you wouldn't think to ask about.

## What You Must Do When Invoked

If the user invoked `/graphify --help` or `/graphify -h` (with no other arguments), print the contents of the `## Command Reference` section from `references/usage.md` verbatim and stop. Do not run any commands, do not detect files, do not default the path to `.`. Just print the Usage block and return.

**Fast path — existing graph:** Before doing anything else, check whether `graphify-out/graph.json` exists. The expected location is `graphify-out/graph.json` relative to the **current working directory** (i.e. the project root where you are running commands). If it exists AND the user's request is a natural-language question about the codebase (e.g. "How does X work?", "What calls Y?", "Trace the data flow through Z") and NOT an explicit rebuild command (`--update`, `--cluster-only`, or a bare path/URL that implies fresh extraction): **skip Steps 1–5 entirely and jump straight to `## For /graphify query`.** Run `graphify query "<question>"` immediately. Do not run detect. Do not check corpus size. Do not ask the user to narrow. The graph is already built — use it.

If no path was given, use `.` (current directory). Do not ask the user for a path.

If the path argument starts with `https://github.com/` or `http://github.com/`, treat it as a GitHub URL - run Step 0 before anything else, then continue with the resolved local path.

Follow these steps in order. Do not skip steps.

### Step 0 - Clone GitHub repo(s)

See `references/step-0-clone-github.md`

### Step 1 - Ensure graphify is installed

See `references/step-1-install.md`

### Step 2 - Detect files

See `references/step-2-detect-files.md`

### Step 2.5 - Transcribe video / audio files

See `references/step-2-5-transcribe-video.md`

### Step 3 - Extract entities and relationships

See `references/step-3-extract-entities.md`

### Step 4 - Build graph, cluster, analyze, generate outputs

See `references/step-4-build-graph.md`

### Step 5 - Label communities

See `references/step-5-label-communities.md`

### Steps 6-9 - Outputs, exports, and cleanup

See `references/step-6-9-outputs-cleanup.md`

---

## Interpreter guard for subcommands

Before running any subcommand (`--update`, `--cluster-only`, `query`, `path`, `explain`, `add`), check that `.graphify_python` exists:

```bash
if [ ! -f graphify-out/.graphify_python ]; then
    GRAPHIFY_BIN=$(which graphify 2>/dev/null)
    if [ -n "$GRAPHIFY_BIN" ]; then
        PYTHON=$(head -1 "$GRAPHIFY_BIN" | tr -d '#!')
        case "$PYTHON" in *[!a-zA-Z0-9/_.-]*) PYTHON="python3" ;; esac
    else
        PYTHON="python3"
    fi
    mkdir -p graphify-out
    "$PYTHON" -c "import sys; open('graphify-out/.graphify_python', 'w', encoding='utf-8').write(sys.executable)"
fi
```

## Subcommands & Workflows

- `--update` (incremental re-extraction): `references/subcommands/update.md`
- `--cluster-only` (re-cluster existing graph): `references/subcommands/cluster-only.md`
- `/graphify query` (traverse & answer questions): `references/subcommands/query.md`
- `/graphify path` (shortest path between nodes): `references/subcommands/path.md`
- `/graphify explain` (explain a node): `references/subcommands/explain.md`
- `/graphify add` (fetch URL, add to corpus): `references/subcommands/add.md`
- `--watch` (auto-rebuild on file changes): `references/subcommands/watch.md`
- Git commit hook (auto-rebuild on commit): `references/subcommands/hook.md`
- CLAUDE.md integration (always-on mode): `references/subcommands/claude-integration.md`

## Honesty Rules

See `references/honesty-rules.md` for audit trail rules and output integrity standards.
