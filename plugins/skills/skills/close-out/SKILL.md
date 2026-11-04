---
name: close-out
description: Finish or pause a piece of work so the result is delivered with honest evidence, the setup gets better from what this session ran into, and the session ends instead of piling up. Use when the user says close out, fully close out, wrap up, finish up, park this, hand over, pick this up later, close this session, or signals they are leaving ("heading off", "that's it for today"); when a coordinating session asks this one to close out; when a long task completes; or before a context reset. Reads which kind of close-out was asked for (park now, close out, or finish everything first), separates changed, tested, committed and deployed, puts anything the user must do first in plain words, leaves one verified next step, and looks back on what the setup could do better. For a small task, two lines is a complete close-out.
license: MIT
---

# Close out

Leave the user with the result, an honest account of what backs it, and a next step a fresh session can act on. Then look back on what the setup around this session could do better, so the next one is more effective, and end the session.

## Read which close-out was asked for

The words decide how much work happens before the report. Get this wrong and the user either has to stop you doing work they deferred, or has to ask again for work you offered instead of finishing.

| They said | Do |
|---|---|
| "for now", "later", "leave this", "park", "I'm not doing this now" | **Park.** Start nothing new, including work you had just offered. Make in-flight work safe (saved, committed if that is already authorized, nothing half-written), record every deferred step, each as its own entry, where the next session or the user's queue will find it, and report in a few lines. |
| "close out", "wrap up", "/close-out" | **Close out.** Deliver, record, report. |
| "fully", "close out fully", "do all the relevant things and close out" | **Finish first.** Complete every remaining step the user's standing permission already covers (commit, push, merge through the project's review path, update the records this work changed) so the report holds results, not offers. Finishing means the steps this work already identified, not a new sweep or investigation. Stop only at steps that need a fresh yes, and ask those questions in this report, batched, while the user is here. |

Combined ("just close out for now fully"): no new work, but finish the state and records. A question or status check mid-work ("how's it going?") is not a close-out; answer it.

## Deliver first

Put the deliverable and its decisive evidence where they belong, and tell the user the outcome, before any retrospective. Loading more skills, re-reading a long transcript or tidying up must never cost the delivery of finished work.

A close-out certifies what was done. It starts no new builds and pitches no new ideas. For a small task: the output, what was checked, any limitation. "Nothing to change in the workflow" is a complete retrospective.

## Say exactly what is true

Keep these separate, in the report and in any notes: **changed, tested, committed, deployed, observed working.** A verified fix can be uncommitted; a committed fix can be missing from the running app. A command you issued but whose result you have not read is started, not done; finishing first never licenses reporting an outcome you did not see.

Before claiming done, check that the artefact exists and opens, that a reported number describes the thing measured, and that an app result came from the final delivered surface and the state after the action, not from a process that exited 0. Name mocks, skipped checks and anything not measured. "Not measured" stays "not measured"; don't upgrade it to "passed" to finish.

If the user corrected a fact during the session (a name, a date, an amount, "that's already done"), the close-out applies it to the record that holds it and drops anything built on the old version. Don't carry a corrected item into the report or the next step.

For multi-worker runs, use the worker returns and the integration record (see **fanout-brief**). A summary cannot override a failed check or a missing file. If this work measured a fact that a maintained record states and the record is now wrong, fix it or leave the exact correction.

## Leave one next step

If work continues, record the next step in the project's task or handoff file *before* writing the report (a sentence in the chat is not a record), so an interrupted close-out still leaves it: one bounded task, its owner, what "done" looks like, and the first verified pointer (a file, a command you actually ran, a failing test). "Continue testing" is not a next step; "combine the two tested branches and check one correct booking through the combined app" is. [Handover](references/handover.md) covers a continuation note for work that spans sessions.

A step you could do now under existing permission is not a next step: do it (park mode excepted). A step that waits on a date, another person or the user's own hands is recorded where they will be reminded, not only in the chat.

## Look back, then fix or log

Ask the question every close-out runs (park mode too, in one line): **was there anything here we could have done better, and what change to the setup around this session (skills, tools, integrations, permissions, the context it started with, hand-over notes) would make the next session like it more effective?** Think broadly, including changes that would make this kind of session unnecessary. But tie every candidate to a moment in this session: a correction, a retry, a wrong turn, a slow manual step, a missing tool, a skill that didn't fire. A candidate with no such moment is an idea: log it as one, never act on it here. "Nothing to improve" is a normal, complete answer.

Why the split: acting on each session's own improvement ideas made agents worse in published tests (self-written skills and instruction files scored below no guidance at all), while capturing every time and acting on what recurs or was actually observed helped. So fix in this session only what is local and checkable now; log the rest where a later batch clusters it and acts on what recurs (an improvement log or backlog file the project already keeps). Never rewrite always-loaded instructions from one session's idea.

Route each fix to the thing that caused it, merging it into the existing rule or check for that kind of failure before adding a new one:

| What went wrong | Where the fix goes |
|---|---|
| A skill didn't load when it should have | Its `description:` line, after checking it is installed, enabled and listed with its description |
| A skill loaded but steered wrong | The instruction in that skill that caused it |
| A stale fact misled the work | The note, README or CLAUDE.md line that holds it |
| The agent lacked a capability or kept ignoring an instruction | The tool, its inputs or a deterministic check, not another emphatic sentence |
| A check passed when it shouldn't have (or the reverse) | The test, fixture or check itself |
| A repeated manual procedure | An existing script, or a new one if it will be reused, with a test |
| Specific to this project | The project's own notes, not a global rule |
| Nothing reusable | Drop it |

Write each lesson as one line: the lesson, where it now lives, and what would show it failed. A lesson with no home is logged for the batch, not listed. Prefer replacing wrong guidance over adding more. One odd result is not yet a rule.

## End the session

When the report is out and nothing is left in flight, end the session if the environment lets a session end itself (an archive or close command, for example), so finished sessions don't pile up. Don't end one that coordinates other sessions or is a long-running session meant to stay open, one the user asked to keep, or one with uncommitted or running work. In park mode, end it too once the next step is recorded, unless the user said they will come back to this conversation.

## Leave things tidy

Review any code you changed (**review-changes**). Give helper scripts someone will need again a proper home and a one-line note on how to run them. Stop processes and free ports or worktrees this session started once nothing depends on them. For anything left running, say who owns it and whether it stops when this session ends. Don't stage other people's work. Sends, deletions and anything outward still need a yes; being technically ready grants none.

## Report

Write for someone who was not watching the session and will read it once. For a small task, or when the user is confirming that something worked, reply in two or three lines with no headings: acknowledge it, and name any consequence still open. Otherwise:

1. **The outcome in one or two sentences**, in plain words: what now works, exists or is decided.
2. **What the user must do, if anything**: a numbered list of at most five, each one action with where and by when ("sign the form in your Downloads folder by Friday"). Only steps that need them: their hands, a send, money, a decision that is theirs. Leave it out entirely when there are none.
3. **What backs it and what doesn't**: the evidence, the limits, what is still running.
4. **The next step** and who owns it, then any permanent fix actually made.
5. **What the look-back changed**, in one line: fixed now, logged for the batch, or nothing.

Keep it under about 200 words unless a full account was asked for. Use the user's words for things, not internal ids, branch names, card numbers or tool jargon; if a term is unavoidable, say what it is in the same sentence. No asides or "insight" boxes. End on the result or the next step, never on an offer ("want me to…?", "say the word"): if it is yours to do, it is done or recorded; if it needs them, it is in item 2.
