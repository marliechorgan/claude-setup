#!/usr/bin/env python3
"""consumers: list what a change's contract touches and the places in the repo that read it.

  consumers.py [--base REF] [--repo DIR] [--max N]

Run it before calling a change ready. It reads the diff from REF (default: the merge base with
origin/main, else main) to the working tree, pulls out what other code depends on, and greps the
rest of the repo for each one:

  file      each MODIFIED file's name: who runs, sources, imports, mirrors or deploys it
  function  functions whose definition or body changed in a modified file (code readers only)
  flag      long options (--name) on changed lines
  exit      exit codes added or removed (exit N, sys.exit(N)); readers are lines that test that code
  env       environment variables on changed lines
  field     "key:" fields written by echo/printf/print on changed lines (card and log formats)

Readers that look like invocations in code come first, and a reader that throws away the status or
the output (`|| true`, `>/dev/null`, `2>&1 ||`) is marked [DISCARDS STATUS]: a new refusal, exit code
or message is lost there without a trace. A token with no readers outside the change is printed too,
so silence is visible. It lists candidates, not verdicts: open each reader and run its real input
through the new code.
Exit 0 after printing; 2 when DIR is not a git repository or REF does not resolve.
Standard library only, python 3.9+.

Why a script: of 471 blocking findings an independent reviewer raised on 201 machine-written PRs
(Oct 2026), one in eight was an existing caller or consumer on main that the change broke and
nobody opened, often one that discarded the new error. The author had grep; the step was skipped.
"""
import argparse
import re
import subprocess
import sys

FUNC = [re.compile(r"^\s*def\s+([A-Za-z_]\w*)\s*\("),
        re.compile(r"^\s*(?:function\s+)?([A-Za-z_][\w-]*)\s*\(\)\s*\{")]
FLAG = re.compile(r"(?<![\w-])(--[a-z][a-z0-9-]{2,})")
EXIT = re.compile(r"\b(?:exit|sys\.exit\()\s*(\d{1,3})\b")
ENV = re.compile(r"\$\{?([A-Z][A-Z0-9_]{3,})\b|environ(?:\.get)?\(?\[?[\"']([A-Z][A-Z0-9_]{3,})[\"']")
FIELD = re.compile(r"(?:echo|printf|print|write)\b[^\n]*?[\"'](?:\\n)?([a-z][a-z0-9_]{2,}):\s")
DISCARD = re.compile(r"\|\|\s*(true|:)(\s|;|$)|&>\s*/dev/null|>\s*/dev/null\s+2>&1|2>&1\s*>\s*/dev/null|check=False"
                     r"|except(\s+Exception)?\s*:\s*pass")
CODE_EXT = (".sh", ".bash", ".zsh", ".py", ".js", ".ts", ".mjs", ".rb", ".go", ".rs", ".pl", ".php", ".java", ".kt")
SKIP_ENV = {"HOME", "PATH", "USER", "TMPDIR", "SHELL", "PWD", "LANG", "TERM"}
SKIP_FLAGS = {"--help", "--version", "--quiet", "--verbose", "--json", "--force"}
COMMON = 300   # a function name with more references than this is a common word, not a contract


def git(repo, *args):
    p = subprocess.run(["git", "-C", repo] + list(args), capture_output=True, text=True)
    return p.returncode, p.stdout


def base_ref(repo, want):
    if want:
        rc, out = git(repo, "rev-parse", "--verify", want + "^{commit}")
        return out.strip() if rc == 0 else None
    for cand in ("origin/main", "main", "origin/master", "master"):
        rc, out = git(repo, "merge-base", "HEAD", cand)
        if rc == 0 and out.strip():
            return out.strip()
    return None


def is_code(path):
    name = path.rsplit("/", 1)[-1]
    return path.endswith(CODE_EXT) or ("." not in name and name.upper() != name)   # extensionless scripts, not README


def is_test(path):
    name = path.rsplit("/", 1)[-1]
    return ".test." in name or name.startswith("test_") or "/tests/" in path or name.endswith("_test.py")


def changed(repo, base):
    """(modified, added, [(file, sign, text)]) for base..working tree; untracked files count as added.
    sign is '+' or '-' for a changed line, '@' for git's enclosing-function line of a hunk."""
    _, st = git(repo, "diff", "--name-status", base)
    modified, added = [], []
    for ln in st.splitlines():
        parts = ln.split("\t")
        if len(parts) >= 2:
            (added if parts[0].startswith("A") else modified).append(parts[-1])
    _, untracked = git(repo, "ls-files", "--others", "--exclude-standard")
    added += [f for f in untracked.splitlines() if f]
    _, diff = git(repo, "diff", "-U0", base)
    lines, cur = [], None
    for ln in diff.splitlines():
        if ln.startswith("+++ "):
            cur = ln[6:] if ln.startswith("+++ b/") else None
        elif cur and ln.startswith("@@"):
            m = re.match(r"@@ -\S+ \+(\d+)(?:,(\d+))? @@", ln)
            if m:
                start, n = int(m.group(1)), int(m.group(2) or 1)
                lines.extend((cur, "#", str(k)) for k in range(start, start + n))   # changed line numbers
            ctx = ln.split("@@", 2)[-1].strip()   # the body changed, the name did not
            if ctx:
                lines.append((cur, "@", ctx))
        elif cur and ln[:1] in "+-" and not ln.startswith(("+++", "---")):
            lines.append((cur, ln[0], ln[1:]))
    for f in untracked.splitlines():
        try:
            with open("%s/%s" % (repo, f), errors="ignore") as fh:
                lines.extend((f, "+", l.rstrip("\n")) for l in fh)
        except OSError:
            pass
    return modified, added, lines


