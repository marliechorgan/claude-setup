#!/usr/bin/env python3
"""Check committed lane changes against an explicit ownership map and immutable base.

Usage: scope_check.py LANE REF --base REF --map scope.json [--pin REF]
Map: {"lane": [["path-or-glob", null], ["file.py", [{"symbol": "Class.method"}]]]}.
Legacy regions [start, end] and [start, "nextdef"] remain supported. See preflight.md.
"""
from __future__ import annotations

import argparse
import ast
import fnmatch
import json
import os
from pathlib import Path, PurePosixPath
import subprocess
import sys


class Unknown(RuntimeError):
    pass


def git(*args: str) -> bytes:
    result = subprocess.run(["git", "--literal-pathspecs", *args], capture_output=True)
    if result.returncode:
        raise Unknown(f"git {' '.join(args)}: {os.fsdecode(result.stderr).strip()}")
    return result.stdout


def pin(ref: str) -> str:
    return os.fsdecode(git("rev-parse", "--verify", "--end-of-options", f"{ref}^{{commit}}")).strip()


def validate_map(raw: object, lane: str) -> list:
    if not isinstance(raw, dict) or not raw or lane not in raw:
        raise Unknown("map must be a nonempty object containing the requested lane")
    for name, rows in raw.items():
        if not isinstance(name, str) or not isinstance(rows, list) or not rows:
            raise Unknown(f"lane {name!r} needs at least one explicit ownership row")
        for row in rows:
            if not isinstance(row, list) or len(row) != 2 or not isinstance(row[0], str) or not row[0]:
                raise Unknown(f"malformed ownership row in {name!r}: {row!r}")
            path, regions = row
            if PurePosixPath(path).is_absolute() or ".." in PurePosixPath(path).parts:
                raise Unknown(f"ownership paths must be repo-relative: {path!r}")
            if regions is None:
                continue
            if not isinstance(regions, list) or not regions:
                raise Unknown(f"regions must be null or a nonempty list: {row!r}")
            for region in regions:
                if isinstance(region, dict) and set(region) == {"symbol"} and isinstance(region["symbol"], str) and region["symbol"]:
                    continue
                if isinstance(region, list) and len(region) == 2 and type(region[0]) is int and region[0] >= 1:
                    if region[1] == "nextdef" or (type(region[1]) is int and region[1] >= region[0]):
                        continue
                raise Unknown(f"unsupported region: {region!r}")
    return raw[lane]


def symbols(source: bytes) -> dict[str, tuple[int, int]]:
    try:
        tree = ast.parse(source)
    except (SyntaxError, ValueError) as error:
        raise Unknown(f"cannot resolve Python symbol regions: {error}") from error
    found: dict[str, tuple[int, int]] = {}

    def visit(node: ast.AST, parent: str) -> None:
        for child in ast.iter_child_nodes(node):
            if isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
                name = parent + child.name
                if name in found:
                    raise Unknown(f"ambiguous Python symbol: {name}")
                first = min([child.lineno, *(decorator.lineno for decorator in child.decorator_list)])
                found[name] = (first, child.end_lineno)
                visit(child, name + ".")
            else:
                visit(child, parent)

    visit(tree, "")
    return found


def range_for(region: object, source: bytes, path: str) -> tuple[int, int, str | None]:
    if isinstance(region, dict):
        if not path.endswith(".py"):
            raise Unknown("symbol regions currently require a Python file; own other file types whole")
        name = region["symbol"]
        table = symbols(source)
        if name not in table:
            raise Unknown(f"symbol {name!r} absent from {path}")
        return (*table[name], name)
    start, end = region
    if end == "nextdef":
        if not path.endswith(".py"):
            raise Unknown("nextdef currently requires Python AST; own other file types whole")
        candidates = [(name, bounds) for name, bounds in symbols(source).items() if bounds[0] <= start <= bounds[1]]
        if not candidates:
            raise Unknown(f"no Python symbol contains start {start} in {path}")
        name, bounds = min(candidates, key=lambda item: item[1][1] - item[1][0])
        return (*bounds, name)
    if end > len(source.splitlines()):
        raise Unknown(f"numeric region exceeds base file length: {path}:{start}-{end}")
    return start, end, None


def validate_regions(rows: list, base: str) -> None:
    paths = [os.fsdecode(value) for value in git("ls-tree", "-r", "--name-only", "-z", base).split(b"\0") if value]
    for pattern, regions in rows:
        if regions is None:
            continue  # Whole-file scope may intentionally authorize a new file.
        matched = [path for path in paths if path == pattern or fnmatch.fnmatchcase(path, pattern)]
        if not matched:
            raise Unknown(f"regional scope matches no file in pinned base: {pattern!r}")
        for path in matched:
            source = git("show", f"{base}:{path}")
            for region in regions:
                range_for(region, source, path)


def file_changes(base: str, tip: str) -> list[tuple[str, str, str, str, str]]:
    records = iter(git("diff", "--raw", "-z", "--no-abbrev", "--find-renames", "--no-relative", "--no-color", "--no-ext-diff", "--ignore-submodules=none", base, tip, "--").split(b"\0"))
    changes = []
    for record in records:
        if not record:
            continue
        fields = os.fsdecode(record).split()
        if len(fields) != 5 or not fields[0].startswith(":"):
            raise Unknown("unrecognized git raw diff record")
        old_mode, new_mode, _, _, status = fields
        old_path = os.fsdecode(next(records))
        new_path = os.fsdecode(next(records)) if status[0] in ("R", "C") else old_path
        changes.append((old_mode[1:], new_mode, status[0], old_path, new_path))
    return changes


