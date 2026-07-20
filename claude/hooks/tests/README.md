# Hook tests

Regression tests for the security-critical PreToolUse blocking hooks. They feed
**real JSON envelopes** to the actual hook scripts and assert the exit code
(`0` = allow, `2` = block) — so they exercise the real artifact end-to-end
(stdin parse + matching logic) and can't drift from a copied-out regex.

## Run

```bash
bash hooks/tests/run-tests.sh
```

Exit non-zero if any case fails. Wire into CI and/or a pre-push guard so a future
edit to `block-secret-reads.sh` or `protect-files.sh` can't silently break
credential blocking (the failure mode that motivated the 2026-05-31 secret-leak
hook in the first place).

## Coverage

| Test | Hook | Cases |
|------|------|-------|
| `test-block-secret-reads.sh` | `block-secret-reads.sh` | cloud creds (AWS/GCP/kube/docker), shell rc, `.env`, keys, npm/netrc; via `file_path`/`command`/`pattern`; safe-template + false-positive ALLOWs |
| `test-protect-files.sh` | `protect-files.sh` | `.env`/`.ssh`/`.aws`/`.git`/keys/`claude-mem.db` BLOCK; `.example`/`.sample`/`.template`/normal ALLOW |

## Adding a hook

If you add another blocking hook, add a `test-<name>.sh` here following the same
pattern: define an envelope helper, a `check desc expected_exit json` assertion,
and `[ "$fail" -eq 0 ]` as the last line. `run-tests.sh` auto-discovers `test-*.sh`.

> Note: `block-secret-reads.sh` scans the **Bash tool's command text**, so running
> these tests inline (`printf '...secret-path...' | hook`) from a Bash *tool call*
> would trip the live hook. Always run them via `bash run-tests.sh` — the runner's
> invocation carries no secret literals; fixtures reach the hook only over the
> test subprocess's stdin.
