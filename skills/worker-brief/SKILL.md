---
name: worker-brief
description: Write the brief for a subagent, background agent or headless Claude session so it can succeed with no memory of this conversation, then lint it before dispatch. Use whenever you delegate — spawning an Agent or Task call, handing a job to a subagent, writing a prompt for another agent or session, queueing work for later, or re-briefing a worker whose first attempt missed. Covers acceptance first, inputs checked now, gotchas, write scope, authority, budget and partial returns, a separate report path, and permission to push back. For several workers on one job, use fanout-brief as well.
---

# Worker brief

A worker starts with the brief and the files it names. It has not seen this conversation, the skills you loaded, or the dead ends you already ruled out. Most bad delegated work traces back to a brief that assumed otherwise.

Scale the brief to the job. A read-only lookup needs three lines: the question, where to look, what to return. A worker that edits code in parallel with others needs every field below. The fields are a checklist, not a form to fill.

## Write it in this order

1. **Outcome and acceptance first.** One observable result and why it matters, then what decides it: checks that fail today and must pass, or for research, the questions to answer or mark unresolved. Name effects that must not happen ("no emails sent", "no rows written outside the test schema"). Without this the worker decides for itself when it is done, and it will decide early.

2. **Inputs, checked now.** Open every file before citing it; a moved file reaches the worker as "nothing found", not as an error. Cite code as `path:line` plus the text on that line in backticks, because line numbers drift and the text is how the worker re-finds it. Pin the base (a commit, or the time of a snapshot). Hand over evidence paths, not your summary of them, and mark causes as hypotheses until tested.

3. **Gotchas as trigger → consequence → workaround.** Only those this task can hit. For example: "`make reset-db` wipes the shared test database → other workers' fixtures vanish → use `TEST_DB=w2 make test`." Never paste a whole lessons file.

4. **A write scope derived from the task.** List what this worker may change: every path its acceptance needs, plus its own scratch directory. Say what wins when rules meet. Name the neighbours whose files are not its own. If read-only, say so. A generic "write only under /tmp" that the acceptance contradicts forces the worker to break one rule or the other.

5. **Effects and authority.** What it may run, commit, push, send or publish, and what stays with you or the user. A brief cannot grant what the delegator does not hold.

6. **A budget, and what to return when it runs out.** Tool calls, time or attempts, plus the partial return: what is done, what is not, the next step. A worker without a budget either stops too soon or burns the session.

7. **A report path apart from the brief.** An owned path, different from the brief's own and from every sibling's. If writing it fails, the worker returns the whole report inline. Give each worker its own scratch directory; shared scratch makes proof files unattributable.

8. **Permission to push back.** The brief is a hypothesis and the worker is the one testing it. When a claim is wrong, the worker names it, shows the evidence, proposes the fix and carries on with what still holds. Routine choices inside the write scope are its own to make.

Ask for the report under fixed headings so returns are comparable: **Changed** (files), **Tested** (the real output, pasted, not described), **Saved** (where the work is), **Not done** (skipped, not found, not checked). "It works" on its own is not a report.

For a risky change, ask the worker to read the code and return a plan first, changing nothing. Check any "that doesn't exist" claim yourself, then send the same worker to build, so what it learned while planning is still in its context.

[references/worker-prompt-template.md](references/worker-prompt-template.md) lays the fields out in order, with a filled example.

## Lint it before dispatch

```bash
python3 scripts/brief_lint.py [--base DIR]... BRIEF [BRIEF...]   # '-' reads stdin
```

Run it from this skill's directory (or give its full path). It prints one `<brief>: <check>: <detail>` line per finding, then a count. Exit 0 is clean, 1 means findings, 2 means it could not judge (usage error, unreadable brief), so a caller never bounces work on a lint bug. It checks:

- `dead-path`: a cited path that does not exist, unless the brief asks for it to be created;
- `drifted-line-ref`: quoted text that is not at its cited line;
- `path-clash`: a report path that is a brief's own path or a sibling's;
- `no-acceptance` and `no-write-scope`;
- `outside-write-scope`: the acceptance needs a file the write scope excludes.

Relative paths are judged only under the `--base` directories you pass. Lint sibling briefs in one call so shared report paths show up. The lint reads paths and labels, not meaning: a brief can pass it and still ask the impossible, so read it once as the worker will before you send it.
