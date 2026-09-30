#!/usr/bin/env python3
"""probe.py: falsify a PreToolUse guard with reshaped commands, without reading its code.

  probe.py --guard path/to/guard.sh [--guard other.sh ...] [--class NAME] [-v]

Point it at any guard (or several — a command is treated as blocked when ANY of them blocks it).
It loads evasion-classes.json, expands each template against a THROWAWAY home and working dir, and
sends it to the guard(s) as a hook payload. Guards judge the command string and never execute it,
so a case aimed at a "protected" path destroys nothing: the paths live under a temp dir that holds
no real files anyway.

It reports two failures, and a guard is judged on both:
  HOLE        a case that must block, which every guard allowed — a gap in the floor.
  OVER-BLOCK  a benign case a guard refused — over-blocking drives people to switch the guard off.

Each case carries its own unattended level, because some verdicts are correctly world-dependent
(a normal `git push` is fine attended, a force push is not). Use --class to limit the run to the
protection family a single guard owns; with no --class, every case runs, so a guard that covers
only one family will show HOLES for the others (expected — point it at the full guard set, or
filter). Exit 0 when there is no HOLE and no OVER-BLOCK, else 1.
"""
import argparse
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))


def guard_cmd(path):
    path = os.path.abspath(path)
    if os.access(path, os.X_OK):
        return [path]
    return (["python3", path] if path.endswith(".py") else ["bash", path])


def run_guard(cmd_argv, payload, env):
    p = subprocess.run(cmd_argv, input=json.dumps(payload), capture_output=True,
                       text=True, env=env, timeout=30)
    if "Traceback" in p.stderr or "SyntaxError" in p.stderr:
        first = next((l for l in p.stderr.splitlines() if l), "")
        print("  EXCEPTION in %s: %s" % (os.path.basename(cmd_argv[-1]), first[:160]))
    return p.returncode


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--guard", action="append", required=True, help="guard script (repeatable)")
    ap.add_argument("--class", dest="klass", help="only run this protection class")
    ap.add_argument("--lib", default=os.path.join(HERE, "evasion-classes.json"))
    ap.add_argument("-v", "--verbose", action="store_true")
    args = ap.parse_args(argv)

    cases = json.load(open(args.lib, encoding="utf-8"))["cases"]
    if args.klass:
        cases = [c for c in cases if c.get("class") == args.klass]
    if not cases:
        print("no cases match", file=sys.stderr)
        return 2
    guards = [guard_cmd(g) for g in args.guard]

    base = tempfile.mkdtemp(prefix="safety-probe-")
    home = os.path.join(base, "home")
    cwd = os.path.join(base, "work")
    tmp = os.path.join(base, "tmp")
    for d in (home, os.path.join(home, ".ssh"), os.path.join(home, ".claude", "hooks"),
              os.path.join(cwd, "build"), tmp):
        os.makedirs(d, exist_ok=True)
    # A config that protects the throwaway home and allows one egress host, so benign cases pass.
    cfg = os.path.join(base, "config.json")
    json.dump({"egress_allowed_hosts": ["api.github.com"]}, open(cfg, "w"))

    subst = {
        "{HOME}": home,
        "{PROT}": os.path.join(home, ".ssh"),
        "{SECRET}": os.path.join(home, ".ssh", "id_ed25519"),
        "{ENV}": os.path.join(cwd, ".env"),
        "{CTRL}": os.path.join(home, ".claude", "settings.json"),
        "{CTRLDIR}": os.path.join(home, ".claude", "hooks"),
        "{OK}": os.path.join(cwd, "build"),
        "{TMP}": tmp,
        "{HOST}": "evil.example.com",
        "{OKHOST}": "api.github.com",
    }

    def expand(s):
        for k, v in subst.items():
            s = s.replace(k, v)
        return s

    base_env = {
        "PATH": "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin",
        "HOME": home, "TMPDIR": tmp, "CLAUDE_SAFETY_CONFIG": cfg,
        "CLAUDE_SAFETY_LOG_DIR": os.path.join(base, "logs"),
    }
    os.makedirs(base_env["CLAUDE_SAFETY_LOG_DIR"], exist_ok=True)

    holes, over = [], []
    try:
        for c in cases:
            cmd = expand(c["cmd"])
            env = dict(base_env)
            if c.get("unattended"):
                env["CLAUDE_SAFETY_UNATTENDED"] = "1"
            payload = {"tool_name": "Bash", "tool_input": {"command": cmd}, "cwd": cwd}
            by = [os.path.basename(g[-1]) for g in guards if run_guard(g, payload, env) == 2]
            eff = "block" if by else "allow"
            ok = eff == c["expect"]
            if not ok and c["expect"] == "block":
                holes.append((c["class"], c["name"]))
            if not ok and c["expect"] == "allow":
                over.append((c["class"], c["name"], ",".join(by)))
            if args.verbose or not ok:
                print("%s %-22s %-28s want=%-5s got=%-5s by=%s" %
                      ("ok " if ok else "XX ", c["class"], c["name"][:28], c["expect"], eff,
                       ",".join(by) or "-"))
    finally:
        import shutil
        shutil.rmtree(base, ignore_errors=True)

    print("\n%d cases | %d HOLES | %d OVER-BLOCKS" % (len(cases), len(holes), len(over)))
    for k, n in holes:
        print("  HOLE       [%s] %s" % (k, n))
    for k, n, b in over:
        print("  OVER-BLOCK [%s] %s (blocked by %s)" % (k, n, b))
    return 1 if (holes or over) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