def tokens(modified, lines):
    out = {}  # token -> (kind, where)
    for f in modified:
        name = f.rsplit("/", 1)[-1]
        if len(name) > 3:
            out.setdefault(name, ("file", f))
    exits = {"+": set(), "-": set()}
    mod = set(modified)
    for f, sign, text in lines:
        if f in mod and not is_test(f):
            for rx in FUNC:
                m = rx.match(text)
                if m and len(m.group(1)) > 2:
                    out.setdefault(m.group(1), ("function", f))
        if sign == "@":
            continue
        for m in FLAG.finditer(text):
            if m.group(1) not in SKIP_FLAGS:
                out.setdefault(m.group(1), ("flag", f))
        for m in ENV.finditer(text):
            v = m.group(1) or m.group(2)
            if v not in SKIP_ENV:
                out.setdefault(v, ("env", f))
        for m in FIELD.finditer(text):
            out.setdefault(m.group(1) + ":", ("field", f))
        for m in EXIT.finditer(text):
            exits[sign].add((m.group(1), f))
    for code, f in exits["+"] ^ exits["-"]:
        out.setdefault("exit %s" % code, ("exit", f))
    return out


def readers(repo, tok, kind, changed_files, changed_lines):
    """Ranked reader lines: non-test code that discards status first, then code, then the rest. A match in a
    modified file counts when it is outside the changed lines (another verb of the same script is a reader)."""
    if kind == "exit":
        code = tok.split()[1]
        pat = r"([$][?]|rc|returncode|status).{0,12}(-eq|==|!=|-ne|=| in ).{0,6}[^0-9]%s([^0-9]|$)" % code
        _, out = git(repo, "grep", "-n", "-I", "-E", pat)
    else:
        args = ["grep", "-n", "-I", "-F"] + (["-w"] if kind in ("function", "env") else []) + ["-e", tok]
        _, out = git(repo, *args)
    hits = []
    for ln in out.splitlines():
        path = ln.split(":", 1)[0]
        num = ln.split(":", 2)[1] if ln.count(":") >= 2 else ""
        if kind != "exit" and (path in changed_files and (path, num) in changed_lines or path in changed_files - set(m for m, _ in changed_lines)):
            continue  # the change itself, not a reader of it
        text = ln.split(":", 2)[-1]
        if kind == "function" and (not is_code(path) or any((m := rx.match(text)) and m.group(1) == tok for rx in FUNC)):
            continue  # prose, or the definition itself
        rank = (1 if is_test(path) else 0, 0 if is_code(path) and DISCARD.search(text) else 1 if is_code(path) else 2)
        hits.append((rank, ln[:220], bool(is_code(path) and DISCARD.search(text))))
    hits.sort(key=lambda h: h[0])
    return hits


def main(argv):
    ap = argparse.ArgumentParser(description="List a change's contract tokens and their readers.")
    ap.add_argument("--base")
    ap.add_argument("--repo", default=".")
    ap.add_argument("--max", type=int, default=8)
    a = ap.parse_args(argv)
    rc, _ = git(a.repo, "rev-parse", "--git-dir")
    if rc != 0:
        print("consumers: %s is not a git repository" % a.repo, file=sys.stderr)
        return 2
    base = base_ref(a.repo, a.base)
    if not base:
        print("consumers: cannot resolve a base (pass --base REF)", file=sys.stderr)
        return 2
    modified, added, lines = changed(a.repo, base)
    if not modified and not added:
        print("consumers: no changes against %s" % base[:12])
        return 0
    chl = {(f, t) for f, sign, t in lines if sign == "#"}
    lines = [x for x in lines if x[1] != "#"]
    toks = tokens(modified, lines)
    files = set(modified) | set(added)
    print("consumers: %d modified, %d new file(s) against %s; %d contract token(s). Open each reader and run its"
          " real input through the new code." % (len(modified), len(added), base[:12], len(toks)))
    order = {"file": 0, "function": 1, "flag": 2, "exit": 3, "field": 4, "env": 5}
    for tok, (kind, where) in sorted(toks.items(), key=lambda kv: (order[kv[1][0]], kv[0])):
        hits = readers(a.repo, tok, kind, files, chl)
        if kind == "function" and len(hits) > COMMON:
            print("\n%-8s %s  (changed in %s): %d references, too common a name to list; find its callers by context"
                  % (kind, tok, where, len(hits)))
            continue
        disc = sum(1 for h in hits if h[2])
        code = sum(1 for h in hits if h[0][1] < 2)
        head = ("%d reader(s), %d in code, %d discard status" % (len(hits), code, disc)) if hits else "no readers outside the change"
        print("\n%-8s %s  (changed in %s): %s" % (kind, tok, where, head))
        for h in hits[:a.max]:
            print("    %s%s" % ("[DISCARDS STATUS] " if h[2] else "", h[1]))
        if len(hits) > a.max:
            print("    ... %d more (git grep -n -F -e '%s')" % (len(hits) - a.max, tok))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
