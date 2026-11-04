#!/usr/bin/env python3
"""Regression tests for consumers.py. Run: python3 test_consumers.py"""
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "consumers.py")


def sh(cwd, *cmd):
    subprocess.run(cmd, cwd=cwd, check=True, capture_output=True,
                   env=dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t", GIT_COMMITTER_NAME="t",
                            GIT_COMMITTER_EMAIL="t@t"))


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as fh:
        fh.write(text)


class Consumers(unittest.TestCase):
    def setUp(self):
        self.d = tempfile.mkdtemp(prefix="consumers-test-")
        sh(self.d, "git", "init", "-q", "-b", "main")
        write(self.d + "/hooks/jobs.sh", "#!/bin/bash\nadd_job() {\n  [ -n \"$1\" ] || exit 4\n  echo \"status: open\"\n}\n")
        write(self.d + "/hooks/report.sh", "#!/bin/bash\n./hooks/jobs.sh add --source report >/dev/null 2>&1 || true\n"
                                          "add_job x; [ $? -eq 5 ] && echo refused\n")
        write(self.d + "/hooks/other.py", "print('unrelated')\n")
        sh(self.d, "git", "add", "-A")
        sh(self.d, "git", "commit", "-q", "-m", "base")

    def run_it(self, *args):
        p = subprocess.run([sys.executable, SCRIPT, "--repo", self.d] + list(args), capture_output=True, text=True)
        return p.returncode, p.stdout + p.stderr

    def test_lists_readers_of_changed_contract(self):
        write(self.d + "/hooks/jobs.sh", "#!/bin/bash\nadd_job() {\n  [ -n \"$JOB_REASON\" ] || exit 5\n"
                                          "  case \"$1\" in --source) : ;; esac\n  echo \"reason: $JOB_REASON\"\n}\n")
        rc, out = self.run_it("--base", "main")
        self.assertEqual(rc, 0, out)
        self.assertRegex(out, r"file\s+jobs\.sh .*1 reader")           # report.sh runs it
        self.assertIn("[DISCARDS STATUS] hooks/report.sh:2:", out)   # the caller that would lose a new refusal
        self.assertRegex(out, r"function add_job .*1 reader")
        self.assertRegex(out, r"flag\s+--source .*1 reader")
        self.assertRegex(out, r"exit\s+exit 5 .*reader")                 # a new exit code and the line testing it
        self.assertIn("hooks/report.sh:3:", out)
        self.assertRegex(out, r"env\s+JOB_REASON .*no readers outside the change")
        self.assertRegex(out, r"field\s+reason: ")
        self.assertNotIn("other.py", out)

    def test_untracked_new_file_counts(self):
        write(self.d + "/hooks/new.sh", "#!/bin/bash\nnew_helper() { :; }\n[ -n \"$JOBS_DIR\" ] || exit 3\n")
        rc, out = self.run_it("--base", "main")
        self.assertEqual(rc, 0, out)
        self.assertIn("1 new file(s)", out)
        self.assertIn("env      JOBS_DIR", out)          # a new file's inputs are still contract
        self.assertNotIn("function new_helper", out)       # a brand-new function has no existing callers

    def test_no_changes(self):
        rc, out = self.run_it("--base", "main")
        self.assertEqual(rc, 0)
        self.assertIn("no changes", out)

    def test_bad_base_and_not_a_repo(self):
        self.assertEqual(self.run_it("--base", "nope")[0], 2)
        p = subprocess.run([sys.executable, SCRIPT, "--repo", tempfile.mkdtemp()], capture_output=True, text=True)
        self.assertEqual(p.returncode, 2)


if __name__ == "__main__":
    unittest.main(verbosity=1)
