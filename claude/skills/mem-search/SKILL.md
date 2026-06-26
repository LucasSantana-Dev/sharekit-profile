---
name: mem-search
description: 'Search past work across sessions. Use when: "did we already solve this?", "how did we do X last time?", "what happened [timeframe]?" See `recall` (vault) or `graphify` for alternative triggers.'
metadata:
  owner: operator
  tier: sonnet
  canonical_source: ~/.claude/skills/mem-search
---

# Memory Search

3-layer cross-session memory workflow: search index → timeline context → selective fetch.

**NOTE:** claude-mem ingestion is currently broken (218k stuck msgs). Skill reads existing data OK; cannot ingest new. For "what did we decide" queries, prefer `/recall` or `search_knowledge()` (vault-first). See decision table below.

## Decision: mem-search vs. recall vs. graphify

| Need | Use | Why |
|------|-----|-----|
| "How did we solve X?" (procedural past work) | **mem-search** | claude-mem search + timeline + fetch |
| "What did we decide about X?" (decisions/ADRs) | **recall** + vault | `search_knowledge()` → decision-brain (cross-project) |
| "Where in codebase is X?" (symbol defs, edges) | **graphify** | Symbol relationships + graph queries |
| "Describe the state of Y repo" (summary) | **recall** | Memory vault handoffs + snapshots |

**mem-search:** best for procedural recovery ("bug fixes around auth"), timeline context, session breadcrumbs.  
**recall:** best for cross-project decisions, ADRs, strategy; vault only, no code/commits.

## Workflow (3 Layers, ALWAYS in order)

**Critical:** filter before fetching (Step 2 → decision gate → Step 3). **10x token savings.**

### Step 1: Search Index

**Precondition:** `${DEV_ROOT}` mounted (knowledge-brain.md §1).

Call `search()` MCP to retrieve slim index (IDs, titles, types):

```bash
search(query="authentication", limit=20, project="my-project", obs_type="bugfix")
```

**Returns:** table with IDs, timestamps, types, titles (~50-100 tokens/result).

**Parameters:** query, limit (20–100), project, type ("observations"/"sessions"/"prompts"), obs_type ("bugfix", "feature", "decision", "discovery", "change"), dateStart/dateEnd (YYYY-MM-DD), offset, orderBy ("date_desc", "date_asc", "relevance").

**Done when:** table with ≥1 candidate ID, or "no results" message.

### Step 2: Timeline + Filter Gate

Call `timeline()` to see context (depth_before/after items around anchor):

```bash
timeline(anchor=11131, depth_before=3, depth_after=3, project="my-project")
```

Or auto-find anchor:

```bash
timeline(query="authentication", depth_before=3, depth_after=3, project="my-project")
```

**Returns:** chronological interleaved observations, sessions, prompts (~200-400 tokens).

**FILTER GATE (token-saving point):** Review titles + context. Discard irrelevant IDs. Keep only IDs you will fetch.

**Parameters:** anchor, query, depth_before (5, max 20), depth_after (5, max 20), project.

**Done when:** you've decided which IDs are relevant (or determined: none are).

### Step 3: Fetch Full Details

Call `get_observations()` for ONLY filtered IDs (batch in single call):

```bash
get_observations(ids=[11131, 10942])
```

**ALWAYS batch:** one HTTP request >> N individual calls.

**Returns:** complete objects—title, subtitle, narrative, facts, concepts, files (~500–1000 tokens each).

**Parameters:** ids (required), orderBy, limit, project.

**Done when:** fetched all filtered observations, or confirmed none to fetch (see reconciliation below).

## Fallback: When claude-mem is Unavailable or Empty

If `search()` returns "no results" or claude-mem is unreachable:

1. Check `${DEV_ROOT}` mounted: `mount | grep -q "${DEV_ROOT}"` → if unmounted, state blocker + suggest External HD recovery.
2. If results sparse: try `rag_query(query="<q>", top=5, scope_types=["memory","handoffs"])` for decision/memory artifacts in RAG index.
3. If still empty: state "no prior work found in mem-search; try `/recall` (vault), `/graphify` (code), or grep."

## Reconciliation & Output

**No hits:** "No memories found matching '<query>'; suggestions: (1) try broader search, (2) check project filter, (3) use `/recall` (decisions) or `/graphify` (code)."

**1 hit:** Return it inline (title + key facts); no "ask for list" needed.

**2–5 hits:** Return all; titles + summary bullets per observation.

**6+ hits:** Return top 3 inline (titles + key facts), then: "5 more observations match; ask for full list or narrow query."

**No relevance:** "Filtered timeline, but titles do not match intent; call `search()` with different `obs_type` or `dateStart`."

## Saving Memories

Manual observation storage (one-off discoveries, decision checkpoints):

```bash
save_memory(text="Authentication uses JWT with 24h expiry. Tokens stored in httpOnly cookies.", 
            title="Auth Token Design", project="my-project")
```

**Parameters:** text (required), title (optional, auto-generated), project (optional, defaults to "claude-mem").

**Done when:** returned observation ID (memory persisted).

## Related Skills

- **recall**: cross-project decisions, ADRs, strategy (vault-first; preferred for "what did we decide")
- **graphify**: code structure, symbol relationships, call graph
- **sync-memories**: persist current-session work into vault for future recall