def matching(rows: list, path: str) -> list:
    # Explicit map globs select a finite Git changed-path dataset, never source semantics.
    return [regions for pattern, regions in rows if path == pattern or fnmatch.fnmatchcase(path, pattern)]


def hunks(base: str, tip: str, path: str) -> list[tuple[int, int, int, int]]:
    output = git("diff", "--no-ext-diff", "--no-textconv", "--no-color", "--no-relative", "--ignore-submodules=none", "--unified=0", base, tip, "--", path)
    result = []
    for line in output.splitlines():
        if not line.startswith(b"@@ "):
            continue
        parts = line.split(b" ", 4)
        if len(parts) < 4 or parts[3] != b"@@":
            raise Unknown("unrecognized git hunk header")
        old = parts[1][1:].split(b",")
        new = parts[2][1:].split(b",")
        result.append((int(old[0]), int(old[1]) if len(old) == 2 else 1,
                       int(new[0]), int(new[1]) if len(new) == 2 else 1))
    if not result:
        raise Unknown(f"no text hunks for region-owned change {path}; binary/metadata changes need whole-file ownership")
    return result


def within(start: int, count: int, bounds: tuple[int, int]) -> bool:
    lo, hi = bounds
    # An insertion anchored immediately outside a region is not owned by that region.
    return lo <= start and start + max(count, 1) - 1 <= hi


def check_file(rows: list, change: tuple, base: str, tip: str) -> bool:
    old_mode, new_mode, status, old_path, new_path = change
    old_rules, new_rules = matching(rows, old_path), matching(rows, new_path)
    if not old_rules or not new_rules:
        print(f"OUT {old_path!r} -> {new_path!r}: every changed source/destination path needs an owner")
        return False
    if any(rule is None for rule in old_rules) and any(rule is None for rule in new_rules):
        print(f"OK {old_path!r} -> {new_path!r}: whole-file ownership ({status}, {old_mode}->{new_mode})")
        return True
    if status != "M" or old_path != new_path or old_mode != new_mode or old_mode not in ("100644", "100755"):
        raise Unknown(f"{old_path}: additions/deletions/renames/type/mode changes require whole-file ownership")
    old_source, new_source = git("show", f"{base}:{old_path}"), git("show", f"{tip}:{new_path}")
    rules = [region for group in old_rules for region in group]
    allowed = [range_for(region, old_source, old_path) for region in rules]
    new_symbols = symbols(new_source) if any(name is not None for _, _, name in allowed) else {}
    passed = True
    for old_start, old_count, new_start, new_count in hunks(base, tip, old_path):
        covered = False
        for lo, hi, name in allowed:
            if not within(old_start, old_count, (lo, hi)):
                continue
            if name is not None:
                if name not in new_symbols:
                    raise Unknown(f"owned symbol {name!r} removed/renamed; explicitly authorize a whole-file change")
                if not within(new_start, new_count, new_symbols[name]):
                    continue
            elif old_count == 0 and old_start in (lo, hi):
                raise Unknown(f"insertion on numeric region boundary in {old_path}; use a symbol or whole-file scope")
            covered = True
            break
        print(f"{'OK' if covered else 'OUT'} {old_path!r}: old {old_start}+{old_count}, new {new_start}+{new_count}")
        passed = passed and covered
    return passed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("lane")
    parser.add_argument("branch")
    parser.add_argument("--base", required=True)
    parser.add_argument("--map", required=True)
    parser.add_argument("--pin", help="legacy alias check: must resolve to the same commit as --base")
    args = parser.parse_args()
    try:
        root = Path(os.fsdecode(git("rev-parse", "--show-toplevel")).removesuffix("\n")).resolve()
        if Path.cwd().resolve() != root:
            raise Unknown(f"run from the worktree root {root}; a subdirectory diff cannot establish complete scope")
        with open(args.map, encoding="utf-8") as handle:
            rows = validate_map(json.load(handle), args.lane)
        base, tip = pin(args.base), pin(args.branch)
        if args.pin and pin(args.pin) != base:
            raise Unknown("--pin and --base differ; region coordinates must use the actual diff base")
        validate_regions(rows, base)
        print(f"PIN base={base} tip={tip}; committed diff only, uncommitted changes require preflight")
        changes = file_changes(base, tip)
        if not changes:
            print(f"NO_CHANGE {args.lane}: no committed changes; this is not evidence that work was delivered")
        passed = True
        for change in changes:
            passed = check_file(rows, change, base, tip) and passed
        if pin(args.base) != base or pin(args.branch) != tip:
            raise Unknown("base or lane tip changed during inspection; re-run")
        print(f"VERDICT {args.lane}: {'OK' if passed else 'OUT'}")
        return 0 if passed else 1
    except (Unknown, OSError, ValueError, TypeError, StopIteration) as error:
        print(f"UNKNOWN {args.lane}: {error}")
        return 2


if __name__ == "__main__":
    sys.exit(main())
