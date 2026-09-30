---
name: close-out
description: Finish a piece of work, or pause it, so the result is delivered with honest evidence and the next session can pick up without re-reading everything. Use when the user says wrap up, close out, finish up, park this, hand over, pick this up later, or signals they are leaving ("heading off", "that's it for today"); when a long task completes; or before a context reset. Separates changed, tested, committed and deployed; leaves one verified next step; turns a lesson the work actually demonstrated into a fix in the right place (CLAUDE.md, a skill, a script) rather than a diary entry. For a small task, two lines is a complete close-out.
license: MIT
---

# Close out

Leave the user with the result, an honest account of what backs it, and a next step a fresh session can act on. Improve the workflow only where this work showed a real, repeatable defect.

## Deliver first

Put the deliverable and its decisive evidence where they belong, and tell the user the outcome, before any retrospective. Loading more skills, re-reading a long transcript or tidying up must never cost the delivery of finished work.

A close-out certifies what was done. It starts no new builds and pitches no new ideas. Keep the report under about 200 words unless a full account was asked for. For a small task: the output, what was checked, any limitation. "Nothing to change in the workflow" is a complete retrospective.

## Say exactly what is true

Keep these separate, in the report and in any notes: **changed, tested, committed, deployed, observed working.** A verified fix can be uncommitted; a committed fix can be missing from the running app.

Before claiming done, check that the artefact exists and opens, that a reported number describes the thing measured, and that an app result came from the final delivered surface and the state after the action, not from a process that exited 0. Name mocks, skipped checks and anything not measured. "Not measured" stays "not measured"; don't upgrade it to "passed" to finish.

For multi-worker runs, use the worker returns and the integration record (see **fanout-brief**). A summary cannot override a failed check or a missing file.

If this work measured a fact that a maintained record states (a version, a count, a status in a README or CLAUDE.md), and the record is now wrong, fix it or leave the exact correction. A truthful final message shouldn't leave a known-false note behind.

## Leave one next step

If work continues, write the next step down *before* writing the report, so an interrupted close-out still leaves it: one bounded task, its owner, what "done" looks like, and the first verified pointer (a file, a command you actually ran, a failing test). "Continue testing" is not a next step; "combine the two tested branches and check one correct booking through the combined app" is. [Handover](references/handover.md) covers what a good continuation note contains when the work spans sessions.

## Fix the lesson where it lives

Look at real friction and corrections from this work, with their evidence, and route each to the thing that caused it:

| What went wrong | Where the fix goes |
|---|---|
| A skill didn't load when it should have | Its `description:` line (the only part Claude sees before choosing), after checking it is installed and enabled |
| A skill loaded but steered wrong | The instruction in that skill that caused it |
| A stale fact misled the work | The note, README or CLAUDE.md line that holds it |
| The agent lacked a capability or kept ignoring an instruction | The tool, its inputs or a deterministic check, not another emphatic sentence |
| A check passed when it shouldn't have (or the reverse) | The test, fixture or check itself |
| A repeated manual procedure | An existing script, or a new one if it will be reused, with a test |
| Specific to this project | The project's own notes, not a global rule |
| Nothing reusable | Drop it |

Write each lesson as one line: the lesson, where it now lives, and what would show it failed. A lesson with no home is dropped, not listed. Prefer replacing wrong guidance over adding more; skill and CLAUDE.md files are working instructions, not changelogs. One odd result is not yet a rule.

## Leave things tidy

Review any code you changed (**review-changes**). Give helper scripts and fixtures that someone will need again a proper home and a one-line note on how to run them; leave throwaway experiments as throwaway. Stop processes and free ports or worktrees this session started once nothing depends on them, and say what is left running and why.

Don't stage other people's work. Commits, pushes, sends and deletions still need the user's existing permission; being technically ready grants none. If nothing more is needed, stop. A bigger improvement you noticed can be named as a next task; don't start it.

## Report

Lead with the usable result and its evidence, then the limits or the next owner and step, then any permanent fix actually made. Keep proposed, staged and installed changes distinct, and leave out empty sections.
