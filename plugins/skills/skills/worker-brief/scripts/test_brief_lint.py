#!/usr/bin/env python3
"""Fixture tests for brief_lint.py. Standard library only; runs on the system python 3.9.

Every case calls the lint BY PATH, as delegators do, inside a
temporary directory, so which paths exist is decided by the fixture and never by this machine.
Run: skills/worker-brief/scripts/test_brief_lint.py
"""
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

LINT = Path(__file__).resolve().parent / "brief_lint.py"

GOOD = """# W1: count the widgets
Outcome: a count of widgets in {root}/src/widgets.py, with evidence.
Acceptance: the result states the count and quotes each definition line.
Inputs: {root}/src/widgets.py:3 `def widget_a():` is the first definition.
Write scope: read-only apart from the report and {root}/scratch/w1/.
Limits: 20 tool calls; return partial work with what is unfinished if you hit them.
Return: {root}/out/w1.md (write it there; if you cannot, return it inline).
Challenge this brief with evidence if it is wrong.
"""


def run(args, cwd, stdin=None, home=None):
    env = dict(os.environ)
    if home:
        env["HOME"] = home
    p = subprocess.run([str(LINT)] + args, cwd=cwd, input=stdin, env=env,
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
    return p.returncode, p.stdout, p.stderr


class LintCase(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.root = Path(self._td.name).resolve()
        (self.root / "src").mkdir()
        (self.root / "out").mkdir()
        (self.root / "scratch").mkdir()
        (self.root / "briefs").mkdir()
        (self.root / "src" / "widgets.py").write_text(
            "import os\n\ndef widget_a():\n    pass\n\n\n\n\n\ndef widget_b():\n    return 2\n")

    def tearDown(self):
        self._td.cleanup()

    def brief(self, text, name="w1.md"):
        p = self.root / "briefs" / name
        p.write_text(text.format(root=self.root))
        return str(p)

    def lint(self, *paths, **kw):
        return run(list(paths), cwd=str(self.root), **kw)

    def findings(self, out, check):
        return [ln for ln in out.splitlines() if (": %s: " % check) in ln]


class Clean(LintCase):
    def test_good_brief_passes_and_says_so(self):
        code, out, err = self.lint(self.brief(GOOD))
        self.assertEqual(code, 0, out + err)
        self.assertIn("0 finding(s) in 1 brief(s)", out)  # a silent success looks like no run

    def test_stdin_brief(self):
        code, out, err = self.lint("-", stdin=GOOD.format(root=self.root))
        self.assertEqual(code, 0, out + err)

    def test_unreadable_brief_is_usage_error(self):
        code, out, err = self.lint(str(self.root / "nope.md"))
        self.assertEqual(code, 2)


class DeadPaths(LintCase):
    def test_missing_input_is_named(self):
        b = self.brief(GOOD + "Read first: {root}/docs/plan.md\n")
        code, out, _ = self.lint(b)
        self.assertEqual(code, 1)
        self.assertTrue(any("docs/plan.md" in f for f in self.findings(out, "dead-path")), out)

    def test_archived_twin_is_reported(self):
        home = self.root / "home"
        (home / ".claude/skills/_archive/old-skill").mkdir(parents=True)
        (home / ".claude/skills/_archive/old-skill/SKILL.md").write_text("x\n")
        b = self.brief(GOOD + "Follow ~/.claude/skills/old-skill/SKILL.md for the method.\n")
        code, out, _ = self.lint(b, home=str(home))
        f = self.findings(out, "dead-path")
        self.assertEqual(code, 1)
        self.assertTrue(f and "_archive" in f[0], out)

    def test_outputs_and_placeholders_are_not_dead(self):
        b = self.brief(GOOD + "Write the table to {root}/out/new-table.md and create {root}/out/sub/x.json.\n"
                       "Scratch: {root}/scratch/w9/\nEach result is {root}/out/<id>.md; see $WT/hooks/x.sh "
                       "and {root}/src/.../y.py and /tmp/worker-*.lock and {root}/src/*/$SESSION_ID.jsonl\n")
        code, out, _ = self.lint(b)
        self.assertEqual(self.findings(out, "dead-path"), [], out)
        self.assertEqual(code, 0, out)

    def test_glob_matching_nothing_is_dead(self):
        b = self.brief(GOOD + "Evidence: {root}/src/*.rs\n")
        code, out, _ = self.lint(b)
        self.assertEqual(code, 1)
        self.assertTrue(self.findings(out, "dead-path"), out)

    def test_relative_path_under_a_base(self):
        b = self.brief(GOOD + "Read src/gone.py first.\n")
        code, out, _ = self.lint("--base", str(self.root), b)
        self.assertTrue(any("src/gone.py" in f for f in self.findings(out, "dead-path")), out)
        code, out, _ = self.lint(b)  # no base: a relative path cannot be judged
        self.assertEqual(code, 0, out)


class LineRefs(LintCase):
    def test_quote_found_elsewhere_is_drift(self):
        b = self.brief(GOOD.replace("widgets.py:3 `def widget_a():`", "widgets.py:3 `def widget_b():`"))
        code, out, _ = self.lint(b)
        f = self.findings(out, "drifted-line-ref")
        self.assertEqual(code, 1)
        self.assertTrue(f and "line 10" in f[0], out)

    def test_quote_absent_from_file(self):
        b = self.brief(GOOD.replace("`def widget_a():`", "`def widget_z():`"))
        code, out, _ = self.lint(b)
        self.assertTrue(self.findings(out, "drifted-line-ref"), out)

    def test_line_past_end_of_file(self):
        b = self.brief(GOOD + "See {root}/src/widgets.py:400 for the tail.\n")
        code, out, _ = self.lint(b)
        f = self.findings(out, "drifted-line-ref")
        self.assertTrue(f and "past the end" in f[0], out)

    def test_quote_before_ref_and_approximate_ref(self):
        b = self.brief(GOOD + "The `return 2` ({root}/src/widgets.py:11) matters, and so does "
                       "{root}/src/widgets.py around `widget_b` (~line 14).\n")
        code, out, _ = self.lint(b)
        self.assertEqual(self.findings(out, "drifted-line-ref"), [], out)
        self.assertEqual(code, 0, out)

    def test_new_text_near_a_ref_is_not_a_quote(self):
        b = self.brief(GOOD + "Add `class: config-change` to the condition at `{root}/src/widgets.py:3`.\n")
        code, out, _ = self.lint(b)
        self.assertEqual(code, 0, out)

    def test_bare_name_resolves_through_base(self):
        b = self.brief(GOOD + "widgets.py:7 `def widget_a():` is where to start.\n")
        code, out, _ = self.lint("--base", str(self.root / "src"), b)
        self.assertTrue(self.findings(out, "drifted-line-ref"), out)


class PathClash(LintCase):
    def test_return_path_is_the_brief(self):
        b = str(self.root / "briefs" / "w1.md")
        self.brief(GOOD.replace("{root}/out/w1.md", b))
        code, out, _ = self.lint(b)
        self.assertEqual(code, 1)
        self.assertTrue(self.findings(out, "path-clash"), out)

    def test_two_briefs_share_a_return_path(self):
        a = self.brief(GOOD, "w1.md")
        b = self.brief(GOOD.replace("W1", "W2"), "w2.md")
        code, out, _ = self.lint(a, b)
        self.assertEqual(code, 1)
        self.assertTrue(self.findings(out, "path-clash"), out)

    def test_done_when_names_a_different_result_file(self):
        (self.root / "queue-results").mkdir()
        b = self.brief(GOOD.replace("Acceptance: the result", "Done when: queue-results/q42.md")
                       .replace("{root}/out/w1.md", "{root}/queue-results/20260922-230132-long-id.md"))
        code, out, _ = self.lint(b)
        f = self.findings(out, "path-clash")
        self.assertTrue(f and "q42.md" in f[0], out)


class Sections(LintCase):
    def test_missing_acceptance(self):
        code, out, _ = self.lint(self.brief(GOOD.replace("Acceptance:", "Notes:")))
        self.assertEqual(code, 1)
        self.assertTrue(self.findings(out, "no-acceptance"), out)

    def test_done_when_label_counts(self):
        t = GOOD.replace("Acceptance:", "**Done when (ESCROWED INTENT - the verifier checks against THIS):**")
        self.assertEqual(self.lint(self.brief(t))[0], 0)

    def test_missing_write_scope(self):
        code, out, _ = self.lint(self.brief(GOOD.replace(
            "Write scope: read-only apart from the report and {root}/scratch/w1/.\n", "")))
        self.assertEqual(code, 1)
        self.assertTrue(self.findings(out, "no-write-scope"), out)

    def test_other_write_scope_forms_count(self):
        for line in ("Own: skills/x/SKILL.md, skills/x/scripts/\n", "You are read-only.\n",
                     "**Guardrails:** headless; no file writes outside {root}/scratch/.\n"):
            t = GOOD.replace("Write scope: read-only apart from the report and {root}/scratch/w1/.\n", line)
            code, out, _ = self.lint(self.brief(t))
            self.assertEqual(self.findings(out, "no-write-scope"), [], line + out)

    def test_done_when_output_outside_write_scope(self):
        # Regression: the Done-when needs a file the write line forbids.
        t = GOOD.replace("Write scope: read-only apart from the report and {root}/scratch/w1/.",
                         "**Guardrails:** no file writes outside {root}/scratch/.")
        t = t.replace("Acceptance: the result", "Done when: {root}/elsewhere/x.csv exists and the result")
        code, out, _ = self.lint(self.brief(t))
        f = self.findings(out, "outside-write-scope")
        self.assertEqual(code, 1)
        self.assertTrue(f and "elsewhere/x.csv" in f[0], out)


class WriteTargets(LintCase):
    """Regression: a Done-when naming a path with a space only to prune it was bounced, because
    the lint had cut the path at its space."""

    def scoped(self, done):
        t = GOOD.replace("Write scope: read-only apart from the report and {root}/scratch/w1/.",
                         "**Guardrails:** no file writes outside {root}/scratch/.")
        return self.brief(t.replace("Acceptance: the result", done + "; and the result"))

    def test_a_path_named_to_prune_exclude_read_or_delete_is_not_a_write(self):
        for done in ("**Done when (ESCROWED INTENT - the verifier checks against THIS):** a PR whose guard makes "
                     "find/du over ~ prune '{root}/Mobile Documents', '{root}/Desk top' and '*.logicx'",
                     "Done when: the walk excludes {root}/Mobile Documents/ and adds nothing",
                     "Done when: the worker reads {root}/elsewhere/in.csv",
                     "Done when: the guard deletes {root}/elsewhere/stale.lock",
                     "Done when: the worker never writes {root}/elsewhere/x.csv",
                     "Done when: it reads {root}/elsewhere/x.csv if {root}/elsewhere/x.csv exists"):
            code, out, _ = self.lint(self.scoped(done))
            self.assertEqual(self.findings(out, "outside-write-scope"), [], done + "\n" + out)
            self.assertEqual(code, 0, done + "\n" + out)

    def test_a_write_target_outside_the_scope_still_fires(self):
        for done, name in (("Done when: the worker writes '{root}/elsewhere/My Report.md'", "elsewhere/My Report.md"),
                           ("Done when: {root}/elsewhere/x.csv is created", "elsewhere/x.csv"),
                           ("Done when: a single file at {root}/elsewhere/q1.md containing the answer", "elsewhere/q1.md"),
                           ("Done when: the flights table is in {root}/elsewhere/flights.md", "elsewhere/flights.md"),
                           ("Done when: the guard prunes {root}/Mobile Documents and saves its log to "
                            "{root}/elsewhere/prune.log", "elsewhere/prune.log")):
            code, out, _ = self.lint(self.scoped(done))
            f = self.findings(out, "outside-write-scope")
            self.assertEqual(code, 1, done + "\n" + out)
            self.assertTrue(len(f) == 1 and f[0].endswith(name + ", which no write-scope path covers"), done + "\n" + out)

    def test_a_space_bearing_path_is_one_token(self):
        (self.root / "Mobile Documents" / "com~apple~CloudDocs").mkdir(parents=True)
        t = GOOD + "Read {root}/Mobile Documents/com~apple~CloudDocs and `{root}/Mobile Documents`, not {root}/Mobile Documents.\n"
        code, out, _ = self.lint(self.brief(t))
        self.assertEqual(code, 0, out)  # none is cut at the space into a dead {root}/Mobile


class ReplayRegressions(LintCase):
    """False positives found replaying real briefs."""

    def test_an_input_named_on_the_deliverable_line_is_not_a_return_path(self):
        (self.root / "fin").mkdir()
        (self.root / "fin" / "STATUS.md").write_text("x\n")
        t = GOOD.replace("Return: {root}/out/w1.md", "**Deliverable:** a complete result at {root}/out/w1.md; "
                         "for money, first read ({root}/fin/STATUS.md)")
        a = self.brief(t, "w1.md")
        b = self.brief(t.replace("out/w1.md", "out/w2.md"), "w2.md")
        code, out, _ = self.lint(a, b)
        self.assertEqual(code, 0, out)

    def test_return_without_a_colon_and_words_with_slashes(self):
        t = GOOD.replace("Return: {root}/out/w1.md (write it there; if you cannot, return it inline).",
                         "Return {root}/out/new/w1.md; scratch in {root}/scratch/w1/. Resolve names with ls/grep.")
        code, out, _ = self.lint(self.brief(t))
        self.assertEqual(code, 0, out)
        b = self.brief(t, "w2.md")
        code, out, _ = self.lint(str(self.root / "briefs" / "w1.md"), b)
        self.assertTrue(self.findings(out, "path-clash"), out)  # both return to out/new/w1.md

    def test_a_title_or_an_acceptance_owner_is_not_a_section(self):
        t = ("# W1: the lint writes findings\nAcceptance owner: the coordinator.\n"
             + GOOD.split("\n", 1)[1].replace("Acceptance: the result states the count and quotes each definition line.\n", "")
             .replace("Write scope: read-only apart from the report and {root}/scratch/w1/.\n", "Replay it on real transcripts (read-only) for a past window.\n- D. Read-only replay: the last 7 days.\n"))
        code, out, _ = self.lint(self.brief(t))
        self.assertTrue(self.findings(out, "no-acceptance"), out)
        self.assertTrue(self.findings(out, "no-write-scope"), out)

    def test_quote_matches_through_markdown_emphasis(self):
        (self.root / "src" / "notes.md").write_text("a\nHarness gaps 56 distinct, **none recurring ≥2×** — no card\n")
        t = GOOD + "{root}/src/notes.md:2 \"56 distinct, none recurring ≥2× — no card\"\n"
        code, out, _ = self.lint(self.brief(t))
        self.assertEqual(code, 0, out)

    def test_shared_reading_after_the_word_return_is_not_a_return_path(self):
        t = GOOD.replace("Inputs:", "Read first: {root}/src/plan.md (authority, ownership, return), {root}/src/widgets.py. Inputs:")
        (self.root / "src" / "plan.md").write_text("x\n")
        a = self.brief(t, "w1.md")
        b = self.brief(t.replace("out/w1.md", "out/w2.md"), "w2.md")
        code, out, _ = self.lint(a, b)
        self.assertEqual(code, 0, out)

    def test_long_field_labels_and_paths_under_a_new_directory(self):
        t = GOOD.replace("Write scope: read-only apart from the report and {root}/scratch/w1/.",
                         "Your owned files (resolve each short name to its filename with ls/grep; report any you can't): "
                         "src/widgets.py") + ("1. New skill `skills/wb/SKILL.md`.\n2. A lint beside it, at `skills/wb/scripts/`.\n"
                                             "If `{root}/future/lint.py` exists, run it by path.\n")
        (self.root / "skills").mkdir()
        code, out, _ = self.lint("--base", str(self.root), self.brief(t))
        self.assertEqual(code, 0, out)


class ReviewFixes(LintCase):
    """Cases from reviewing the diff before submission."""

    def test_unreadable_cited_file_is_not_judged_and_does_not_crash(self):
        p = self.root / "src" / "locked.py"
        p.write_text("x\n")
        p.chmod(0)
        try:
            code, out, err = self.lint(self.brief(GOOD + "{root}/src/locked.py:1 `something here`\n"))
        finally:
            p.chmod(0o644)
        self.assertEqual(code, 0, out + err)

    def test_an_output_named_again_later_is_not_dead(self):
        t = GOOD + "Write {root}/out/table.md. Then check that {root}/out/table.md has three rows.\n"
        self.assertEqual(self.lint(self.brief(t))[0], 0)

    def test_abbreviated_line_range(self):
        t = GOOD + "{root}/src/widgets.py:10-1 `return 2`\n"  # read as 10-11, like ":1644-45"
        code, out, _ = self.lint(self.brief(t))
        self.assertEqual(code, 0, out)

    def test_existing_sibling_named_in_the_acceptance_is_not_a_clash(self):
        (self.root / "out" / "w0.md").write_text("x\n")
        t = GOOD.replace("Acceptance: the result", "Acceptance: {root}/out/w0.md is untouched and the result")
        code, out, _ = self.lint(self.brief(t))
        self.assertEqual(code, 0, out)


if __name__ == "__main__":
    unittest.main(verbosity=1)
