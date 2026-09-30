#!/usr/bin/env python3
"""corpus-check.py: run a cases file through a guard, and optionally against a candidate guard.

  corpus-check.py --guard g.sh cases.json                 # does g.sh match every case?
  corpus-check.py --guard live.sh --candidate new.sh cases.json   # does new.sh match, and agree?

A cases file is a JSON list. Each case is either the plugin's own shape
  {"name": ..., "payload": {hook JSON}, "expect": "allow"|"block"}
or a compact shape
  {"name"|"note": ..., "cmd": ..., "cwd": ..., "want": 0|2, "unattended": 0|1}
Both are accepted; a file may mix them. $HOME and $CWD inside a case are expanded to a throwaway
home and working dir, and the guard runs with HOME pointed there, so nothing real is read or
touched — guards judge commands, they never run them.

Prints every case the (candidate, or the guard when there is no candidate) misses, and every case
where the candidate disagrees with the guard, then the fail counts. Exit 1 if it fails any case.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile


def guard_cmd(path):
    path = os.path.abspath(path)
    if os.access(path, os.X_OK):
        return [path]
    return (["python3", path] if path.endswith(".py") else ["bash", path])


def expand(obj, home, cwd):
    if isinstance(obj, str):
        return obj.replace("$HOME", home).replace("$CWD", cwd)
    if isinstance(obj, list):
        return [expand(x, home, cwd) for x in obj]
    if isinstance(obj, dict):
        return {k: expand(v, home, cwd) for k, v in obj.items()}
    return obj


def want_rc(case):
    if "expect" in case:
        return {"allow": 0, "block": 2}[case["expect"]]
    return int(case["want"])


def payload_of(case, cwd):
    if "payload" in case:
        p = dict(case["payload"])
        p.setdefault("cwd", cwd)
        return p
    return {"tool_name": "Bash", "tool_input": {"command": case["cmd"]},
            "cwd": case.get("cwd") or cwd}


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--guard", required=True)
    ap.add_argument("--candidate")
    ap.add_argument("cases")
    args = ap.parse_args(argv)

    live = guard_cmd(args.guard)
    cand = guard_cmd(args.candidate) if args.candidate else live
    cases = json.load(open(args.cases, encoding="utf-8"))
    if isinstance(cases, dict):
        cases = cases.get("cases", [])

    base = tempfile.mkdtemp(prefix="safety-corpus-")
    home, cwd, logs = (os.path.join(base, d) for d in ("home", "work", "logs"))
    for d in (home, cwd, logs):
        os.makedirs(d)
    env = {"HOME": home, "TMPDIR": os.path.join(base, "tmp"),
           "PATH": "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin",
           "CLAUDE_SAFETY_LOG_DIR": logs}
    os.makedirs(env["TMPDIR"])

    fails = {"live": 0, "cand": 0}
    try:
        for c in cases:
            name = c.get("name") or c.get("note") or "?"
            want = want_rc(c)
            payload = expand(payload_of(c, cwd), home, cwd)
            cenv = dict(env)
            if c.get("unattended") or c.get("headless"):
                cenv["CLAUDE_SAFETY_UNATTENDED"] = "1"
            rcs = []
            for g in (live, cand):
                p = subprocess.run(g, input=json.dumps(payload), capture_output=True,
                                   text=True, env=cenv, timeout=30)
                if "Traceback" in p.stderr or "SyntaxError" in p.stderr:
                    print("EXCEPTION %s :: %s" % (os.path.basename(g[-1]), name))
                rcs.append(p.returncode)
            fails["live"] += rcs[0] != want
            fails["cand"] += rcs[1] != want
            if rcs[1] != want or rcs[0] != rcs[1]:
                tag = "ok " if rcs[1] == want else "XX "
                print("%s live=%s cand=%s want=%s | %s" % (tag, rcs[0], rcs[1], want, name))
    finally:
        shutil.rmtree(base, ignore_errors=True)

    if args.candidate:
        print("%d cases | live fails %d | candidate fails %d" % (len(cases), fails["live"], fails["cand"]))
    else:
        print("%d cases | fails %d" % (len(cases), fails["live"]))
    return 1 if fails["cand"] else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
