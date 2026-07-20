# Skill Patterns

Canonical, copy-pasteable templates for the recurring SKILL.md quality patterns.
`skill-quality-spec.md` is the **checklist** (verify yes/no); this file is the **how**.
Cite a section by anchor — e.g. `standards/skill-patterns.md §completion-criteria` —
instead of re-explaining the pattern inline. Source: skill-improvement-map audit
2026-06-26 (27-skill quality sweep, 8 systemic gaps).

---

## §completion-criteria

Every step ends on a **checkable** done-condition — the agent can tell done from
not-done without judgement. Vague endings ("ready", "looks good") invite premature
completion.

**Template:** end each step with a bold `**Done when:**` line.

```
## Step 2 — Score candidates
...
**Done when:** every candidate has an Impact × Frequency score; top 5 identified.
```

Make it *exhaustive* where it matters ("every modified model accounted for", not
"produce a change list"). Per-category phrasing:

| Category | A good "Done when:" reads… |
|---|---|
| Eval     | "metrics + per-case breakdown captured for all N cases" |
| RAG      | "index confirms 0 stale chunks" / "top-3 reranked results returned" |
| Agent    | "every agent has a bounded prompt + owner; dispatch acknowledged" |
| Loop     | "artifact created AND the narrow check passed" |
| Refactor | "every call-site updated; build green" |

---

## §stop-conditions

At least one explicit **blocker** per skill: a named precondition that, if unmet,
halts with a surfaced message — never a silent fallback that returns misleading output.

**Template:**

```
**Stop if:** <precondition> missing → surface "BLOCKED: <what>, <what would fix it>", halt.
```

Distinguish two kinds, both required where they apply:
- **Preventative guard** (before the work): "Stop if no baseline branch exists → BLOCKED."
- **Reactive blocker** (mid-work): "If the plan agent returns no plan → halt dispatch, surface."

Blocker output format (matches CLAUDE.md signal-first):
```
BLOCKED: <condition>
Missing: <what would resolve it>
Next: <how to proceed, if at all>
```

---

## §progressive-disclosure

SKILL.md holds only immediately-actionable steps. Target **< ~150 lines**. Push
reference material — tables, templates, long examples, rationale — into
`references/` and cite with a one-line pointer.

**3-step refactor:**
1. Extract each table / config block / >15-line example to `references/<name>.md`
   (`references/output-patterns.md`, `references/schemas.md`, `references/templates.md`).
2. Replace the inline block with one line: `See [references/<name>.md](references/<name>.md).`
3. Verify no content lives in **both** places. The error to hunt is duplication:
   an orphaned `references/` file never cited, or a cited file whose content is *also*
   still inline. Grep `references/` in SKILL.md; every file in the folder must be cited
   **at least once** (no orphans). The same pointer may legitimately appear in two steps
   that each need it — that is not duplication; duplicated *content* is.

Disclose what only *some* branches reach; inline what *every* run needs.

---

## §parallelism-signaling

When ≥2 steps/phases are independent, say so explicitly and tell the agent to
dispatch them together — otherwise they run sequentially and waste wall-clock.

**Template:**

```
Phases 2 and 3 are independent. Dispatch both in a single message (one Agent() call each)
so they run concurrently.
```

For parallel git-touching work, add: "each agent in its own worktree under
`${DEV_ROOT}/.worktrees/<task>-<n>/`" (CLAUDE.md
parallel-execution rule). For read-only fan-out, no worktree needed.

---

## §rag-first

Skills that answer "what did we decide / where did we hit this / what was the prior
result" query memory BEFORE wide grep/filesystem scans. Add a **Step 0**.

**Template (pick the matching use case):**

```bash
# prior result / regression check (e.g. last mutation score, last eval)
python3 ~/.claude/rag-index/query.py "<topic> prior result" --top 5 --scope memory

# decision lookup ("what did we decide about X")
search_knowledge(query="<question>", top=5)        # MCP, vault-only

# collision / name check before creating (agents, skills, files)
python3 ~/.claude/rag-index/query.py "<name> existing" --top 5
```

**Done when:** RAG queried; prior work cited or confirmed absent. Full source list:
`standards/skill-quality-spec.md` → "Verified RAG / knowledge invocation patterns".

---

## §mount-guard

