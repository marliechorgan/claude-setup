#!/usr/bin/env python3
"""run_cases.py: run every guard's test cases through the wrapper, as Claude Code would.

  python3 tests/run_cases.py [guard-name ...] [-v]

Each tests/<guard>.cases.json holds [{"name", "payload", "expect": "allow"|"block", "why"}].
$HOME and $CWD inside a payload are replaced by a throwaway home and working directory, and
the guards run with HOME pointed there too, so no real file is ever read or touched. Guards
judge commands; nothing in a payload is executed. Exit 0 when every case matches.
"""
import glob
import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
WRAPPER = os.path.join(ROOT, "guards", "guard-run.sh")


def expand(obj, home, cwd):
    if isinstance(obj, str):
        return obj.replace("$HOME", home).replace("$CWD", cwd)
    if isinstance(obj, list):
        return [expand(x, home, cwd) for x in obj]
    if isinstance(obj, dict):
        return {k: expand(v, home, cwd) for k, v in obj.items()}
    return obj


def main(argv):
    verbose = "-v" in argv
    names = [a for a in argv if not a.startswith("-")]
    files = sorted(glob.glob(os.path.join(HERE, "*.cases.json")))
    if names:
        files = [f for f in files if os.path.basename(f).split(".cases.json")[0] in names]
    if not files:
        print("no case files found", file=sys.stderr)
        return 2
    base = tempfile.mkdtemp(prefix="safety-tests-")
    home, cwd, logs = (os.path.join(base, d) for d in ("home", "work", "logs"))
    for d in (home, cwd, logs):
        os.makedirs(d)
    env = {"HOME": home, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin",
           "TMPDIR": os.path.join(base, "tmp"), "CLAUDE_SAFETY_LOG_DIR": logs,
           "CLAUDE_SAFETY_CONFIG": os.path.join(HERE, "config.test.json")}
    os.makedirs(env["TMPDIR"])
    total = fails = 0
    try:
        for f in files:
            guard = os.path.basename(f).split(".cases.json")[0]
            script = os.path.join(ROOT, "guards", guard + ".sh")
            if not os.path.exists(script):
                script = os.path.join(ROOT, "guards", guard + ".py")
            cases = json.load(open(f, encoding="utf-8"))
            gfail = 0
            for c in cases:
                total += 1
                payload = expand(c["payload"], home, cwd)
                payload.setdefault("cwd", cwd)
                cenv = dict(env, **c.get("env", {}))
                p = subprocess.run(["bash", WRAPPER, script], input=json.dumps(payload),
                                   capture_output=True, text=True, env=cenv, cwd=cwd, timeout=30)
                got = {0: "allow", 2: "block"}.get(p.returncode, f"break(rc={p.returncode})")
                if got != c["expect"]:
                    fails += 1
                    gfail += 1
                    print(f"FAIL {guard} :: {c['name']}: expected {c['expect']}, got {got}")
                    if p.stderr.strip():
                        print("     " + p.stderr.strip().splitlines()[0][:200])
                elif verbose:
                    print(f"ok   {guard} :: {c['name']}")
            print(f"{guard}: {len(cases) - gfail}/{len(cases)} passed")
    finally:
        shutil.rmtree(base, ignore_errors=True)
    print(f"TOTAL {total - fails}/{total} passed")
    return 0 if fails == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
