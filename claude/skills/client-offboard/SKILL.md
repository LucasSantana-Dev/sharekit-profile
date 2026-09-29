---
name: client-offboard
description: Scaffold, maintain, and retire a client engagement's memory boundary. Modes - init SLUG (scaffold a new client's registry entry, vault and gate wiring), harvest (batch-promote pending lessons to general memory), promote-now NOTE (one lesson), offboard SLUG (final harvest, purge, verification). Use for "new client", "onboard client", "offboard client", "trocar de cliente", "encerrar cliente", "harvest lessons", "purge client", or at session close in a client repo.
argument-hint: "init <slug> | harvest | promote-now <note> | offboard <slug>"
triggers:
  - offboard client
  - trocar de cliente
  - encerrar cliente
  - harvest lessons
  - promote-now
  - purge client
  - init client
  - onboard client
  - new client
  - scaffold client
---

# client-offboard

Two invariants, in this order:

1. **Learning is never lost.** Technical and behavioral lessons survive every purge. When in doubt, keep and ask. Never delete.
2. **One client's business never reaches another.** Domain rules, org hierarchy, people, numbers, confidential facts: none of it goes to general memory. Not even inside a "generalized" lesson.

## Where things live

| What | Where |
|---|---|
| Clients | shelfmark registry, lookup order: `$SHELFMARK_CLIENTS` env var first, else `${RAG_HOME:-~/.shelfmark}/clients.json`, as `{slug: {db, roots}}`. Example: [`examples/clients.json.example`](examples/clients.json.example) |
| Active client | the client whose `roots` contain the session's cwd, detected automatically; no env var needed for work done inside a client root. `RAG_CLIENT=<slug>` is only for work done from outside every root (a generic parent folder, a tools repo); `RAG_CLIENT=none` turns client rules off |
| Client vault | any `.md` note under the client's roots. It does not need to live in a directory literally named `memory/` (a registry `roots` entry is what makes it the vault, not the folder name) |
| General vault | the operator's cross-project memory dir (ask once if unclear) |
| Lexicon | `<root>/.client/lexicon.txt`: names, people, acronyms, IDs, one per line |
| Origin id | `<root>/.client/origin-id`: 8 random hex chars, made once (`openssl rand -hex 4`). General notes carry this, never the slug |
| Manifest | `<root>/.client/harvest-manifest.jsonl`: one line per promoted lesson. It lives in the client vault, so the link from a lesson back to the client leaves with the client |
| Review queue | `<root>/.client/review-queue.jsonl` (or `$MEMORY_REVIEW_QUEUE`): the memory gate's lexicon hits |
| Purge tooling | the `shelfmark` CLI (`shelfmark-purge`, `shelfmark build`), separate from the gate. The gate only reads `clients.json`; only `offboard` needs the CLI installed |

**Candidates are derived, never flagged.** A candidate is a client-vault note of type `feedback`, `gotcha` or `finding` whose path is not in the manifest yet, plus every review-queue entry for that client.

## Mode: init <slug>

Scaffold a new client before any session works inside its root. Ask for the client's absolute repo root if it was not given.

1. **Registry.** Add the client to `clients.json`, creating the file first if it does not exist yet:
   ```bash
   RAG_HOME="${RAG_HOME:-$HOME/.shelfmark}"
   CLIENTS="${SHELFMARK_CLIENTS:-$RAG_HOME/clients.json}"
   mkdir -p "$(dirname "$CLIENTS")"
   [ -f "$CLIENTS" ] || echo '{}' > "$CLIENTS"
   jq --arg s "<slug>" --arg r "<absolute-root>" --arg db "$RAG_HOME/<slug>.db" \
     '.[$s] //= {db: $db, roots: [$r]}' "$CLIENTS" > "$CLIENTS.tmp" && mv "$CLIENTS.tmp" "$CLIENTS"
   ```
   `//=` only adds the entry when the slug is new, so a re-run never drops roots added by hand. For more than one root, add the extra absolute paths to the `roots` array by hand. See [`examples/clients.json.example`](examples/clients.json.example) for the shape. `clients.json` is private: it never ships with this profile, is never synced or published, and stays out of any repo it happens to sit in (see `.gitignore`).
2. **Client dir.** Create `<root>/.client/`, keeping any file already there: the operator may have written the lexicon before running init, and a new origin id would orphan every lesson already promoted under the old one.
   ```bash
   mkdir -p "<root>/.client"
   [ -e "<root>/.client/lexicon.txt" ] || : > "<root>/.client/lexicon.txt"   # fill with 10-30 names/acronyms/IDs before offboard, one per line
   [ -s "<root>/.client/origin-id" ] || openssl rand -hex 4 > "<root>/.client/origin-id"
   ```
