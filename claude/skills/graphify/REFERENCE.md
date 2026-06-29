# graphify — Operational Reference

Complete step-by-step pipeline, Python blocks, subagent logic, and configuration details for the /graphify skill.

## Table of Contents
- [Step 0: Clone GitHub Repos](#step-0--clone-github-repos)
- [Step 1: Ensure graphify is Installed](#step-1--ensure-graphify-is-installed)
- [Step 2: Detect Files](#step-2--detect-files)
- [Step 2.5: Transcribe Audio/Video](#step-25--transcribe-audiovideo)
- [Step 3: Extract Nodes and Edges](#step-3--extract-nodes-and-edges)
- [Step 4: Build Graph and Cluster](#step-4--build-graph-and-cluster)
- [Step 5: Generate Report and Viz](#step-5--generate-report-and-viz)
- [Step 6: Write Outputs](#step-6--write-outputs)
- [Part A: Subagent Dispatch Logic](#part-a--subagent-dispatch-logic)
- [Part B: Cross-Repo Merge Patterns](#part-b--cross-repo-merge-patterns)
- [Part C: Query and Explain Logic](#part-c--query-and-explain-logic)
- [Whisper Configuration](#whisper-configuration)
- [MCP Server Mode](#mcp-server-mode)
- [Watch Mode](#watch-mode)

---

## Step 0: Clone GitHub Repos

**Single repo:**
```bash
LOCAL_PATH=$(graphify clone <github-url> [--branch <branch>])
# Use LOCAL_PATH as the target for all subsequent steps
```

**Multiple repos (cross-repo graph):**

For each repo, clone first. Reuse existing clones on repeat runs.

```bash
graphify clone https://github.com/owner1/repo1 # → ~/.graphify/repos/owner1/repo1
graphify clone https://github.com/owner2/repo2 # → ~/.graphify/repos/owner2/repo2
```

After cloning, continue to Step 1 with each local path. After building individual graphs, use Part B to merge them.

---

## Step 1: Ensure graphify is Installed

Detect the correct Python interpreter. Handles uv tool, pipx, venv, and system python3.

```bash
PYTHON=""
GRAPHIFY_BIN=$(which graphify 2>/dev/null)

# 1. Try uv tool installs (most reliable on modern Mac/Linux)
if [ -z "$PYTHON" ] && command -v uv >/dev/null 2>&1; then
    _UV_PY=$(uv tool run graphify python -c "import sys; print(sys.executable)" 2>/dev/null)
    if [ -n "$_UV_PY" ]; then PYTHON="$_UV_PY"; fi
fi

# 2. Read shebang from graphify binary (pipx, direct pip installs)
if [ -z "$PYTHON" ] && [ -n "$GRAPHIFY_BIN" ]; then
    _SHEBANG=$(head -1 "$GRAPHIFY_BIN" | tr -d '#!')
    case "$_SHEBANG" in
        *[!a-zA-Z0-9/_.-]*) ;;
        *) "$_SHEBANG" -c "import graphify" 2>/dev/null && PYTHON="$_SHEBANG" ;;
    esac
fi

# 3. Fall back to python3
if [ -z "$PYTHON" ]; then PYTHON="python3"; fi

# 4. Install if missing
if ! "$PYTHON" -c "import graphify" 2>/dev/null; then
    if command -v uv >/dev/null 2>&1; then
        echo "Installing graphify via uv..."
        uv tool install --upgrade graphify -q 2>&1 | tail -3
        _UV_PY=$(uv tool run graphify python -c "import sys; print(sys.executable)" 2>/dev/null)
        if [ -n "$_UV_PY" ]; then PYTHON="$_UV_PY"; fi
    else
        echo "Installing graphify via pip..."
        "$PYTHON" -m pip install graphify -q 2>/dev/null \
          || "$PYTHON" -m pip install graphify -q --break-system-packages 2>&1 | tail -3
    fi
fi

# Save interpreter path for all subsequent steps
mkdir -p graphify-out
"$PYTHON" -c "import sys; open('graphify-out/.graphify_python', 'w', encoding='utf-8').write(sys.executable)"
echo "$(cd INPUT_PATH && pwd)" > graphify-out/.graphify_root
```

If the import succeeds, print nothing and move to Step 2.

---

## Step 2: Detect Files

```bash
PYTHON=$(cat graphify-out/.graphify_python)
SCAN_ROOT=$(cat graphify-out/.graphify_root)

$PYTHON << 'PYTHON_DETECT'
import json
from graphify.detect import detect
from pathlib import Path
import sys

scan_root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
detected = detect(str(scan_root))

# Output format: JSON with file counts by type
output = {
    "code_files": detected.get("code_files", []),
    "doc_files": detected.get("doc_files", []),
    "media_files": detected.get("media_files", []),
    "count": {
        "code": len(detected.get("code_files", [])),
        "docs": len(detected.get("doc_files", [])),
        "media": len(detected.get("media_files", []))
    }
}
print(json.dumps(output, indent=2))
PYTHON_DETECT
```

Expected output: JSON with file lists and counts. If count is 0, warn the user ("no code/docs found").

---

## Step 2.5: Transcribe Audio/Video

Only run if `media_files` list from Step 2 is non-empty.

```bash
PYTHON=$(cat graphify-out/.graphify_python)
WHISPER_MODEL=${WHISPER_MODEL:-"base"}  # tiny, small, base, medium, large

$PYTHON << 'PYTHON_TRANSCRIBE'
import json
from graphify.transcribe import transcribe_all
from pathlib import Path
import sys

scan_root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
model_size = sys.argv[2] if len(sys.argv) > 2 else "base"

# Download Whisper model if needed; transcribe all media files
transcripts = transcribe_all(str(scan_root), model=model_size)

output = {
    "model": model_size,
    "transcripts_created": len(transcripts),
    "files": transcripts
}
print(json.dumps(output, indent=2))
PYTHON_TRANSCRIBE
```

Transcriptions are saved to `graphify-out/transcripts.json`. Continue to Step 3.

---

## Step 3: Extract Nodes and Edges

```bash
PYTHON=$(cat graphify-out/.graphify_python)
SCAN_ROOT=$(cat graphify-out/.graphify_root)
MODE=${MODE:-"default"}  # "deep" for richer INFERRED edges

$PYTHON << 'PYTHON_EXTRACT'
import sys, json
from graphify.extract import collect_files, extract
from graphify.cache import check_semantic_cache, save_semantic_cache
from pathlib import Path

scan_root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
mode = sys.argv[2] if len(sys.argv) > 2 else "default"

# Collect files from Step 2
files = collect_files(str(scan_root))

# Check semantic cache for unchanged files
cache_hits = check_semantic_cache("graphify-out/.cache", files)

# Extract nodes and edges (EXTRACTED + INFERRED)
nodes, edges = extract(
    files=files,
    mode=mode,  # "deep" triggers richer INFERRED edges
    cache_hits=cache_hits,
    transcripts_path="graphify-out/transcripts.json"
)

# Save semantic cache for next run
save_semantic_cache("graphify-out/.cache", files, nodes, edges)

output = {
    "nodes": len(nodes),
    "edges": len(edges),
    "extracted": sum(1 for e in edges if e.get("type") == "EXTRACTED"),
    "inferred": sum(1 for e in edges if e.get("type") == "INFERRED"),
    "ambiguous": sum(1 for e in edges if e.get("type") == "AMBIGUOUS")
}

# Save intermediate JSON for Step 4
with open("graphify-out/extracted.json", "w") as f:
    json.dump({"nodes": nodes, "edges": edges}, f)

print(json.dumps(output, indent=2))
PYTHON_EXTRACT
```

Output: node and edge counts by type. All data saved to `graphify-out/extracted.json`.

---

## Step 4: Build Graph and Cluster

```bash
PYTHON=$(cat graphify-out/.graphify_python)

$PYTHON << 'PYTHON_BUILD'
import sys, json
from graphify.build import build_from_json
from graphify.cluster import cluster, score_all
from pathlib import Path

# Load extracted data
with open("graphify-out/extracted.json") as f:
    data = json.load(f)

# Build NetworkX graph
graph = build_from_json(data["nodes"], data["edges"])

# Cluster using Louvain community detection
communities = cluster(graph)

# Score nodes by surprise and centrality
node_scores = score_all(graph, communities)

# Identify god nodes (high centrality) and surprising connections
output = {
    "communities": len(communities),
    "god_nodes": node_scores["top_centrality"][:5],
    "surprising": node_scores["top_surprise"][:5],
    "graph_file": "graphify-out/graph.json"
}

# Save graph as JSON (NetworkX export)
from graphify.export import to_json
graph_json = to_json(graph, node_scores, communities)
with open("graphify-out/graph.json", "w") as f:
    json.dump(graph_json, f)

print(json.dumps(output, indent=2))
PYTHON_BUILD
```

Output: community count, god nodes, surprising connections. Full graph saved to `graphify-out/graph.json`.

---

## Step 5: Generate Report and Viz

```bash
PYTHON=$(cat graphify-out/.graphify_python)

$PYTHON << 'PYTHON_REPORT'
import json
from graphify.report import generate
from graphify.build import build_from_json
from pathlib import Path

# Load graph
with open("graphify-out/graph.json") as f:
    graph_data = json.load(f)

# Generate plain-language report
report = generate(graph_data)

# Save GRAPH_REPORT.md
with open("graphify-out/GRAPH_REPORT.md", "w") as f:
    f.write(report)

# Generate interactive HTML visualization
from graphify.viz import build_html
html = build_html(graph_data)
with open("graphify-out/index.html", "w") as f:
    f.write(html)

output = {
    "report": "graphify-out/GRAPH_REPORT.md",
    "html": "graphify-out/index.html"
}
print(json.dumps(output, indent=2))
PYTHON_REPORT
```

Output: report and HTML saved.

---

## Step 6: Write Outputs

```bash
PYTHON=$(cat graphify-out/.graphify_python)

$PYTHON << 'PYTHON_EXPORT'
import json
from pathlib import Path

# Load graph
with open("graphify-out/graph.json") as f:
    graph_data = json.load(f)

# Optional exports (format-specific)
# Each is conditional on corresponding CLI flag

# SVG export (if --svg passed)
if Path(".graphify_flags").read_text().find("--svg") > -1:
    from graphify.export import to_svg
    svg = to_svg(graph_data)
    with open("graphify-out/graph.svg", "w") as f:
        f.write(svg)

# GraphML export (if --graphml passed)
if Path(".graphify_flags").read_text().find("--graphml") > -1:
    from graphify.export import to_graphml
    graphml = to_graphml(graph_data)
    with open("graphify-out/graph.graphml", "w") as f:
        f.write(graphml)

# Neo4j Cypher export (if --neo4j passed)
if Path(".graphify_flags").read_text().find("--neo4j") > -1:
    from graphify.export import to_cypher
    cypher = to_cypher(graph_data)
    with open("graphify-out/cypher.txt", "w") as f:
        f.write(cypher)

output = {
    "status": "complete",
    "outputs": {
        "graph.json": "graphify-out/graph.json",
        "GRAPH_REPORT.md": "graphify-out/GRAPH_REPORT.md",
        "index.html": "graphify-out/index.html"
    }
}
print(json.dumps(output, indent=2))
PYTHON_EXPORT
```

---

## Part A: Subagent Dispatch Logic

When the user provides multiple repos or a large corpus, dispatch subagents in parallel for extraction.

**Dispatch strategy:**
1. Clone all repos to `~/.graphify/repos/` in Step 0
2. For each cloned repo, dispatch a subagent to run Steps 1–5 independently
3. Each subagent writes its own `graphify-out/graph.json` inside the cloned repo
4. Parent agent merges all graph.json files using Part B logic
5. Final merged graph is written to the working directory's `graphify-out/graph.json`

**Subagent template:**
```
Task: Run full graphify pipeline on <REPO_PATH>
Output: <REPO_PATH>/graphify-out/graph.json
Parallel: Yes (run one per cloned repo)
```

---

## Part B: Cross-Repo Merge Patterns

Once individual graphs are built, merge them into a single cross-repo graph.

**For multiple local folders in a monorepo:**
```bash
graphify merge-graphs \
  ./service-a/graphify-out/graph.json \
  ./service-b/graphify-out/graph.json \
  ./service-c/graphify-out/graph.json \
  --out graphify-out/cross-repo-graph.json
```

**For multiple cloned repos:**
```bash
graphify merge-graphs \
  ~/.graphify/repos/owner1/repo1/graphify-out/graph.json \
  ~/.graphify/repos/owner2/repo2/graphify-out/graph.json \
  --out graphify-out/cross-repo-graph.json
```

Each node in the merged graph carries a `repo` attribute so you can filter by origin:
```
query "How does auth work?" # Returns nodes tagged with their repo origin
```

---

## Part C: Query and Explain Logic

Once the graph exists, answer user questions using BFS (breadth-first search) by default.

### Query (BFS Traversal)

```bash
graphify query "<user-question>"
```

**Output:** Multi-hop traversal from concept to concept. Broad context, good for "How does X work?" questions.

**Flags:**
- `--dfs` — Use depth-first search instead. Good for "Trace the data flow through Z"
- `--budget N` — Cap answer at N tokens

**Explanation (Plain-Language Node Summary)**

```bash
graphify explain "NodeName"
```

**Output:** Plain-language explanation of a single node, its neighbors, and its role in the graph.

### Path (Shortest Path Between Concepts)

```bash
graphify path "AuthModule" "Database"
```

**Output:** Shortest path in the graph, hop-by-hop.

---

## Whisper Configuration

Audio/video transcription uses OpenAI's Whisper. Model size is configurable via `--whisper-model`:

- `tiny` — Fastest, lowest accuracy (~39M params)
- `small` — Balanced (~140M params)
- `base` — Default, good quality (~140M params)
- `medium` — Better accuracy (~769M params)
- `large` — Best accuracy (~1550M params, requires more VRAM)

**Set via CLI:**
```
/graphify <path> --whisper-model medium
```

**Environment override:**
```bash
export WHISPER_MODEL=large
/graphify <path>
```

---

## MCP Server Mode

Start an MCP (Model Context Protocol) stdio server for agent access to the graph. Agents can query and explain via the MCP interface without re-extracting.

```bash
graphify <path> --mcp
```

The server listens on stdio and exposes tools:
- `query(question, dfs=False, budget=1500)` → answer
- `explain(node_name)` → explanation
- `path(source, target)` → shortest path

Useful for integrating the graph into agentic workflows.

---

## Watch Mode

Automatically rebuild the graph when files change. No LLM needed — purely file-system-triggered extraction and clustering.

```bash
graphify <path> --watch
```

Monitors the scanned directory for changes:
- New/modified files → re-extract Step 3 only (incremental)
- Deletions → rebuild graph (Step 4 only)
- Changes to dir structure → full rebuild

Watch mode is passive; it does NOT push results to the user. Use in the background while editing code; query the graph when ready.

---

## Output Files

All outputs written to `graphify-out/`:

| File | Purpose |
|------|---------|
| `graph.json` | NetworkX graph export; Obsidian vault ready |
| `GRAPH_REPORT.md` | Plain-language audit trail + analysis |
| `index.html` | Interactive visualization (explore in browser) |
| `graph.svg` | SVG export (embed in Notion, GitHub) |
| `graph.graphml` | Gephi/yEd format |
| `cypher.txt` | Neo4j import script |
| `.graphify_python` | Interpreter path (persists across runs) |
| `.graphify_root` | Scan root directory (persists across runs) |
| `.cache/` | Semantic cache (for incremental `--update`) |
| `transcripts.json` | Whisper transcription results |
| `extracted.json` | Intermediate nodes/edges (deleted after Step 5) |

