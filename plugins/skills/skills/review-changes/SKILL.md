---
name: review-changes
description: Use this skill whenever someone asks you to review, check or look over a diff, pull request, patch, script or config change, however short, and before you call your own change ready. Reviews changed code, scripts or configuration — a diff, a pull request, the first working version of a feature, partial work being parked, a helper script whose output you are about to rely on, or several workers' changes combined. Use when asked to review, check or sanity-check a change, and on your own at those points during a build. Runs each new check against its whole input class, opens every caller and consumer the change touches, looks for other routes around a guard, compares the result with main, and reports only findings that matter, each with the input that reproduces it.
license: MIT
---

# Review changes

Review what will actually run: the diff plus the code around it and the configuration it uses. Whether the running app does its job for its user, and survives an attacker, is a separate and faster check: send the **test-crew** at it. Match depth to what the change can break. A local edit does not need an estate audit; a change to shared config may affect every job that reads it.

## Review at the points that matter

Do this without waiting to be asked, at these moments in a build:

- **First working version.** Check the changed path and its main failure case before building more on top. A passing happy path makes something reviewable, not ready.
- **Parking partial work.** Mark what is unfinished or unsafe to run and write down the next check, so nobody mistakes it for done.
- **Incidental scripts.** Review a helper before trusting its numbers, even when the real task is a report or an analysis. A wrong script produces a confident wrong answer.
- **Combined work.** After merging several changes, review the combination: reuse evidence for untouched parts, and exercise the interfaces the merge changed.
- **Before you submit your own change.** This is the review that most often gets skipped. An independent reviewer reading 201 machine-written pull requests blocked 91 of them that their authors had submitted as ready, with 471 blocking findings; the classes below are what it found.

These are checkpoints, not a review after every command.

## Investigate by running, not by reading

Read the diff, the status and any new files, then go after the defects independent review finds most, in this order. Each one is a thing to run, not a thing to reason about.

1. **Attack each new check across its input class** (about a third of the findings). For every matcher, guard, regex, parser or condition the diff adds or changes, name the inputs it must hold over and try them against the code: other spellings and casings; quoting; `--x=y` and `--x y`; glued and separate option values; a wrapper before the command (`env`, `sudo`, `timeout`, `xargs`); a second line; empty, whitespace-only, missing, huge and flag-shaped values; non-ASCII digits and lookalikes; path spellings (a symlink, `/private/var` and `/var`, relative, a trailing slash); several arguments where it handled one. Try over-matching too: an ordinary input the check now catches by mistake.
2. **Look for another route to the effect a guard prevents** (nearly a quarter). Name the effect, then the other ways to reach it: another command or tool, a copy or rename, a derived variable, another encoding, another file with the same role. A guard keyed on one spelling or one path has a way round it.
3. **Open every reader of what changed** (about 1 in 8). Any function, verb, flag, exit code, output line, field or class value, env var or file the diff changes has callers and consumers: `python3 ../code-writing/scripts/consumers.py --base <ref>` lists candidates and marks callers that discard the status, where a new refusal or error disappears. Run each caller's real input through the new code. Two changes that are each valid can combine into a wrong meaning: a `parent_id` that means "derived from" in one path and "translated from" in another.
4. **Check the claims** (about 1 in 10). Hold each sentence of the title, PR body and comments against the code and the test output. "Every", "never" and a count are claims to grep or rerun, not to trust.
5. **Run it twice, together, late.** A second run, two at once, a run after a partial failure, a replay, state written by an older version, a newer head than the one reviewed.
6. **Make the evidence fail on main.** A test that passes on main as well as on the change proves nothing about the change. Run the new test against main's copy, or break the fix on purpose, and see it fail.

Also look at the boundaries every change has: what the changed path can read, log or send, and to whom; a way back for migrations, unattended scripts and shared config; and the real output (the file written, the row stored, the message actually sent) whenever the result depends on more than the source text. For shell scripts, check quoting, failures inside conditionals and `||` lists, pipelines (`set -o pipefail`), and macOS against Linux tools. Failure must never produce a success message; a guard that blocks an action must refuse when it can't verify.

## Decide what blocks

Keep finding separate from reporting: don't drop a plausible defect because it looks small before you have traced it to a trigger and a consequence. Then sort, comparing against main:

- **Blocking:** it makes things worse than main, or it breaks what the change itself claims, and you can name the exact input that reproduces it.
- **Worth fixing now:** a real defect, cheap to fix, in what the change touches.
- **Uncertain or out of scope:** a risk you could not reproduce, hardening, style, or something main already does (say so; it is not this change's defect).

Don't invent nits to look thorough, and don't present speculation as a confirmed bug.

## Removed behaviour and merged branches

A merge without conflicts proves the text fits, not the meaning. List the shared objects whose meaning changed on either side and test the combined case.

When removing a confirmation, question or human sign-off, find every place that produces it: prompts, tools, schemas and code. Searching for the known wording finds duplicates; paraphrases and other routes still need an outcome check. Confirm the final path no longer asks, and that any real permission boundary still holds.

When fixing a guard that always refused, review the code after it as newly reachable. The guard may have been hiding the next bug.

## Verify in proportion

Run the project's relevant checks and look at the intended artefact. A syntax check cannot prove what a shell script does; a green process cannot prove a file was written. For agent behaviour, use the running-app checks in **multi-agent-system-design**. Reuse evidence for unchanged inputs, rerun what the change invalidated, and name what you skipped and what that leaves unknown.

## Report

Lead with whether it is ready and any blocking defect, in words the person who asked can act on. Each finding gets: where (file and line), the input that triggers it, the wrong result, what main does with the same input, and the evidence or an honest uncertainty. Skip empty sections and diff recitals. Fix what is in scope; a review being positive does not by itself authorise committing, publishing or deploying.