**Mandatory** before any RAG-index or knowledge-brain reliance — the embedder cache
and vault live on external drive (knowledge-brain.md §1). Without the guard, RAG calls
degrade silently and return empty/misleading results.

**Template (place before the first rag_query / search_knowledge call):**

```bash
mount | grep -q "${DEV_ROOT}" || { echo "BLOCKED: external drive unmounted — RAG/vault unreachable"; exit 1; }
```

If unmounted: say so plainly, fall back to grep, do not return a confident-looking
empty result.

---

## §signal-first-output

Lead with the verdict. Then top-3 findings inline. Gate the rest. Never bury the
decision under a wall of detail (CLAUDE.md signal-first hard rule).

**Template:**

```
<VERDICT line: READY / NOT READY / PASS / 3 issues found>

Top 3:
1. <finding> — <evidence>
2. ...
3. ...

(N more — ask for the full list, or see <path>.)
```

Exempt: composite reconciliation blocks and plans with <4 phases (show all inline).

---

## §trigger-design

A model-invoked `description` lists ≥3 **genuinely distinct** trigger branches — not
synonyms renaming one branch. Each branch = a different intent/use case that should
fire the skill.

**Test:** if two triggers would always co-occur in the same request, they're one
branch written twice — collapse them. Front-load the skill's leading word.

```
description: >
  <lead verb + what it does>. Use when <branch 1: distinct intent>;
  when <branch 2: different intent>; or when <branch 3: different intent>.
```

---

## §reasoning-scaffold

The model-independence lever: a delegated prompt with explicit numbered steps produces the same
result whether a frontier or a cheap model runs it, because the procedure lives in the prompt, not
the model's head. Strong models self-scaffold; weak ones execute what they're told. Scaffold any
prompt that is delegated to a subagent, has ≥3 ordered steps, or has a gate the model could skip.
Full rationale: `standards/prompting-discipline.md` → "Reasoning scaffolds".

**Template (use in every subagent / delegated prompt):**

```
Goal: <one sentence — the observable end state>
Steps (in order, do not skip):
  1. <first concrete action — name the file/command/query>
  2. <next — reference the output of step 1>
  3. <verification — the check that proves it, e.g. "run <cmd>; expect <result>">
Constraints: <what must NOT happen — scope bound, read-only, no new deps>
Output: <exact shape — schema / path / N-bullet list>
Stop when: <success condition>; escalate if <blocker> instead of guessing.
```

The verification step is non-optional — without an explicit "prove it" step a weak model reports
success it didn't achieve (the self-report overclaim).

---

## §structured-output

Force the *shape* of a result so it doesn't depend on the model formatting well. In `Workflow`,
pass a JSON `schema` to `agent()` — validation happens at the tool layer and the model retries on
mismatch, so a malformed result is structurally impossible. For inline subagents, name the exact
output contract. This is research lever #1 (structured-output forcing, +~35-45pp on structured
tasks) and pairs with §reasoning-scaffold (scaffold the process; schema the result).

**Template (Workflow agent with forced schema):**

```js
const FINDINGS = { type: "object", required: ["verdict","items"], properties: {
  verdict: { enum: ["pass","fail"] },
  items: { type: "array", items: { type: "object",
    required: ["file","line","issue"], properties: {
      file: {type:"string"}, line: {type:"integer"}, issue: {type:"string"} } } } } }
const r = await agent(prompt, { schema: FINDINGS })   // r is validated — no parsing
```

**Done when:** the result is consumed as data (indexed/filtered/counted), never regex-scraped from prose.

---

## §read-only-agent

Make "this agent does not edit / shell out" **structural**, not a hope the model honors a prose
line. A prompt that says "read-only" has been violated in practice — agents wrote to disk anyway.
Remove the capability instead. For analysis phases (research, triage, audit, review, spec) dispatch
a write-incapable `agentType` so editing is impossible. Mirrors the CLAUDE.md read-only-enforcement
hard rule.

**Template:**

```
# Analysis subagent — write-incapable by construction
agentType: Explore | Plan | critic | code-reviewer | security-reviewer | overengineering-auditor
# In Workflow: set agentType on every analysis agent() stage; only explicit
# implementer stages get general-purpose / debugger / test-engineer.
```

**Done when:** every findings-returning agent uses a write-incapable type; edits derived from its
output are applied by the orchestrator or a separate implementer stage, never the analysis agent.
