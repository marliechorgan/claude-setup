#!/usr/bin/env python3
"""Regression tests for draft_lint.py. Run: python3 test_draft_lint.py"""
import os
import subprocess
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
LINT = os.path.join(HERE, "draft_lint.py")


def run(text, *args):
    p = subprocess.run([sys.executable, LINT, *args], input=text, capture_output=True, text=True)
    return p.returncode, p.stdout


class DraftLint(unittest.TestCase):
    def test_clean_text_passes(self):
        self.assertEqual(run("sounds good, see you Thu 2 Oct at 8\n")[0], 0)

    def test_em_dash_flagged(self):
        code, out = run("see you there — can't wait\n")
        self.assertEqual(code, 1)
        self.assertIn("dash", out)

    def test_number_range_en_dash_allowed(self):
        self.assertEqual(run("free 2–4pm on Friday 3 Oct\n")[0], 0)

    def test_relative_date_flagged(self):
        self.assertIn("date", run("let's do tomorrow\n")[1])

    def test_stock_phrase_flagged(self):
        self.assertIn("stock", run("just checking in on the invoice\n")[1])

    def test_chat_only_phrase_allowed_in_email(self):
        email = "Hi Sam,\n\nI hope you're well.\n\nThe report is attached.\n\nBest,\nAlex\n"
        self.assertEqual(run(email, "--channel", "email")[0], 0)
        self.assertEqual(run("hope you're well mate\n")[0], 1)

    def test_long_chat_message_flagged_and_threshold_adjustable(self):
        text = " ".join(["word"] * 60) + "\n"
        self.assertIn("length", run(text)[1])
        self.assertEqual(run(text, "--max-words", "80")[0], 0)

    def test_markdown_skips_quoted_incoming_message(self):
        md = "> *Sam: see you tomorrow — yeah?*\n\n> yes, Thu 2 Oct works\n"
        self.assertEqual(run(md, "--markdown")[0], 0)

    def test_markdown_numbers_each_blockquote(self):
        md = "> fine\n\n> circle back later\n"
        code, out = run(md, "--markdown")
        self.assertEqual(code, 1)
        self.assertIn("message 2", out)

    def test_usage_error_exits_2(self):
        self.assertEqual(run("x", "--channel", "fax")[0], 2)


if __name__ == "__main__":
    unittest.main(verbosity=1)
