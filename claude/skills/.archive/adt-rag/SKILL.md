---
name: rag
description: Build and debug Retrieval-Augmented Generation pipelines — chunking, embedding, retrieval, reranking
triggers:
  - rag
  - retrieval
  - build a rag
  - semantic search
  - document retrieval
  - vector search
---

# RAG

Build production-ready Retrieval-Augmented Generation pipelines. Don't retrieve blindly — curate what reaches the model.

## Pipeline Stages

```
Documents → Chunk → Embed → Index → [Query] → Retrieve → Rerank → Augment → Generate
```

## 1. Chunking Strategy

Choose based on document structure. See [references/chunking-strategies.md](references/chunking-strategies.md) for a table of strategies and key principles.

**Done when:** all documents chunked with strategy aligned to structure; metadata (source, section, page, timestamp) present in every chunk; no mid-sentence splits in sample of 10 chunks.

## 2. Embedding

```text
embed(chunk) → vector[dim]
```

**BLOCKER:** If embedding model switches mid-pipeline without re-embedding all chunks → retrieval fails silently. Stop and re-embed the entire index or roll back the model change.

See [references/embedding-models.md](references/embedding-models.md) for model options and critical rules about model matching.

**Done when:** embedding model confirmed identical for indexing and querying; all vectors normalized; index re-embedded if model changed since prior run; confirm no stale vectors in index.

## 3. Retrieval

**Dense retrieval** (semantic): cosine similarity over embeddings — good for paraphrase matching  
**Sparse retrieval** (BM25): keyword overlap — good for exact terms, names, codes  
**Hybrid**: combine both with RRF (Reciprocal Rank Fusion) — best for production

```text
Top-K candidates: start with K=20, rerank to top 3–5
```

**Query expansion**: generate 2–3 query variants before retrieval to improve coverage

**Done when:** K=20 retrieval confirmed working; top-3 candidates identified after reranking; query expansion variants logged; no empty result sets on sample queries.

## 4. Reranking

Never trust retrieval order alone — rerank before passing to LLM:

1. Cross-encoder reranker (e.g., `cross-encoder/ms-marco-MiniLM-L-6-v2`) — slow but accurate
2. LLM reranker: ask the model to score relevance (1–5) for each candidate
3. Reciprocal Rank Fusion: no reranker needed — combine multiple retrieval passes

**Done when:** all K=20 candidates scored by chosen reranker; final ranking differs from retrieval order (sanity check); top 3–5 passed to augmentation.

## 5. Context Augmentation

```text
System: You are a helpful assistant. Use only the provided context.
Context:
[1] <most relevant chunk>
[2] <second chunk>
...
User: <original query>
```

**Key rules:**
- Most relevant first — LLMs attend more to the beginning
- Include source citations in chunks (`[Source: doc.pdf, p.12]`)
- Set a hard token budget for context (e.g., 2000 tokens) — trim from the bottom

**Done when:** top-3 candidates formatted with citations; token count measured against budget; budget enforced (no overflow to LLM); grounding instruction added to system prompt.

## Debugging Checklist

See [references/debugging-guide.md](references/debugging-guide.md) for a systematic checklist and troubleshooting workflow.

## Output

```text
RAG Report
──────────
Stage:     <pipeline stage>
Chunks:    <total chunks indexed>
Retrieved: <K candidates>
Reranked:  <N passed to LLM>
Latency:   <ms per stage>
Issue:     <root cause if failing>
```
