#!/usr/bin/env python3
"""Regression fixtures for preflight and scope ownership; creates only temporary Git repositories."""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPTS = Path(__file__).resolve().parent
SOURCE = "def first():\n    return 1\n\n\ndef second():\n    return 10\n"


class Gates(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="fanout-regression-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "repo with spaces"
        self.repo.mkdir()
        self.env = os.environ.copy()
        shim = self.root / "bin"
        shim.mkdir()
        (shim / "gh").write_text("#!/bin/sh\nexit 3\n")
        (shim / "gh").chmod(0o755)
        self.env["PATH"] = str(shim) + os.pathsep + self.env["PATH"]
        self.env["GIT_CONFIG_GLOBAL"] = os.devnull
        self.env["GIT_CONFIG_SYSTEM"] = os.devnull
        self.git("init", "-b", "main")
        self.git("config", "user.name", "Gate fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        (self.repo / "source.py").write_text(SOURCE)
        (self.repo / ".gitignore").write_text("ignored.txt\n")
        self.git("add", "source.py", ".gitignore")
        self.git("commit", "-m", "fixture baseline")
        self.base = self.git("rev-parse", "HEAD").strip()
        self.map_path = self.root / "scope.json"

    def git(self, *args, tree=None):
        result = subprocess.run(["git", "-C", str(tree or self.repo), *args], env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result.stdout

    def run_gate(self, args, expected, tree=None):
        result = subprocess.run(args, cwd=tree or self.repo, env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result.stdout

    def preflight(self, *args, expected=0, tree=None):
        return self.run_gate(["bash", str(SCRIPTS / "fanout-preflight.sh"), str(tree or self.repo), *args], expected)

    def commit(self, paths, message="fixture change", tree=None):
        self.git("add", "--", *paths, tree=tree)
        self.git("commit", "-m", message, tree=tree)

    def scope(self, rows, expected=0, extra=(), base=None):
        self.map_path.write_text(json.dumps({"worker": rows}) + "\n")
        return self.run_gate([sys.executable, str(SCRIPTS / "scope_check.py"), "worker", "HEAD", "--base", base or self.base, "--map", str(self.map_path), *extra], expected)

    def test_silent_failure_is_not_a_baseline(self):
        output = self.preflight("--test", "false", expected=1)
        self.assertIn("exit=1", output)
        self.assertNotIn("CHECKS PASSED", output)

    def test_pipeline_status_cannot_hide_failure(self):
        self.preflight("--test", "false | cat", expected=1)

    def test_usage_error_and_zero_collection_are_not_success(self):
        for code in (2, 3, 4, 5, 137):
            with self.subTest(code=code):
                self.preflight("--test", f"exit {code}", expected=1)

    def test_summary_words_are_not_a_verdict(self):
        output = self.preflight("--test", "printf '12 passed, 2 xfailed; FAILED is a fixture string\\n'", expected=0)
        self.assertIn("Exit 0 means command completed", output)

    def test_unmeasured_is_explicit(self):
        output = self.preflight()
        self.assertIn("NOT_MEASURED", output)
        self.assertNotIn("safe to dispatch", output)

    def test_explicit_empty_baseline_is_unknown(self):
        self.preflight("--test", "", expected=1)

    def test_dirty_current_tree_fails_closeout(self):
        (self.repo / "source.py").write_text(SOURCE + "# pending\n")
        self.preflight("--closeout", "--base", "HEAD", "--branches", "main", expected=1)

    def test_dirty_dispatch_does_not_run_baseline(self):
        (self.repo / "source.py").write_text(SOURCE + "# pending\n")
        output = self.preflight("--test", "touch would-run", expected=1)
        self.assertIn("NOT_RUN", output)
        self.assertFalse((self.repo / "would-run").exists())

    def test_exact_untracked_exception_does_not_hide_tracked_source(self):
        (self.repo / "uv.lock").write_text("generated\n")
        self.preflight(expected=1)
        self.preflight("--allow-untracked", "uv.lock")
        (self.repo / "source.py").write_text(SOURCE + "# tracked\n")
        self.preflight("--allow-untracked", "uv.lock", "source.py", expected=1)

    def test_untracked_exceptions_do_not_cover_neighbor_paths(self):
        (self.repo / "uv.lock.other").write_text("pending\n")
        self.preflight("--allow-untracked", "uv.lock", expected=1)

    def test_ignored_files_are_outside_the_claim(self):
        (self.repo / "ignored.txt").write_text("not a tracked input\n")
        output = self.preflight()
        self.assertIn("ignored files are outside this check", output)

    def test_worktree_spaces_and_selected_scope(self):
        selected = self.root / "selected lane with spaces"
        unrelated = self.root / "unrelated lane with spaces"
        self.git("worktree", "add", "-b", "selected", str(selected))
        self.git("worktree", "add", "-b", "unrelated", str(unrelated))
        (unrelated / "new.txt").write_text("unrelated\n")
        self.commit(["new.txt"], tree=unrelated)
        self.preflight("--closeout", "--branches", "selected")
        self.preflight("--closeout", expected=1)
        (selected / "source.py").write_text(SOURCE + "# worker uncommitted\n")
        self.preflight("--closeout", "--branches", "selected", expected=1)

    def test_branch_advanced_after_old_tip_was_integrated(self):
        worker = self.root / "worker"
        self.git("worktree", "add", "-b", "worker", str(worker))
        self.preflight("--closeout", "--branches", "worker")
        (worker / "late.txt").write_text("late result\n")
        self.commit(["late.txt"], tree=worker)
        self.preflight("--closeout", "--branches", "worker", expected=1)

    def test_invalid_git_inputs_are_not_empty_success(self):
        self.preflight("--closeout", "--branches", "missing-ref", expected=1)
        self.preflight("--closeout", "--worktrees", str(self.root), expected=1)
        self.preflight("--closeout", "--base", "missing-base", expected=1)
        self.preflight(tree=self.root, expected=1)

    def test_renamed_staged_file_is_still_dirty(self):
        self.git("mv", "source.py", "renamed file.py")
        self.preflight("--closeout", "--branches", "main", expected=1)

    def test_command_source_mutation_breaks_pin_claim(self):
        self.preflight("--test", "printf '# modified\\n' >> source.py", expected=1)

    def test_targets_citations_and_unavailable_prs(self):
        output = self.preflight("--targets", "source.py", "--cite", "source.py:1-2")
        self.assertIn("UNAVAILABLE", output)
        self.assertIn("existence only", output)
        self.preflight("--cite", "source.py:900", expected=1)
        self.preflight("--targets", "nonexistent", expected=1)

    def test_empty_or_malformed_scope_fails_before_empty_diff(self):
        for raw in ({}, {"worker": []}, {"worker": [["source.py", []]]}, {"worker": [["source.py", [[0, 4]]]]}):
            with self.subTest(raw=raw):
                self.map_path.write_text(json.dumps(raw))
                self.run_gate([sys.executable, str(SCRIPTS / "scope_check.py"), "worker", "HEAD", "--base", "HEAD", "--map", str(self.map_path)], 2)

    def test_scope_requires_map_and_base(self):
        self.run_gate([sys.executable, str(SCRIPTS / "scope_check.py"), "worker", "HEAD"], 2)

    def test_invalid_semantic_region_fails_even_without_changes(self):
        self.scope([["source.py", [{"symbol": "missing"}]]], expected=2)
        self.scope([["source.py", [[1, 999999]]]], expected=2)
        self.scope([["missing.py", [[1, "nextdef"]]]], expected=2)
        self.scope([["source.py", [{"symbol": "first"}]]])

    def test_legacy_pin_must_equal_actual_diff_base(self):
        (self.repo / "source.py").write_text(SOURCE.replace("return 1\n", "return 2\n"))
        self.commit(["source.py"])
        self.scope([["source.py", None]], expected=2, extra=("--pin", "HEAD"))

    def test_symbol_scope_checks_both_sides(self):
        (self.repo / "source.py").write_text(SOURCE.replace("return 1\n", "return 2\n"))
        self.commit(["source.py"])
        self.scope([["source.py", [{"symbol": "first"}]]])
        self.scope([["source.py", [[1, "nextdef"]]]])
        self.scope([["source.py", [{"symbol": "second"}]]], expected=1)

    def test_appended_sibling_is_outside_function_scope(self):
        (self.repo / "source.py").write_text(SOURCE + "\n\ndef third():\n    return 30\n")
        self.commit(["source.py"])
        self.scope([["source.py", [{"symbol": "second"}]]], expected=1)

    def test_added_deleted_and_renamed_files_need_full_coverage(self):
        self.git("mv", "source.py", "renamed.py")
        self.commit(["renamed.py"])
        self.scope([["source.py", None]], expected=1)
        self.scope([["source.py", None], ["renamed.py", None]])
        self.scope([["source.py", [[1, 2]]], ["renamed.py", None]], expected=2)

    def test_new_file_scope(self):
        (self.repo / "new.py").write_text("VALUE = 1\n")
        self.commit(["new.py"])
        self.scope([["source.py", None]], expected=1)
        self.scope([["new.py", None]])
        self.scope([["new.py", [[1, 1]]]], expected=2)

    def test_deleted_file_scope(self):
        self.git("rm", "source.py")
        self.git("commit", "-m", "fixture deletion")
        self.scope([["source.py", None]])
        self.scope([["source.py", [[1, 2]]]], expected=2)

    def test_mode_only_change_needs_whole_file_scope(self):
        (self.repo / "source.py").chmod(0o755)
        self.commit(["source.py"])
        self.scope([["source.py", [[1, 2]]]], expected=2)
        self.scope([["source.py", None]])

    def test_literal_diff_path_with_spaces(self):
        (self.repo / "a file with spaces.txt").write_text("owned\n")
        self.commit(["a file with spaces.txt"])
        self.scope([["a file with spaces.txt", None]])

    def test_target_globs_select_pinned_files(self):
        self.preflight("--targets", "*.py")
        self.preflight("--targets", "*.missing", expected=1)

    def test_deleted_registered_worktree_is_unknown(self):
        worker = self.root / "vanished worker"
        self.git("worktree", "add", "-b", "worker", str(worker))
        worker.rename(self.root / "moved worker")
        self.preflight("--closeout", "--branches", "worker", expected=1)

    def test_worktree_only_scope_checks_detached_head(self):
        worker = self.root / "detached worker"
        self.git("worktree", "add", "--detach", str(worker))
        self.preflight("--closeout", "--worktrees", str(worker))
        (worker / "new.txt").write_text("late\n")
        self.commit(["new.txt"], tree=worker)
        self.preflight("--closeout", "--worktrees", str(worker), expected=1)

    def test_binary_region_has_no_false_empty_hunk_success(self):
        (self.repo / "source.py").write_bytes(b"\0binary\0content\n")
        self.commit(["source.py"])
        self.scope([["source.py", [[1, 2]]]], expected=2)
        self.scope([["source.py", None]])

    def test_invalid_python_symbol_is_unknown(self):
        (self.repo / "source.py").write_text("def first(:\n    return 2\n")
        self.commit(["source.py"])
        self.scope([["source.py", [{"symbol": "first"}]]], expected=2)

    def test_ast_symbol_handles_methods_and_decorators(self):
        source = "class Example:\n    @staticmethod\n    def method():\n        return 1\n"
        (self.repo / "source.py").write_text(source)
        self.commit(["source.py"])
        base = self.git("rev-parse", "HEAD").strip()
        (self.repo / "source.py").write_text(source.replace("return 1", "return 2"))
        self.commit(["source.py"])
        self.scope([["source.py", [{"symbol": "Example.method"}]]], base=base)

    def test_git_magic_filename_cannot_redirect_hunks(self):
        for path in (":(literal)safe.py", "safe.py"):
            (self.repo / path).write_text(SOURCE)
        self.git("--literal-pathspecs", "add", "--", ":(literal)safe.py", "safe.py")
        self.git("commit", "-m", "fixture literal filenames")
        base = self.git("rev-parse", "HEAD").strip()
        (self.repo / ":(literal)safe.py").write_text(SOURCE.replace("return 10", "return 20"))
        (self.repo / "safe.py").write_text(SOURCE.replace("return 1\n", "return 2\n"))
        self.git("--literal-pathspecs", "add", "--", ":(literal)safe.py", "safe.py")
        self.git("commit", "-m", "fixture two different functions")
        self.scope([[":(literal)safe.py", [{"symbol": "first"}]], ["safe.py", None]], expected=1, base=base)
        self.scope([[":(literal)safe.py", [{"symbol": "second"}]], ["safe.py", None]], base=base)

    def test_bracket_filename_is_not_a_git_pattern(self):
        for path in ("x[ab].py", "xa.py"):
            (self.repo / path).write_text(SOURCE)
        self.git("--literal-pathspecs", "add", "--", "x[ab].py", "xa.py")
        self.git("commit", "-m", "fixture bracket filenames")
        base = self.git("rev-parse", "HEAD").strip()
        (self.repo / "x[ab].py").write_text(SOURCE.replace("return 1\n", "return 2\n"))
        (self.repo / "xa.py").write_text(SOURCE.replace("return 10", "return 20"))
        self.git("--literal-pathspecs", "add", "--", "x[ab].py", "xa.py")
        self.git("commit", "-m", "fixture bracket neighbor")
        self.scope([["x[ab].py", [{"symbol": "first"}]], ["xa.py", None]], base=base)
        self.scope([["x[ab].py", [{"symbol": "second"}]], ["xa.py", None]], expected=1, base=base)

    def test_subdirectory_relative_config_cannot_hide_root_change(self):
        nested = self.repo / "nested"
        nested.mkdir()
        self.git("config", "diff.relative", "true")
        (self.repo / "foreign.txt").write_text("unowned root change\n")
        self.commit(["foreign.txt"])
        self.map_path.write_text(json.dumps({"worker": [["source.py", None]]}))
        self.run_gate([sys.executable, str(SCRIPTS / "scope_check.py"), "worker", "HEAD", "--base", self.base, "--map", str(self.map_path)], 2, tree=nested)
        self.scope([["source.py", None]], expected=1)

    def test_submodule_config_cannot_hide_gitlink_change(self):
        self.git("update-index", "--add", "--cacheinfo", f"160000,{self.base},module")
        self.git("commit", "-m", "fixture gitlink")
        base = self.git("rev-parse", "HEAD").strip()
        self.git("update-index", "--cacheinfo", f"160000,{base},module")
        self.git("commit", "-m", "fixture changed gitlink")
        self.git("config", "diff.ignoreSubmodules", "all")
        self.scope([["source.py", None]], expected=1, base=base)
        self.scope([["module", None]], base=base)

    def test_submodule_config_cannot_hide_tracked_dirt(self):
        child = self.root / "child"
        child.mkdir()
        self.git("init", "-b", "main", tree=child)
        self.git("config", "user.name", "Gate fixture", tree=child)
        self.git("config", "user.email", "fixture@example.invalid", tree=child)
        (child / "child.txt").write_text("clean\n")
        self.commit(["child.txt"], tree=child)
        self.git("-c", "protocol.file.allow=always", "submodule", "add", str(child), "module")
        self.commit([".gitmodules", "module"])
        self.git("config", "diff.ignoreSubmodules", "all")
        self.git("config", "submodule.module.ignore", "all")
        (self.repo / "module/child.txt").write_text("dirty\n")
        self.preflight("--closeout", "--base", "HEAD", "--branches", "main", expected=1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
