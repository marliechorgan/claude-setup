# Mechanical checks for dispatch and integration

`scripts/fanout-preflight.sh` measures a Git snapshot. `scripts/scope_check.py` checks a committed lane diff against its ownership row. Neither decides whether the product works, acquires a coordinator lease, or authorizes publication.

The shell entrypoint uses an activated Python virtual environment. Otherwise it checks `FANOUT_VENV`, the supplied tree's `.venv` or `venv`, then `~/.venv` or `~/venv`. It requires only Python's standard library and Git. Activate the environment explicitly before running the Python scope checker or regression suite.

## Dispatch

```bash
bash scripts/fanout-preflight.sh "$TREE" \
  --test 'the exact baseline command' \
  --deployed "$DEPLOYED_SHA" \
  --targets src/ tests/ \
  --cite src/example.py:20-35
```

Use a clean worktree rooted at the same pinned commit that workers will receive. Baseline environment differences still matter: an ignored configuration file or external dependency is not bound to the Git SHA. Use a temporary worktree when that is how the workers will execute. A dirty working candidate can be tested during development, but it cannot be represented as a clean committed dispatch baseline by this script.

- Nonzero baseline exit is a failed execution, including interruption, usage error and no collection. The command runs under `bash -o pipefail`, so a failed command piped into a successful reader fails too.
- Exit 0 means the supplied command completed. It does not prove that any assertions ran, that a sufficient test set was collected, or that the product passed. Read the full retained log and record the asserted output separately. Text such as `xfailed`, `0 failed`, or a fixture containing `FAILED` does not determine the verdict.
- Omitting `--test` reports `NOT_MEASURED`. Omitting the deployed ref also reports `NOT_MEASURED`. Required checks that could not execute report `UNKNOWN` and exit nonzero.
- Optional PR inventory reports `UNAVAILABLE` when `gh` is missing or fails; it does not turn an authentication failure into “no open PRs.” Successful inventory shows at most 20 PRs and does not establish file overlap.
- Targets are checked against tracked filenames in the pinned tree. Exact files, directory prefixes and explicit globs over this static filename inventory are supported. An ignored/untracked file is not evidence of a target in the pin.
- Citations display the pinned excerpt with bounded output. This proves the lines exist, not that they implement the behavior, are executable code, or are reached on a particular flow. Read the callers and branch conditions for those claims.
- HEAD and tracked/untracked cleanliness are checked again after the baseline. A command that changes the tree invalidates the snapshot claim. This is a before/after check; it cannot detect transient changes made and fully restored while the command runs. Keep ownership exclusive throughout the run.

## Close-out

Prefer explicit run scope:

```bash
bash scripts/fanout-preflight.sh "$INTEGRATION_TREE" --closeout \
  --base "$INTEGRATION_REF" \
  --branches "$WORKER_ONE_REF" "$WORKER_TWO_REF" \
  --worktrees "$WORKER_ONE_TREE" "$WORKER_TWO_TREE"
```

Selected refs are pinned and checked as ancestors of the resolved integration ref. The script checks selected worktrees, worktrees checked out on the selected branch refs, and the current integration tree. It also checks the HEAD of every included worktree, covering detached workers. An unrelated path supplied as a worktree fails.

Without `--branches` and `--worktrees`, legacy repository-wide inventory is retained: every local branch and every registered worktree is inspected. This is often too broad on long-lived repositories. A missing/moved worktree or Git read failure is `UNKNOWN`, not clean. An unmerged unrelated branch can make this broad inventory fail while a specific run is complete; select the actual run explicitly instead of ignoring the verdict.

```bash
bash scripts/fanout-preflight.sh "$TREE" --closeout --base "$REF" \
  --branches "$WORKER_REF" --allow-untracked uv.lock
```

`--allow-untracked` accepts exact normalized repo-relative paths only. It never exempts a tracked modification, does not match neighboring names, and prints every exemption that was used. This exception applies to all inspected trees, so keep it narrow. Ignored files are outside Git status coverage; the script says so. Do not use exceptions to hide worker output or source edits.

Refs and HEADs are rechecked at the end to catch a lane that advanced during inspection. Containment is a snapshot over printed SHAs, not a lease. Capture acknowledged final worker tips in the run record, stop live writers through the coordinator protocol, and run the check again before claiming integration. Squash/cherry-pick equivalence is not ancestry; this script will not infer that a distinct commit was integrated.

## Ownership scope

```bash
python scripts/scope_check.py worker-one "$WORKER_REF" \
  --base "$PINNED_BASE" --map "$SCOPE_MAP"
```

Both `--base` and `--map` are mandatory; there is no default pin or built-in lane map. For compatibility, `--pin` is also accepted, but it must resolve to the same commit as `--base`.

Run from the worktree root. The checker rejects a subdirectory invocation and disables relative-diff/submodule-ignore settings so local Git configuration cannot silently hide changes. Actual filenames are passed to Git literally, including bracket characters and names beginning with Git pathspec syntax. Preflight also overrides submodule-ignore settings when checking dirt.

The JSON map shape is unchanged, with optional symbol regions:

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

- `null` owns the whole file. Explicit path globs match the finite changed-file inventory. The coordinator must still ensure the map assigns non-overlapping ownership; this gate checks one lane's adherence and does not arbitrate competing claims.
- Python symbol regions are resolved with the AST at both pinned versions, including methods, nested definitions and decorators. This prevents an added sibling function from slipping through a one-sided old-line check. Removed/renamed symbols require a new explicit ownership decision.
- Legacy `[start, "nextdef"]` regions resolve to the enclosing Python symbol through the AST, with both sides checked. Legacy `[start, end]` regions retain numeric base coordinates; insertions directly on their boundary are `UNKNOWN` because those coordinates cannot establish ownership of new sibling code. Prefer symbols or whole-file ownership.
- Renames require ownership of both old and new paths. New/deleted files, type/mode changes and binary changes require whole-file ownership. A regional rule cannot establish their scope, so it fails as `UNKNOWN`.
- Empty maps, empty lane rows, malformed regions, base/pin mismatch, missing files/symbols and unsupported observations fail before they can produce a passing no-op. A valid empty diff is labeled `NO_CHANGE`, which is not evidence of delivered work.
- Scope examines committed changes only. Use preflight to expose outstanding edits. A scope pass does not prove correctness, test quality or source safety; the integration owner still needs the diff and relevant result evidence.

## Exit contract and regression checks

Preflight: `0` means supplied executable checks passed; unresolved `NOT_MEASURED` and optional `UNAVAILABLE` observations remain visible. `1` means a required check failed or was unknown. CLI/runtime usage errors may return `2`. Scope: `0` means covered (or a labeled valid no-change), `1` means out of scope, `2` means unknown/unsupported/malformed.

Never convert “nonzero” into “probably noise,” or “zero” into product completion. Record the check, input commits, actual exit and evidence separately.

Run `python scripts/test_fanout_gates.py` in an activated environment. It uses temporary Git repositories only, with local fixture commits and no pushes or network dependency. Fixtures exercise silent failures, failed pipelines, unusable test exits, misleading summary prose, dirty/ignored/exempt files, unrelated/late branches, detached/missing worktrees, paths with spaces, citations, malformed maps, base mismatch, AST regions, renames, additions, deletions, mode and binary changes.
