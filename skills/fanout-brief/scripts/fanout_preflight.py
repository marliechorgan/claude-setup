#!/usr/bin/env python3
"""Measure a dispatch snapshot or declared integration scope without classifying test prose."""
from __future__ import annotations

import argparse
import fnmatch
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys
import tempfile


class Unknown(RuntimeError):
    pass


def git(tree: Path, *args: str) -> bytes:
    result = subprocess.run(["git", "-C", str(tree), *args], capture_output=True)
    if result.returncode:
        raise Unknown(f"git {' '.join(args)} in {tree}: {os.fsdecode(result.stderr).strip()}")
    return result.stdout


def resolve(tree: Path, ref: str) -> str:
    return os.fsdecode(git(tree, "rev-parse", "--verify", "--end-of-options", f"{ref}^{{commit}}")).strip()


def worktrees(tree: Path) -> list[dict[str, str]]:
    records: list[dict[str, str]] = []
    current: dict[str, str] = {}
    for raw in git(tree, "worktree", "list", "--porcelain", "-z").split(b"\0"):
        if not raw:
            if current:
                records.append(current)
                current = {}
            continue
        key, _, value = os.fsdecode(raw).partition(" ")
        current[key] = value
    if current:
        records.append(current)
    return records


def dirty(tree: Path, allowed: set[str]) -> tuple[list[str], list[str]]:
    records = iter(git(tree, "status", "--porcelain=v1", "-z", "--untracked-files=all", "--ignore-submodules=none").split(b"\0"))
    changes, exceptions = [], []
    for raw in records:
        if not raw:
            continue
        code, path = os.fsdecode(raw[:2]), os.fsdecode(raw[3:])
        if code == "??" and path in allowed:
            exceptions.append(path)
        else:
            changes.append(f"{code} {path!r}")
        if "R" in code or "C" in code:
            if not next(records, None):
                raise Unknown("truncated rename/copy status record")
    return changes, exceptions


def ancestor(tree: Path, older: str, newer: str) -> bool:
    result = subprocess.run(["git", "-C", str(tree), "merge-base", "--is-ancestor", older, newer], capture_output=True)
    if result.returncode not in (0, 1):
        raise Unknown(f"ancestry unavailable: {os.fsdecode(result.stderr).strip()}")
    return result.returncode == 0


class Checks:
    def __init__(self) -> None:
        self.failed = False

    def emit(self, state: str, check: str, detail: str) -> None:
        print(f"{state:12} {check}: {detail}")
        if state in ("FAIL", "UNKNOWN"):
            self.failed = True

    def clean(self, tree: Path, allowed: set[str]) -> None:
        changes, exceptions = dirty(tree, allowed)
        if exceptions:
            self.emit("EXEMPT", "untracked", f"{tree}: exact declared paths {exceptions!r}")
        if changes:
            self.emit("FAIL", "dirty", f"{tree}: " + "; ".join(changes))
        else:
            self.emit("PASS", "clean", f"{tree}: no non-exempt tracked/untracked changes; ignored files are outside this check")


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("tree", type=Path)
    p.add_argument("--test", metavar="COMMAND")
    p.add_argument("--deployed", metavar="REF")
    p.add_argument("--targets", nargs="+", default=[])
    p.add_argument("--cite", action="append", default=[], metavar="FILE:LINE[-LINE]")
    p.add_argument("--closeout", action="store_true")
    p.add_argument("--base", default="main", metavar="REF")
    p.add_argument("--branches", nargs="+", default=[], metavar="REF")
    p.add_argument("--worktrees", nargs="+", type=Path, default=[], metavar="PATH")
    p.add_argument("--allow-untracked", nargs="+", default=[], metavar="EXACT_PATH")
    return p


