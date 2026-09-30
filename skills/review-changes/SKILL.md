---
name: review-changes
description: Use this skill whenever someone asks you to review, check or look over a diff, pull request, patch, script or config change, however short, and before you call your own change ready. Reviews changed code, scripts or configuration — a diff, a pull request, the first working version of a feature, partial work being parked, a helper script whose output you are about to rely on, or several workers' changes combined. Use when asked to review, check or sanity-check a change, and on your own at those points during a build. Traces each suspected defect to a concrete trigger and consequence, checks the producers and consumers a change touches, verifies the actual output, and reports only findings that matter, with evidence.
license: MIT
---

# Review changes

Review what will actually run: the diff plus the code around it and the configuration it uses. Match depth to what the change can break. A local edit does not need an estate audit; a change to shared config may affect every job that reads it.

## Review at the points that matter

Do this without waiting to be asked, at these moments in a build:

- **First working version.** Check the changed path and its main failure case before building more on top. A passing happy path makes something reviewable, not ready.
- **Parking partial work.** Mark what is unfinished or unsafe to run and write down the next check, so nobody mistakes it for done.
- **Incidental scripts.** Review a helper before trusting its numbers, even when the real task is a report or an analysis. A wrong script produces a confident wrong answer.
- **Combined work.** After merging several changes, review the combination: reuse evidence for untouched parts, and exercise the interfaces the merge changed.

These are checkpoints, not a review after every command.

## Investigate first, then decide what matters

Read the diff, the status and any new files. Keep finding separate from reporting: don't drop a plausible defect because it looks small before you have traced it to a trigger and a consequence. Then sort findings into blocking, worth fixing now, and uncertain or out of scope. Don't invent nits to look thorough, and don't present speculation as a confirmed bug.

Look at the boundaries the change actually touches:

- **Correctness:** missing input, retries, ordering, cancellation, and errors that can read as success (see **code-writing**, "The traps that report success").
- **Producers and consumers** of any changed field, flag, status value or config key. Two changes that are each valid can combine into a wrong meaning: a `parent_id` that means "derived from" in one path and "translated from" in another.
- **Data and secrets:** what the changed path can read, log or send, and to whom.
- **Recovery:** migrations, unattended scripts and shared config need a way back.
- **The real output:** the generated file, the stored row, the rendered page, the message actually sent, whenever the result depends on more than the source text.

For shell scripts, check quoting, command substitution, failures inside conditionals, pipelines (`set -o pipefail`), macOS vs Linux differences, and what happens when the script fails: failure must never produce a success message. A helper that adds optional context may skip what it can't find; a guard that blocks an action must refuse when it can't verify.

## Removed behaviour and merged branches

A merge without conflicts proves the text fits, not the meaning. List the shared objects whose meaning changed on either side and test the combined case.

When removing a confirmation, question or human sign-off, find every place that produces it: prompts, tools, schemas and code. Searching for the known wording finds duplicates; paraphrases and other routes still need an outcome check. Confirm the final path no longer asks, and that any real permission boundary still holds.

When fixing a guard that always refused, review the code after it as newly reachable. The guard may have been hiding the next bug.

## Verify in proportion

Run the project's relevant checks and look at the intended artefact. A syntax check cannot prove what a shell script does; a green process cannot prove a file was written. For agent behaviour, use the running-app checks in **multi-agent-system-design**. Reuse evidence for unchanged inputs, rerun what the change invalidated, and name what you skipped and what that leaves unknown.

## Report

Lead with whether it is ready and any blocking defect. Each finding gets a location, the trigger, the consequence, and the evidence or an honest uncertainty. Skip empty sections and diff recitals. Fix what is in scope; a review being positive does not by itself authorise committing, publishing or deploying.
