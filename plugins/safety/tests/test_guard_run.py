#!/usr/bin/env python3
"""test_guard_run.py: prove guard-run.sh's contract with throwaway guards.

  python3 tests/test_guard_run.py [-v]

Covers pass-through, the integrity gate, block/break logging, secret redaction in the
ledger, the portable temp file, and a JSON "deny" on exit 0 being recorded as a block.
Runs under /bin/bash (3.2 on macOS) when present. Standard library only.
"""
import glob
import json
import os
import shutil
import stat
import subprocess
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
WRAPPER = os.path.join(os.path.dirname(HERE), "guards", "guard-run.sh")
BASH = "/bin/bash" if os.path.exists("/bin/bash") else "bash"
def lines(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read().splitlines()


PAYLOAD = json.dumps({"tool_name": "Bash", "tool_input": {"command": "ls -la"}, "cwd": "/tmp"}) + "\n"


class GuardRunTest(unittest.TestCase):
    def setUp(self):
        self.base = tempfile.mkdtemp(prefix="guard-run-test-")
        self.logs = os.path.join(self.base, "logs")
        self.tmp = os.path.join(self.base, "tmp")
        os.makedirs(self.tmp)
        self.env = {"HOME": os.path.join(self.base, "home"), "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
                    "TMPDIR": self.tmp, "CLAUDE_SAFETY_LOG_DIR": self.logs}

    def tearDown(self):
        shutil.rmtree(self.base, ignore_errors=True)

    def guard(self, body, name="g.sh", mode=0o755):
        path = os.path.join(self.base, name)
        with open(path, "w") as fh:
            fh.write(body)
        os.chmod(path, mode)
        return path

    def run_wrapper(self, args, payload=PAYLOAD, env=None, cwd=None):
        return subprocess.run([BASH, WRAPPER] + args, input=payload, capture_output=True,
                              text=True, env=env or self.env, cwd=cwd or self.base, timeout=30)

    def ledger(self):
        path = os.path.join(self.logs, "ledger.jsonl")
        if not os.path.exists(path):
            return []
        return [json.loads(line) for line in lines(path)]

    def activity(self):
        rows = []
        for f in glob.glob(os.path.join(self.logs, "activity-*.tsv")):
            rows += [line.split("\t") for line in lines(f)]
        return rows

    # --- pass-through --------------------------------------------------------------
    def test_passthrough_exact(self):
        g = self.guard('#!/bin/bash\ncat\nprintf "note\\n" >&2\nexit 0\n')
        payload = PAYLOAD + "\n\ntrailing  spaces  \n"
        p = self.run_wrapper([g], payload=payload)
        self.assertEqual(p.returncode, 0)
        self.assertEqual(p.stdout, payload)
        self.assertEqual(p.stderr, "note\n")
        self.assertEqual(self.ledger(), [], "an allow must not be logged")
        self.assertEqual(self.activity(), [])

    def test_exit_codes_pass_through_and_log(self):
        for rc, verdict in ((2, "block"), (1, "break"), (3, "break"), (127, "break")):
            g = self.guard('#!/bin/bash\necho "BLOCKED by g: no" >&2\nexit %d\n' % rc, name="g%d.sh" % rc)
            p = self.run_wrapper([g])
            self.assertEqual(p.returncode, rc)
            self.assertEqual(p.stderr, "BLOCKED by g: no\n")
            row = self.ledger()[-1]
            self.assertEqual((row["verdict"], row["rc"], row["guard"]), (verdict, rc, "g%d.sh" % rc))
            self.assertEqual(row["reason"], "BLOCKED by g: no")
            self.assertEqual(row["subject"], "ls -la")
            self.assertEqual(self.activity()[-1][1:], ["g%d.sh" % rc, verdict, "0"])

    def test_guard_arguments_forwarded(self):
        g = self.guard('#!/bin/bash\necho "$1|$2"\nexit 0\n')
        p = self.run_wrapper([g, "a b", "c"])
        self.assertEqual(p.stdout, "a b|c\n")

    def test_relative_guard_path_and_cwd_isolation(self):
        self.guard('#!/bin/bash\npwd\necho "$CLAUDE_PROJECT_DIR"\nexit 0\n', name="rel.sh")
        p = self.run_wrapper(["./rel.sh"], cwd=self.base)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(p.stdout.split("\n")[0], "/")
        self.assertEqual(os.path.realpath(p.stdout.split("\n")[1]), os.path.realpath(self.base))

    def test_unattended_recorded(self):
        g = self.guard("#!/bin/bash\nexit 2\n")
        self.run_wrapper([g], env=dict(self.env, CLAUDE_SAFETY_UNATTENDED="1"))
        self.assertEqual(self.ledger()[-1]["unattended"], "1")
        self.assertEqual(self.activity()[-1][3], "1")

    # --- integrity gate ------------------------------------------------------------
    def assert_absent(self, args):
        p = self.run_wrapper(args)
        self.assertEqual(p.returncode, 2)
        self.assertTrue(p.stderr.startswith("BLOCKED by guard-run [guard-absent]"), p.stderr)
        self.assertIn("DO THIS INSTEAD:", p.stderr)
        self.assertEqual(self.ledger()[-1]["verdict"], "absent")
        self.assertEqual(self.ledger()[-1]["subject"], "ls -la")

    def test_gate_no_argument(self):
        self.assert_absent([])

    def test_gate_missing(self):
        self.assert_absent([os.path.join(self.base, "nope.sh")])

    def test_gate_not_executable(self):
        self.assert_absent([self.guard("#!/bin/bash\nexit 0\n", mode=0o644)])

    def test_gate_empty(self):
        self.assert_absent([self.guard("")])

    def test_gate_truncated(self):
        full = '#!/bin/bash\npython3 -I -S - <<\'PY\'\nimport sys\nsys.exit(2)\nPY\n'
        self.assert_absent([self.guard(full[: full.index("sys.exit") + 5])])

    def test_gate_directory(self):
        d = os.path.join(self.base, "dir.sh")
        os.makedirs(d)
        self.assert_absent([d])

    def test_gate_accepts_known_endings(self):
        endings = ["exit 0", "exit $RC", "fi", "esac", "done", "}", "PY", "# guard-end", "sys.exit(main())"]
        for i, last in enumerate(endings):
            # "exit 0" runs first, so only the gate's reading of the last line is under test
            g = self.guard("#!/bin/bash\nexit 0\n" + last + "\n\n", name="end%d.sh" % i)
            p = self.run_wrapper([g])
            self.assertEqual(p.returncode, 0, "%r rejected: %s" % (last, p.stderr))

    # --- secrets never reach the ledger ------------------------------------
    def test_subject_redacted_and_short(self):
        secrets = ["hunter2hunter2", "sk-ant-api03-AAAAbbbbCCCCddddEEEE", "ghp_0123456789abcdefghijABCDEFGHIJ",
                   "AKIAIOSFODNN7EXAMPLE", "s3cr3tvalue", "xoxb-1234567890-abcdefghij",
                   "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N",
                   "0123456789abcdef0123456789abcdef", "pa55word"]
        cmd = ("curl -H 'Authorization: Bearer %s' -u admin:%s https://x.test/?api_key=%s "
               "AWS=%s --password %s TOKEN=%s -H 'X: %s' %s postgres://bob:%s@localhost:5432/app"
               % tuple(secrets[i] for i in (4, 0, 1, 3, 0, 5, 6, 7, 8)))
        cmd += " " + "z" * 300
        payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": "export GITHUB_TOKEN=%s; " % secrets[2] + cmd}})
        g = self.guard('#!/bin/bash\necho "BLOCKED by g: saw GITHUB_TOKEN=%s" >&2\nexit 2\n' % secrets[2])
        p = self.run_wrapper([g], payload=payload)
        self.assertEqual(p.returncode, 2)
        row = self.ledger()[-1]
        self.assertLessEqual(len(row["subject"]), 120)
        blob = json.dumps(row)
        for s in secrets:
            self.assertNotIn(s, blob, "secret %r leaked into %s" % (s, blob))
        self.assertIn("curl", row["subject"])

    def test_redaction_keeps_ordinary_commands(self):
        g = self.guard("#!/bin/bash\nexit 2\n")
        payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": "git commit --author=me -m 'fix: token parsing'"}})
        self.run_wrapper([g], payload=payload)
        self.assertEqual(self.ledger()[-1]["subject"], "git commit --author=me -m 'fix: token parsing'")

    # --- portable temp file (GNU and BSD mktemp) ------------------------------------------------
    def test_temp_file_in_tmpdir_and_removed(self):
        seen = os.path.join(self.base, "seen")
        g = self.guard('#!/bin/bash\nls -d "$TMPDIR"/guard-run.?????? > %s 2>/dev/null\necho "BLOCKED by g: x" >&2\nexit 2\n' % seen)
        p = self.run_wrapper([g])
        self.assertEqual(p.returncode, 2)
        self.assertEqual(len(lines(seen)), 1, "the temp dir should be $TMPDIR/guard-run.XXXXXX")
        self.assertEqual(os.listdir(self.tmp), [], "temp dir must be removed on exit")
        self.assertEqual(self.ledger()[-1]["reason"], "BLOCKED by g: x", "stderr must be captured")

    def test_temp_file_without_tmpdir(self):
        g = self.guard('#!/bin/bash\necho "BLOCKED by g: y" >&2\nexit 2\n')
        env = {k: v for k, v in self.env.items() if k != "TMPDIR"}
        p = self.run_wrapper([g], env=env)
        self.assertEqual((p.returncode, p.stderr), (2, "BLOCKED by g: y\n"))
        self.assertEqual(self.ledger()[-1]["reason"], "BLOCKED by g: y")

    def test_temp_file_with_bad_tmpdir(self):
        g = self.guard('#!/bin/bash\ncat\necho "BLOCKED by g: z" >&2\nexit 2\n')
        p = self.run_wrapper([g], env=dict(self.env, TMPDIR=os.path.join(self.base, "missing")))
        self.assertEqual((p.returncode, p.stdout, p.stderr), (2, PAYLOAD, "BLOCKED by g: z\n"))
        self.assertEqual(self.ledger()[-1]["reason"], "BLOCKED by g: z")

    # --- a JSON deny with exit 0 is recorded as a block -----------------------------------
    def test_json_deny_recorded_as_block(self):
        out = json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny",
                                                 "permissionDecisionReason": "BLOCKED by g: json deny"}})
        g = self.guard("#!/bin/bash\ncat <<'EOF'\n%s\nEOF\nexit 0\n" % out)
        p = self.run_wrapper([g])
        self.assertEqual(p.returncode, 0, "the exit code still passes through")
        self.assertEqual(p.stdout, out + "\n", "stdout still passes through")
        row = self.ledger()[-1]
        self.assertEqual((row["verdict"], row["rc"], row["reason"]), ("block", 0, "BLOCKED by g: json deny"))
        self.assertEqual(self.activity()[-1][2], "block")

    def test_legacy_decision_block_recorded(self):
        g = self.guard('#!/bin/bash\necho \'{"decision": "block", "reason": "legacy"}\'\nexit 0\n')
        self.run_wrapper([g])
        self.assertEqual((self.ledger()[-1]["verdict"], self.ledger()[-1]["reason"]), ("block", "legacy"))

    def test_json_allow_not_logged(self):
        for decision in ("allow", "ask"):
            g = self.guard('#!/bin/bash\necho \'{"hookSpecificOutput": {"permissionDecision": "%s"}}\'\nexit 0\n' % decision)
            p = self.run_wrapper([g])
            self.assertEqual(p.returncode, 0)
        self.assertEqual(self.ledger(), [])

    def test_non_json_stdout_not_logged(self):
        g = self.guard('#!/bin/bash\necho \'the word "decision" in plain text\'\nexit 0\n')
        self.assertEqual(self.run_wrapper([g]).returncode, 0)
        self.assertEqual(self.ledger(), [])


if __name__ == "__main__":
    unittest.main()