def closeout(args: argparse.Namespace, checks: Checks, tree: Path, allowed: set[str]) -> None:
    if args.test or args.deployed or args.targets or args.cite:
        raise Unknown("dispatch arguments cannot be combined with --closeout; run them separately")
    base = resolve(tree, args.base)
    records = worktrees(tree)
    refs = list(dict.fromkeys(args.branches))
    selected = {tree, *(path.expanduser().resolve() for path in args.worktrees)}
    if args.branches or args.worktrees:
        full_refs = {os.fsdecode(git(tree, "rev-parse", "--symbolic-full-name", "--verify", "--end-of-options", ref)).strip() for ref in refs}
        selected.update(Path(record["worktree"]).resolve() for record in records if record.get("branch") in full_refs)
        checks.emit("SCOPE", "closeout", "declared refs/worktrees plus current tree; unrelated branches are excluded")
    else:
        refs = os.fsdecode(git(tree, "for-each-ref", "--format=%(refname)", "refs/heads/")).splitlines()
        selected.update(Path(record["worktree"]).resolve() for record in records)
        checks.emit("SCOPE", "closeout", "legacy repository-wide inventory: all local branches and registered worktrees")
    known = {Path(record["worktree"]).resolve() for record in records}
    if not selected <= known:
        raise Unknown(f"selected paths are not registered worktrees of this repository: {selected - known}")
    pins = {ref: resolve(tree, ref) for ref in refs}
    heads = {path: resolve(path, "HEAD") for path in sorted(selected)}
    checks.emit("PIN", "base", f"{args.base} = {base}")
    for ref, tip in pins.items():
        contained = ancestor(tree, tip, base)
        checks.emit("PASS" if contained else "FAIL", "containment", f"{ref} at {tip}; contained in {base}={contained}")
    for path, tip in heads.items():
        contained = ancestor(tree, tip, base)
        checks.emit("PASS" if contained else "FAIL", "worktree HEAD", f"{path} at {tip}; contained={contained}")
        checks.clean(path, allowed)
    if resolve(tree, args.base) != base:
        checks.emit("FAIL", "base drift", "base advanced during inspection; re-run")
    for ref, tip in pins.items():
        if resolve(tree, ref) != tip:
            checks.emit("FAIL", "tip drift", f"{ref} advanced during inspection; re-run")
    for path, tip in heads.items():
        if resolve(path, "HEAD") != tip:
            checks.emit("FAIL", "HEAD drift", f"{path} changed during inspection; re-run")
        changes, _ = dirty(path, allowed)
        if changes:
            checks.emit("FAIL", "final dirty", f"{path}: " + "; ".join(changes))
    print("SNAPSHOT     Containment applies to printed tips at inspection time; this does not acquire ownership or stop live writers.")


def citation(checks: Checks, tree: Path, sha: str, value: str) -> None:
    filename, separator, coordinates = value.rpartition(":")
    numbers = coordinates.split("-")
    if not separator or len(numbers) not in (1, 2):
        raise Unknown(f"citation needs FILE:LINE[-LINE]: {value!r}")
    start, end = int(numbers[0]), int(numbers[-1])
    if not (1 <= start <= end):
        raise Unknown(f"invalid citation bounds: {value!r}")
    lines = os.fsdecode(git(tree, "show", f"{sha}:{filename}")).splitlines()
    if end > len(lines) or not any(line.strip() for line in lines[start - 1:end]):
        checks.emit("FAIL", "citation", f"blank or out-of-bounds: {value!r}")
        return
    checks.emit("OBSERVED", "citation", f"{sha}:{value}; existence only: read excerpt and caller/flow before making a semantic claim")
    for index in range(start - 1, min(end, start + 39)):
        print(f"             {index + 1}: {lines[index]}")
    if end - start >= 40:
        print("             excerpt capped at 40 lines; open the remainder before citing it")


