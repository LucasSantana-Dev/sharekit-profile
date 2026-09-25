---
name: client-offboard
description: Keep the technical and behavioral lessons from a client engagement and remove that client's business knowledge from memory and the RAG index. Modes - harvest (batch-promote pending lessons to general memory), promote-now NOTE (one lesson), offboard SLUG (final harvest, purge, verification). Use for "offboard client", "trocar de cliente", "encerrar cliente", "harvest lessons", "purge client", or at session close in a client repo.
argument-hint: "harvest | promote-now <note> | offboard <slug>"
triggers:
  - offboard client
  - trocar de cliente
  - encerrar cliente
  - harvest lessons
  - promote-now
  - purge client
---

# client-offboard

Two invariants, in this order:

1. **Learning is never lost.** Technical and behavioral lessons survive every purge. When in doubt, keep and ask. Never delete.
2. **One client's business never reaches another.** Domain rules, org hierarchy, people, numbers, confidential facts: none of it goes to general memory. Not even inside a "generalized" lesson.

## Where things live

| What | Where |
|---|---|
| Clients | shelfmark registry: `$SHELFMARK_CLIENTS` or `$RAG_HOME/clients.json`, as `{slug: {db, roots}}` |
| Client vault | any `memory/` dir under the client's roots (the client's own repo) |
| General vault | the operator's cross-project memory dir (ask once if unclear) |
| Lexicon | `<root>/.client/lexicon.txt`: names, people, acronyms, IDs, one per line |
| Manifest | `<general vault>/.harvest-manifest.jsonl`: one line per promoted lesson |
| Review queue | `$MEMORY_REVIEW_QUEUE` (the memory gate's lexicon hits) |

**Candidates are derived, never flagged.** A candidate is a client-vault note of type `feedback`, `gotcha` or `finding` whose path is not in the manifest yet, plus every review-queue entry for that client.

## Mode: harvest (continuous; run at session close in a client repo)

1. List the candidates. None? Say "nothing to harvest" and stop.
2. For each candidate, a read-only agent drafts the lesson in the general form:
   - Keep the mechanism, the failure mode and the rule of thumb.
   - Drop names, people, org structure, amounts, dates, IDs, product names, domain rules, and any quote from a client document.
   - Rewrite examples into a neutral domain of your own ("an invoicing system", "a permissions service").
3. Run the two-question test. It is two separate gates, as in the legal conflict and confidentiality rules:
   - **(a) Inference:** could someone who reads only this lesson infer a fact specific to the client's business?
   - **(b) Confidentiality:** does it contain anything the client would consider confidential, even if nothing can be inferred?
   - Either "yes" means rewrite once. If it is still "yes", the note stays in the client vault only.
4. Grep the draft against the client's lexicon. Any hit means rewrite. Never promote a draft with a hit.
5. Show the operator the batch: original path, draft and test result. Promote only the ones they approve.
6. For each approved lesson:
   - Write the note to the general vault with frontmatter `knowledge: technical` or `knowledge: behavioral`, plus `origin: client-<slug>`. The memory gate requires the tag while a client is active.
   - Append a line to the manifest: `{ts, client, source, target, sha256 of target}`.
   - Leave the original untouched in the client vault.
7. Report: N promoted, M kept client-only, K rejected by the test.

## Mode: promote-now <note>

The same steps 2 to 6, for a single note, right when the operator recognizes a lesson. Keep it cheap: one draft, one test, one approval.

## Mode: offboard <slug>

Order matters. Stop at the first failure.

1. **Final harvest.** Run `harvest` until there are no candidates left. Anything the operator defers goes to a written list in the handoff, not to silence.
2. **Recall baseline.** Run the retrieval eval gate on the general layer and record hit@5/MRR (e.g. `bash eval/check.sh` in the index repo).
3. **Dry run.** Run `shelfmark-purge <slug> --lexicon <root>/.client/lexicon.txt`. Show the counts: client files, residue paths, query-log rows, canary hits.
4. **Confirm (T3, destructive).** Show the dry-run output and the archive recipient, then ask the operator explicitly. Do not proceed without a yes in this turn.
5. **Purge.** Run `shelfmark-purge <slug> --apply --archive <age-recipient> --lexicon <lexicon>`. Exit 1 with `PARTIAL` means re-run the same command. It is idempotent, and the tombstone already blocks leaks.
6. **Config.** Remove the client from `sources.yaml` together with its globs and `repos:` entries, then rebuild the index. The build stops on orphans, and the tombstone skips the client's files.
7. **Verify.**
   - The purge printed `verified`.
   - The recall gate on the general layer shows no regression against step 2. On a regression, stop and find which general lesson depended on client context.
   - Grep the lexicon across the general vault: 0 hits outside notes whose origin is `client-<slug>` and that the operator approved.
8. **Surfaces the purge does not own.** List these for the operator to decide:
   - the client vault repo (it belongs to the client, archive or hand back)
   - session transcripts under the client's project dir
   - off-machine copies (remote index exports, backups on other hosts)
   - graph snapshots
   - file-system snapshots
9. **Record.** Add one line to the autonomy-gates log and a note in the handoff: client, date, archive path, counts, recall before/after.

## Stop conditions

- The client is not in the registry: the purge must run before the client is removed from config. Stop.
- The lexicon file is missing: ask the operator to write one (10 to 30 terms) before the offboard. Harvest can run without it, but the canary checks cannot.
- The recall gate regresses after the purge: stop and investigate. Do not re-add client data to fix the number.
- The operator did not confirm step 4: stop. A dry run is never approval.
