#!/usr/bin/env python3
"""replay.py: replay your own past Bash commands through two guards and report how they differ.

  replay.py --old path/to/old-guard.sh --new path/to/new-guard.sh [--days 7] [--unattended]

Before changing a guard, this shows what the change does to the real commands you have actually
run, not just to hand-written cases. It reads your Claude Code session transcripts under
~/.claude/projects, pulls out the distinct Bash commands from the last N days, and runs each one
through both guards as a hook payload. Guards judge the command string and never run it.

PRIVACY: it prints COUNTS ONLY. No command, path, or transcript text is ever written to the
screen or to any file. Your real commands can contain tokens and private paths; this tool is
built so none of that leaves your machine or reaches a repo. If you need to see which shapes
changed, narrow the window with --days and inspect your guard's own log, not this tool.

Output: totals, how many each guard blocks, and the two disagreement counts:
  old-allow/new-block   the new guard is stricter here (check these are all things you want blocked)
  old-block/new-allow   the new guard is looser here (check you did not open a real hole)
Exit is always 0; this is a report, not a gate.
"""
import argparse
import glob
import json
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor


def guard_cmd(path):
    path = os.path.abspath(path)
    if os.access(path, os.X_OK):
        return [path]
    return (["python3", path] if path.endswith(".py") else ["bash", path])


def collect(days):
    """Distinct (command, cwd) pairs from transcripts modified in the last `days` days.

    Held in memory only. Never returned to a caller that prints it; only counted.
    """
    import subprocess  # noqa: F401  (kept local; nothing is shelled out here)
    root = os.path.expanduser("~/.claude/projects")
    cutoff = time.time() - days * 86400
    seen, rows = set(), []
    for f in glob.glob(os.path.join(root, "**", "*.jsonl"), recursive=True):
        try:
            if os.path.getmtime(f) < cutoff:
                continue
        except OSError:
            continue
        try:
            fh = open(f, errors="ignore")
        except OSError:
            continue
        with fh:
            for line in fh:
                if '"Bash"' not in line:
                    continue
                try:
                    r = json.loads(line)
                except ValueError:
                    continue
                content = r.get("message", {}).get("content")
                if not isinstance(content, list):
                    continue
                for b in content:
                    if b.get("type") == "tool_use" and b.get("name") == "Bash":
                        cmd = b.get("input", {}).get("command", "")
                        key = (cmd, r.get("cwd"))
                        if cmd and key not in seen:
                            seen.add(key)
                            rows.append({"cmd": cmd, "cwd": r.get("cwd") or os.path.expanduser("~")})
    return rows


def main(argv):
    import subprocess
    ap = argparse.ArgumentParser()
    ap.add_argument("--old", required=True)
    ap.add_argument("--new", required=True)
    ap.add_argument("--days", type=float, default=7)
    ap.add_argument("--unattended", action="store_true",
                    help="judge every command as an unattended session would")
    args = ap.parse_args(argv)

    old, new = guard_cmd(args.old), guard_cmd(args.new)
    rows = collect(args.days)
    if not rows:
        print("No Bash commands found in ~/.claude/projects in the last %g days." % args.days)
        return 0

    env = dict(os.environ)
    env.pop("CLAUDE_GUARD_OVERRIDE", None)
    # Replays are judgements, not events: keep them out of the real block log.
    import tempfile
    env["CLAUDE_SAFETY_LOG_DIR"] = tempfile.mkdtemp(prefix="guard-replay-")
    if args.unattended:
        env["CLAUDE_SAFETY_UNATTENDED"] = "1"

    def judge(guard, row):
        payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": row["cmd"]},
                              "cwd": row["cwd"]})
        try:
            p = subprocess.run(guard, input=payload, capture_output=True, text=True,
                               env=env, timeout=30)
        except Exception:
            return None
        exc = ("Traceback" in p.stderr or "SyntaxError" in p.stderr)
        return (p.returncode, exc)

    def both(row):
        return judge(old, row), judge(new, row)

    n = len(rows)
    old_block = new_block = old_exc = new_exc = 0
    old_allow_new_block = old_block_new_allow = errors = 0
    with ThreadPoolExecutor(max_workers=8) as ex:
        for a, b in ex.map(both, rows):
            if a is None or b is None:
                errors += 1
                continue
            ra, ea = a
            rb, eb = b
            old_block += ra == 2
            new_block += rb == 2
            old_exc += ea
            new_exc += eb
            if ra == 0 and rb == 2:
                old_allow_new_block += 1
            if ra == 2 and rb == 0:
                old_block_new_allow += 1

    print("Replayed %d distinct commands from the last %g days (%s mode)."
          % (n, args.days, "unattended" if args.unattended else "attended"))
    print("  old guard blocks:        %d" % old_block)
    print("  new guard blocks:        %d" % new_block)
    print("  old allow -> new block:  %d   (new guard is stricter on these)" % old_allow_new_block)
    print("  old block -> new allow:  %d   (new guard is looser on these — check for a new hole)"
          % old_block_new_allow)
    if old_exc or new_exc:
        print("  guard raised an error:   old=%d new=%d   (a guard that errors fails open)"
              % (old_exc, new_exc))
    if errors:
        print("  could not run:           %d" % errors)
    print("(counts only, by design — no command text is ever printed)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