def dispatch(args: argparse.Namespace, checks: Checks, tree: Path, allowed: set[str]) -> None:
    if args.branches or args.worktrees:
        raise Unknown("--branches/--worktrees require --closeout")
    checks.clean(tree, allowed)
    sha = resolve(tree, "HEAD")
    checks.emit("PIN", "commit", sha)
    if checks.failed:
        print("NOT_RUN      baseline command: resolve dirty source before pinning a dispatch baseline")
        return
    records = worktrees(tree)
    primary = Path(records[0]["worktree"])
    if primary.resolve() != tree:
        missing = [name for name in (".env", ".env.local") if (primary / name).is_file() and not (tree / name).is_file()]
        if missing:
            checks.emit("UNAVAILABLE", "environment", f"gitignored files absent here: {missing}; do not claim live checks are available")
    if args.deployed:
        deployed = resolve(tree, args.deployed)
        contained = ancestor(tree, deployed, sha)
        checks.emit("PASS" if contained else "FAIL", "deployed ancestry", f"deployed={deployed}, contained in pin={contained}; false can mean behind or divergent")
    else:
        checks.emit("NOT_MEASURED", "deployed ancestry", "no --deployed supplied")
    tracked_paths = [os.fsdecode(value) for value in git(tree, "ls-tree", "-r", "--name-only", "-z", sha).split(b"\0") if value] if args.targets else []
    for target in args.targets:
        # Explicit target globs map to the pinned Git filename dataset, not source text.
        exists = any(path == target or path.startswith(target.rstrip("/") + "/") or fnmatch.fnmatchcase(path, target) for path in tracked_paths)
        checks.emit("PASS" if exists else "FAIL", "target", f"{target!r}: present in pinned tracked tree={exists}")
    for value in args.cite:
        citation(checks, tree, sha, value)
    if args.targets:
        if shutil.which("gh"):
            result = subprocess.run(["gh", "pr", "list", "--state", "open", "--json", "number,title", "--limit", "20"], cwd=tree, capture_output=True)
            if result.returncode:
                checks.emit("UNAVAILABLE", "open PRs", f"gh exited {result.returncode}; inspect separately before claiming no in-flight work")
            else:
                checks.emit("OBSERVED", "open PRs", os.fsdecode(result.stdout).strip() + " (first 20; file overlap unassessed)")
        else:
            checks.emit("UNAVAILABLE", "open PRs", "gh is not installed")
    else:
        checks.emit("NOT_MEASURED", "open PRs", "no targets supplied")
    if args.test:
        descriptor, log_path = tempfile.mkstemp(prefix="fanout-baseline-", suffix=".log")
        with os.fdopen(descriptor, "wb") as output:
            result = subprocess.run(["bash", "-o", "pipefail", "-c", args.test], cwd=tree, stdout=output, stderr=subprocess.STDOUT)
        checks.emit("PASS" if result.returncode == 0 else "FAIL", "baseline command", f"exit={result.returncode}; log={log_path}; command={args.test!r}")
        print("             Exit 0 means command completed; collection, assertions and product behavior require separate evidence.")
    else:
        checks.emit("NOT_MEASURED", "baseline", "no --test supplied")
    if resolve(tree, "HEAD") != sha:
        checks.emit("FAIL", "pin drift", "HEAD changed during checks; baseline cannot be bound to the original pin")
    changes, _ = dirty(tree, allowed)
    if changes:
        checks.emit("FAIL", "source drift", "tree changed during checks: " + "; ".join(changes))
    print(f"CONTEXT      verification_root={tree}\n             pinned_commit={sha}\n             authority=source and observed post-state outrank this brief")


def main() -> int:
    args = parser().parse_args()
    checks = Checks()
    try:
        if args.test is not None and not args.test.strip():
            raise Unknown("--test was supplied without a nonempty command")
        tree = args.tree.expanduser().resolve(strict=True)
        root = Path(os.fsdecode(git(tree, "rev-parse", "--show-toplevel")).removesuffix("\n")).resolve()
        if tree != root:
            raise Unknown(f"use the worktree root {root}, not subdirectory {tree}")
        allowed = set(args.allow_untracked)
        for value in allowed:
            parsed = PurePosixPath(value)
            if parsed.is_absolute() or ".." in parsed.parts or value != parsed.as_posix() or value in ("", "."):
                raise Unknown(f"--allow-untracked needs an exact normalized repo-relative path: {value!r}")
        if args.closeout:
            closeout(args, checks, tree, allowed)
        else:
            dispatch(args, checks, tree, allowed)
    except (Unknown, OSError, ValueError) as error:
        checks.emit("UNKNOWN", "inspection", str(error))
    print("CHECKS FAILED" if checks.failed else "CHECKS PASSED — only supplied checks; NOT_MEASURED/UNAVAILABLE remain unresolved.")
    return 1 if checks.failed else 0


if __name__ == "__main__":
    sys.exit(main())