3. **Vault.** Create the client's own memory directory inside its own repo, e.g. `mkdir -p "<root>/memory"`. Any directory name works (see "Client vault" above); this is where ordinary session memory writes for this client are meant to land.
4. **Symlink into Claude Code's per-project memory.** Claude Code keys a project's local state by its absolute path with every character that is not a letter or digit replaced by `-` (each separator becomes its own hyphen, so a path segment like `/.git` produces a double hyphen, not one). Verify this against a real entry before relying on it: `ls ~/.claude/projects/`. Then symlink that project's `memory/` to the vault you just created, guarded: on macOS, `ln -s` against an existing `memory/` directory exits 0 and silently nests the link inside it instead of replacing it, so nothing is lost but the redirect never happens and the step looks like it worked when it did not.
   ```bash
   ENCODED="$(printf '%s' "<root>" | sed -E 's/[^A-Za-z0-9]/-/g')"
   mkdir -p ~/.claude/projects/"$ENCODED"
   LINK=~/.claude/projects/"$ENCODED"/memory
   TARGET="<root>/memory"
   if [ -L "$LINK" ] && [ "$(readlink "$LINK")" = "$TARGET" ]; then
     echo "already done - skipping"
   elif [ -e "$LINK" ]; then
     echo "REFUSED: $LINK already exists and is not this vault's symlink."
     echo "Move its notes into $TARGET by hand, remove $LINK, then retry."
     exit 1
   else
     ln -s "$TARGET" "$LINK"
   fi
   ```
   Verify the link actually points where it should:
   ```bash
   readlink ~/.claude/projects/"$ENCODED"/memory   # expect: <root>/memory
   ```
   This symlink is the whole mechanism keeping a session opened in `<root>` writing its ordinary memory into the client's own vault instead of the operator's general one.
5. **Tooling check.** The registry and the gate need nothing beyond `jq`. Purging later needs the `shelfmark-rag` CLI (>= 1.1.0, the first release with client layers and `shelfmark-purge`) on `PATH`:
   ```bash
   command -v shelfmark-purge >/dev/null 2>&1 || {
     echo "shelfmark-purge not found. Install or upgrade shelfmark-rag (needs >= 1.1.0 for client support):"
     echo "  pipx install shelfmark-rag"
     echo "  pipx upgrade shelfmark-rag   # if already installed on an older version"
   }
   ```
6. **Verify with a gate dry-run.** From inside `<root>`, confirm the gate now recognizes the client without writing anything real:
   ```bash
   cd "<root>"
   printf '{"tool_name":"Write","tool_input":{"file_path":"%s/memory/smoke-test.md","content":"smoke test"}}' "<root>" \
     | bash ~/.claude/hooks/memory-scope-gate.sh; echo "exit=$?"
   rm -f "<root>/memory/smoke-test.md"
   ```
   Exit 0 with an `allow scope=` line on stderr means the vault write is recognized; the smoke-test file above is never meant to persist.
7. **Report.** Slug, root, vault path, and whether `shelfmark-purge` is installed.

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
   - Write the note to the general vault with frontmatter `knowledge: technical` or `knowledge: behavioral`, plus `origin: <origin id>`. The memory gate requires the tag while a client is active. Never put the slug or the client's name in a general note.
   - Append a line to the manifest (in the client vault): `{ts, origin, source, target, sha256 of target}`.
   - Leave the original untouched in the client vault.
7. Report: N promoted, M kept client-only, K rejected by the test.

## Mode: promote-now <note>

The same steps 2 to 6, for a single note, right when the operator recognizes a lesson. Keep it cheap: one draft, one test, one approval.

## Mode: offboard <slug>

Order matters. Stop at the first failure.

1. **Final harvest.** Run `harvest` until there are no candidates left. Deferred candidates must survive the vault leaving: put their files in an encrypted archive, `tar czf - <files> | age -r <recipient> > "$RAG_HOME/archive/client-<slug>-deferred-$(date +%F).tar.gz.age"`, and write only the count and the archive path in the handoff (never titles, they carry client business).
2. **Recall baseline.** Run the retrieval eval gate on the general layer and record hit@5/MRR (e.g. `bash eval/check.sh` in the index repo).
3. **Dry run.** Run `shelfmark-purge <slug> --lexicon <root>/.client/lexicon.txt`. Show the counts: client files, residue paths, query-log rows, canary hits.
4. **Confirm (T3, destructive).** Show the dry-run output and the archive recipient, then ask the operator explicitly. Do not proceed without a yes in this turn.
5. **Purge.** Run `shelfmark-purge <slug> --apply --archive <age-recipient> --lexicon <lexicon>`. Exit 1 with `PARTIAL` means re-run the same command until it exits 0: every step is idempotent, and the tombstone (written before the first deletion) already keeps the client's files out of the general index. Do not go to step 6 until the purge printed `verified` and `$RAG_HOME/index.client-<slug>.purged` exists.
6. **Config.** Remove the client from `sources.yaml` together with its globs and `repos:` entries, then rebuild the index. The build stops on orphans, and the tombstone skips the client's files.
7. **Verify.**
   - The purge printed `verified`.
   - The recall gate on the general layer shows no regression against step 2. On a regression, stop and find which general lesson depended on client context.
   - Grep the lexicon across the general vault: 0 hits, no exceptions. A hit in a promoted lesson means the lesson still carries client business: rewrite it before closing.
8. **Surfaces the purge does not own.** List these for the operator to decide:
   - the client vault repo (it belongs to the client, archive or hand back). Its `.client/` dir holds the manifest, the review queue and the origin id, and leaves with it
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
