#!/bin/bash
# Mount guard — fail loud before any brain/RAG op (standards/knowledge-brain.md §1)
# Used by: knowledge-loop Phase 5, rag-curate, sync-memories, recall when search_knowledge is invoked

if [ -z "$DEV_ROOT" ]; then
  echo "BLOCKED: \$DEV_ROOT is unset — cannot locate knowledge-brain." >&2
  echo "Surface to user; skip push/curate phases." >&2
  exit 1
fi

BRAIN="${DEV_ROOT}/knowledge-brain"

# Directory reachability is the real signal here — `mount` only lists actual
# mount points (e.g. ${DEV_ROOT}), never subdirectories like
# $DEV_ROOT, so grepping mount output for a nested path always false-positives
# as "unmounted" even when the volume is present and the path is reachable.
if [ ! -d "$BRAIN/.git" ]; then
  echo "BLOCKED: external drive not mounted — knowledge-brain unreachable." >&2
  echo "RAG/vault queries will fail. Surface to user; skip push/curate phases." >&2
  exit 1
fi
