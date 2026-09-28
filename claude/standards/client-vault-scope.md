# Client vault scope

Client work must start one of two ways:

1. The session opens with the working directory inside a client root (a path listed under that client's `roots` in the shelfmark registry), or
2. The session sets `RAG_CLIENT=<slug>` before any memory write.

**Why this matters:** `memory-scope-gate.sh` decides whether a client is active by checking the current working directory against the registry, or by reading `RAG_CLIENT`. If a session opens in a generic parent folder instead (a workspace root, a scratch dir, a multi-client umbrella folder), neither signal fires. The gate then treats every memory write as general, client isolation never engages, and business detail from the engagement can land in the general vault unflagged. Getting this wrong is the single most common cause of "the gate never saw the client."

**What this looks like in practice:**

- Opening a terminal in `<client-root>/` or a subdirectory of it: the gate resolves the active client from the cwd automatically.
- Opening a terminal anywhere else (a parent folder that holds several clients, a tools repo, a home directory) while working for a client: export `RAG_CLIENT=<slug>` first, in that shell, before any memory write happens.
- `RAG_CLIENT=none` explicitly turns client rules off for the session, distinct from leaving it unset.

See `.harness/memory-scopes.json` for the registry shape and lookup order, and the `client-offboard` skill for the client's full lifecycle (scaffold, harvest, offboard).
