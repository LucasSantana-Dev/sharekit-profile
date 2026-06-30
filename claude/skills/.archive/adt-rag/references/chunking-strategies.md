# Chunking Strategies

Choose based on document structure:

| Strategy        | Use when                         | Chunk size                    |
| --------------- | -------------------------------- | ----------------------------- |
| Fixed-size      | Uniform docs (logs, transcripts) | 256–512 tokens, 10% overlap   |
| Semantic        | Articles, manuals, code          | Split on headings/paragraphs  |
| Hierarchical    | Nested content (books, wikis)    | Parent + child chunks         |
| Sentence-window | QA over dense text               | 3–5 sentences, sliding window |

## Key principles

- Always include metadata (source, section, page, timestamp)
- Overlap prevents context being split at chunk boundaries
- Smaller chunks → better precision; larger chunks → better context
