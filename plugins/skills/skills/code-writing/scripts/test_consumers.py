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
        write(self.d + "/hooks/queue.sh", "#!/bin/bash\nadd_card() {\n  [ -n \"$1\" ] || exit 4\n  echo \"status: open\"\n}\n")
        write(self.d + "/hooks/inbox.sh", "#!/bin/bash\n./hooks/queue.sh add --source inbox >/dev/null 2>&1 || true\n"
                                          "add_card x; [ $? -eq 5 ] && echo refused\n")
        write(self.d + "/hooks/other.py", "print('unrelated')\n")
        sh(self.d, "git", "add", "-A")
        sh(self.d, "git", "commit", "-q", "-m", "base")

    def run_it(self, *args):
        p = subprocess.run([sys.executable, SCRIPT, "--repo", self.d] + list(args), capture_output=True, text=True)
        return p.returncode, p.stdout + p.stderr

    def test_lists_readers_of_changed_contract(self):
        write(self.d + "/hooks/queue.sh", "#!/bin/bash\nadd_card() {\n  [ -n \"$WHY_OS\" ] || exit 5\n"
                                          "  case \"$1\" in --source) : ;; esac\n  echo \"why_os: $WHY_OS\"\n}\n")
        rc, out = self.run_it("--base", "main")
        self.assertEqual(rc, 0, out)
        self.assertRegex(out, r"file\s+queue\.sh .*1 reader")           # inbox.sh runs it
        self.assertIn("[DISCARDS STATUS] hooks/inbox.sh:2:", out)   # the caller that would lose a new refusal
        self.assertRegex(out, r"function add_card .*1 reader")
        self.assertRegex(out, r"flag\s+--source .*1 reader")
        self.assertRegex(out, r"exit\s+exit 5 .*reader")                 # a new exit code and the line testing it
        self.assertIn("hooks/inbox.sh:3:", out)
        self.assertRegex(out, r"env\s+WHY_OS .*no readers outside the change")
        self.assertRegex(out, r"field\s+why_os: ")
        self.assertNotIn("other.py", out)

    def test_untracked_new_file_counts(self):
        write(self.d + "/hooks/new.sh", "#!/bin/bash\nnew_helper() { :; }\n[ -n \"$QUEUE_DIR\" ] || exit 3\n")
        rc, out = self.run_it("--base", "main")
        self.assertEqual(rc, 0, out)
        self.assertIn("1 new file(s)", out)
        self.assertIn("env      QUEUE_DIR", out)          # a new file's inputs are still contract
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
