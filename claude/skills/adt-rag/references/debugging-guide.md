# RAG Debugging Checklist

- [ ] **Retrieval:** are the right chunks being found? Log top-K before reranking
- [ ] **Embedding mismatch:** same model for index and query?
- [ ] **Chunk quality:** are chunks coherent? No mid-sentence splits?
- [ ] **Hallucination:** is the model ignoring retrieved context? Add grounding instruction
- [ ] **Latency:** which stage is slowest? Profile chunk → embed → retrieve → rerank

## How to use

Work through each item systematically. Start with embedding mismatch — it's the most common failure mode. Then verify chunk quality by sampling 10 random chunks. Finally, run a latency profile on your full pipeline to identify bottlenecks.
