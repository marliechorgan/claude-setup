# Mechanical checks for dispatch and integration

`scripts/fanout-preflight.sh` measures a Git snapshot; `scripts/scope_check.py` checks a committed lane diff against its ownership row. Neither judges the product, takes a lease or authorizes publication.

The shell entrypoint uses an activated Python virtual environment, else `FANOUT_VENV`, the tree's `.venv` or `venv`, then `~/.venv` or `~/venv`. It needs only the standard library and Git. Activate it yourself for the scope checker and regression suite.

## Dispatch

```bash
bash scripts/fanout-preflight.sh "$TREE" \
  --test 'the exact baseline command' \
  --deployed "$DEPLOYED_SHA" \
  --targets src/ tests/ \
  --cite src/example.py:20-35
```

Run it in a clean worktree (temporary, if workers run that way) at the commit workers will get. Ignored config and external dependencies are not bound to the SHA, so the environment still matters. A dirty copy can be tested during development but is never reported as a clean committed baseline.

- **Nonzero baseline exit is a failed run**, including interruption, usage error and nothing collected. It runs under `bash -o pipefail`, so a failed command piped into a successful reader fails.
- **Exit 0 means the command completed**, not that assertions ran, enough tests were collected or the product passed. Read the retained log and record the asserted output separately. Text like `xfailed`, `0 failed` or a fixture containing `FAILED` does not decide the verdict.
- **Omitting `--test` or `--deployed` reports `NOT_MEASURED`**; a required check that could not run reports `UNKNOWN` and exits nonzero.
- **PR inventory is optional**: `UNAVAILABLE` when `gh` is missing or fails, so an auth failure never reads as "no open PRs". Success lists at most 20 PRs and says nothing about file overlap.
- **Targets** match tracked filenames in the pinned tree: exact files, directory prefixes, explicit globs. An ignored or untracked file is not evidence of a target in the pin.
- **Citations** print the pinned excerpt (bounded). That proves the lines exist, not that they implement the behaviour, execute or are reached on a flow; read callers and branch conditions for that.
- **HEAD and tracked/untracked cleanliness are rechecked after the baseline**; a command that changes the tree invalidates the snapshot. Changes made and fully restored mid-run are invisible to this before/after check, so keep ownership exclusive throughout.

## Close-out

Prefer an explicit run scope:

```bash
bash scripts/fanout-preflight.sh "$INTEGRATION_TREE" --closeout \
  --base "$INTEGRATION_REF" \
  --branches "$WORKER_ONE_REF" "$WORKER_TWO_REF" \
  --worktrees "$WORKER_ONE_TREE" "$WORKER_TWO_TREE"
```

Selected refs are pinned and checked as ancestors of the resolved integration ref. It checks the selected worktrees, any worktree on a selected branch and the integration tree, including each HEAD (covering detached workers). An unrelated path passed as a worktree fails.

Without `--branches` and `--worktrees` it inspects every local branch and registered worktree (the legacy inventory), usually too broad on long-lived repositories. A missing or moved worktree or a Git read failure is `UNKNOWN`, not clean. An unmerged unrelated branch can fail this even when the run is complete; select the run explicitly rather than ignoring the verdict.

```bash
bash scripts/fanout-preflight.sh "$TREE" --closeout --base "$REF" \
  --branches "$WORKER_REF" --allow-untracked uv.lock
```

`--allow-untracked` takes exact normalized repo-relative paths. It never exempts a tracked modification, does not match neighbouring names, and prints each exemption used. It applies to every inspected tree, so keep it narrow and never use it to hide worker output or source edits. Ignored files are outside Git status coverage; the script says so.

Refs and HEADs are rechecked at the end to catch a lane that advanced. Containment is a snapshot over the printed SHAs, not a lease: record acknowledged final tips, stop live writers through the lead's protocol, and rerun before claiming integration. Squash or cherry-pick equivalence is not ancestry; a distinct commit is never inferred as integrated.

## Ownership scope

```bash
python scripts/scope_check.py worker-one "$WORKER_REF" \
  --base "$PINNED_BASE" --map "$SCOPE_MAP"
```

`--base` and `--map` are required; there is no default pin or built-in map. `--pin` is accepted for compatibility but must resolve to the same commit as `--base`.

Run it from the worktree root; it rejects a subdirectory and disables relative-diff and submodule-ignore settings so local Git configuration cannot hide changes. Filenames go to Git literally, including brackets and leading pathspec syntax. Preflight also overrides submodule-ignore when checking for uncommitted changes.

The JSON map, with optional symbol regions:

```json
{
  "worker-one": [
    ["src/component.py", [{"symbol": "Component.execute"}]],
    ["tests/test_component.py", null]
  ],
  "worker-two": [
    ["src/other.py", null],
    ["tests/test_other*.py", null]
  ]
}
```

- **`null` owns the whole file**; explicit path globs match the finite changed-file inventory. Keeping ownership non-overlapping is the lead's job: this gate checks one lane's adherence, not competing claims.
- **Python symbol regions** resolve through the AST at both pinned versions (methods, nested definitions, decorators), so an added sibling function cannot slip past a one-sided line check. A removed or renamed symbol needs a new ownership decision.
- **Legacy `[start, "nextdef"]` regions** resolve to the enclosing symbol through the AST, both sides checked. **Legacy `[start, end]` regions** keep numeric base coordinates; an insertion on their boundary is `UNKNOWN`, since coordinates cannot establish ownership of new sibling code. Prefer symbols or whole files.
- **Renames need both old and new paths owned.** New or deleted files, type or mode changes and binary changes need whole-file ownership; a regional rule fails them as `UNKNOWN`.
- **Empty maps, empty lane rows, malformed regions, base/pin mismatch, missing files or symbols and unsupported observations fail** rather than pass as a no-op. A valid empty diff is labelled `NO_CHANGE`, which is not evidence of delivered work.
- **Scope sees committed changes only**; preflight exposes outstanding edits. A pass does not prove correctness, test quality or source safety; the integration owner still needs the diff and result evidence.

## Exit codes and the regression suite

| Tool | 0 | 1 | 2 |
|---|---|---|---|
| Preflight | Supplied executable checks passed (`NOT_MEASURED`, `UNAVAILABLE` stay visible) | A required check failed or was unknown | CLI or runtime usage errors may exit 2 |
| Scope | Covered, or a labelled valid `NO_CHANGE` | Out of scope | Unknown, unsupported or malformed |

Nonzero is never "probably noise" and zero is never product completion. Record check, input commits, exit and evidence separately.

Run `python scripts/test_fanout_gates.py` in an activated environment. It uses temporary Git repositories and local fixture commits: no pushes, no network. Fixtures cover silent failures, failed pipelines, unusable test exits, misleading summary prose, dirty/ignored/exempt files, unrelated and late branches, detached and missing worktrees, paths with spaces, citations, malformed maps, base mismatch, AST regions, renames, additions, deletions, and mode and binary changes.
