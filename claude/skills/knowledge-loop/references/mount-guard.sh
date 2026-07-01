#!/bin/bash
# Mount guard — fail loud before any brain/RAG op (standards/knowledge-brain.md §1)
# Used by: knowledge-loop Phase 5, rag-maintenance, sync-memories, recall when search_knowledge is invoked

BRAIN="${DEV_ROOT}/knowledge-brain"

if ! mount | grep -q "${DEV_ROOT}" || [ ! -d "$BRAIN/.git" ]; then
  echo "BLOCKED: External HD not mounted — knowledge-brain unreachable." >&2
  echo "RAG/vault queries will fail. Surface to user; skip push/curate phases." >&2
  exit 1
fi
