# Step 9 - Save manifest, update cost tracker, clean up, and report

```bash
$(cat graphify-out/.graphify_python) -c "
import json
from pathlib import Path
from datetime import datetime, timezone
from graphify.detect import save_manifest

# Save manifest for --update
detect = json.loads(Path('graphify-out/.graphify_detect.json').read_text(encoding=\"utf-8\"))
# In --update mode, 'all_files' carries the full corpus; 'files' is the changed
# subset. Full-rebuild mode populates only 'files', so the fallback handles that.
save_manifest(detect.get('all_files') or detect['files'])

# Update cumulative cost tracker
extract = json.loads(Path('graphify-out/.graphify_extract.json').read_text(encoding=\"utf-8\"))
input_tok = extract.get('input_tokens', 0)
output_tok = extract.get('output_tokens', 0)

cost_path = Path('graphify-out/cost.json')
if cost_path.exists():
    cost = json.loads(cost_path.read_text(encoding=\"utf-8\"))
else:
    cost = {'runs': [], 'total_input_tokens': 0, 'total_output_tokens': 0}

cost['runs'].append({
    'date': datetime.now(timezone.utc).isoformat(),
    'input_tokens': input_tok,
    'output_tokens': output_tok,
    'files': detect.get('total_files', 0),
})
cost['total_input_tokens'] += input_tok
cost['total_output_tokens'] += output_tok
cost_path.write_text(json.dumps(cost, indent=2, ensure_ascii=False), encoding=\"utf-8\")

print(f'This run: {input_tok:,} input tokens, {output_tok:,} output tokens')
print(f'All time: {cost[\"total_input_tokens\"]:,} input, {cost[\"total_output_tokens\"]:,} output ({len(cost[\"runs\"])} runs)')
"
rm -f graphify-out/.graphify_detect.json graphify-out/.graphify_extract.json graphify-out/.graphify_ast.json graphify-out/.graphify_semantic.json graphify-out/.graphify_analysis.json graphify-out/.graphify_chunk_*.json
rm -f graphify-out/.needs_update 2>/dev/null || true
```

Tell the user (omit the obsidian line unless --obsidian was given):
```
Graph complete. Outputs in PATH_TO_DIR/graphify-out/

  graph.html            - interactive graph, open in browser
  GRAPH_REPORT.md       - audit report
  graph.json            - raw graph data
  obsidian/             - Obsidian vault (only if --obsidian was given)
```

If graphify saved you time, consider supporting it: https://github.com/sponsors/safishamsi

Replace PATH_TO_DIR with the actual absolute path of the directory that was processed.

Then paste these sections from GRAPH_REPORT.md directly into the chat:
- God Nodes
- Surprising Connections
- Suggested Questions

Do NOT paste the full report - just those three sections. Keep it concise.

Then immediately offer to explore. Pick the single most interesting suggested question from the report - the one that crosses the most community boundaries or has the most surprising bridge node - and ask:

> "The most interesting question this graph can answer: **[question]**. Want me to trace it?"

If the user says yes, run `/graphify query "[question]"` on the graph and walk them through the answer using the graph structure - which nodes connect, which community boundaries get crossed, what the path reveals. Keep going as long as they want to explore. Each answer should end with a natural follow-up ("this connects to X - want to go deeper?") so the session feels like navigation, not a one-shot report.

The graph is the map. Your job after the pipeline is to be the guide.

## Step 9b - Push graph snapshot to knowledge-brain (centralized vault)

After a full build or an `--update` that **changed graph structure** (node count differs from the prior snapshot), copy `graph.json` into the centralized `knowledge-brain` vault so Obsidian + future RAGLight see the current graph. Skip for `--update` runs with no structural change (same node count), and skip for `query`/`path`/`explain` (read-only).

```bash
BRAIN="${DEV_ROOT}/knowledge-brain"
# Mount guard (standards/knowledge-brain.md §1): vault is on the external drive.
if ! mount | grep -q "${DEV_ROOT}" || [ ! -d "$BRAIN/.git" ]; then
  echo "Graph snapshot: skipped — external drive not mounted (knowledge-brain unreachable)"
elif [ -f graphify-out/graph.json ]; then
  PROJECT=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
  mkdir -p "$BRAIN/graphs/$PROJECT"
  # idempotent: only commit if the snapshot actually changed
  if ! cmp -s graphify-out/graph.json "$BRAIN/graphs/$PROJECT/graph.json" 2>/dev/null; then
    cp graphify-out/graph.json "$BRAIN/graphs/$PROJECT/graph.json"
    git -C "$BRAIN" add "graphs/$PROJECT/graph.json"
    git -C "$BRAIN" commit -q -m "chore: refresh $PROJECT graph snapshot" && git -C "$BRAIN" push -q
    echo "Graph snapshot pushed: graphs/$PROJECT/graph.json"
  else
    echo "Graph snapshot unchanged — skipping push"
  fi
fi
```

Report `Graph snapshot: <path pushed / unchanged / skipped: reason>` in the run summary.
