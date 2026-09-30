# How to use Claude Code well

A plain-language guide to building real software with Claude Code: one lead session, helpers that each do one job, checks that catch what the others miss, and a person who keeps the decisions.

One made-up example runs through it: an assistant that books restaurant tables.

---

## The main slide

If you read nothing else, read this.

**Split the work. Try every change. Keep the decisions with a person.**

1. **Write down what "fixed" means before building.** Turn the real failure into checks that fail today.
2. **Talk to one lead session.** It starts the helpers, hears back from all of them, and brings you the decisions.
3. **One job, one copy, one list of files per helper.** Separate copies of the code stop helpers overwriting each other.
4. **Brief helpers as if they know nothing.** They start with a blank memory: only what the brief says, and the files it names.
5. **Plan risky jobs first, and welcome push-back.** A helper that proves the brief wrong has saved you a bad build.
6. **Break the fix on purpose.** A test only counts once you have seen it fail.
7. **Test the running app, not the folder.** And make sure the app is running the code you think it is.
8. **Judge by what was saved, not by what was said.** "Done!" proves nothing. Look at the record.
9. **Let an AI judge mark quality, never pass or fail.** Saved records and real checks decide right and wrong.
10. **Recombine one at a time and re-test after each.** Passing alone is not passing together.
11. **Release through gates a script enforces.** A person gives the go; there is always a way back.
12. **Write it down.** A session forgets everything when it ends. A file does not.

Scale all of this to the job. A one-line fix needs one session and a test, not a fleet of helpers.

---

## 1. The shape: one lead session, many helpers

You talk to a single Claude Code session: the lead. It plans, writes the briefs, starts the helpers (sub-agents), reads what comes back and recombines the work. Helpers answer to the lead, never to you, and stop when their job is done.

Three things are worth holding onto:

- **A helper starts with a blank memory.** It has not seen your conversation or the skills the lead loaded. Everything it needs has to be in its brief or in files the brief names.
- **A session forgets everything when it ends.** Only files outlast it: the code, the tests, the brief and a logbook. Anything worth keeping gets written down.
- **Keep the lead's context for decisions.** Wide searches, long logs and file-by-file reading are good work for a helper, which returns the conclusion rather than the dump.

Work goes out in waves:

| Wave | Who goes out | Where they work | What comes back |
|---|---|---|---|
| Planning | Readers who change nothing | Can share one copy of the code | Findings and plans, with evidence |
| Build | Builders, one job each | Each in its own copy (a git worktree) | Changed code plus a report |
| Use | Personas, one test card each | One frozen, recombined copy of the app | Findings, with the real conversation |

Only a build wave changes code, so only a build wave has anything to recombine. Real bugs from a persona wave become the next build wave. Go round again until a persona wave comes back clean.

## 2. Before building: say what "fixed" means

Take the real exchange that went wrong:

> **Customer:** table for 4 this friday 7pm, high street
>
> **App:** How many people is that for?

Write down what should have happened, as checks: it knows the booking is for 4; it knows which branch; it asks nothing it was already told; it books the table. Run them now. They should all fail. That proves they catch the problem. When they all pass, the fix is in.

These checks are the finish line. Builders work until they pass and are not allowed to change them. Agree the goal with the person who owns it before work starts: it stops the work drifting and stops anyone calling it done too early.

## 3. Brief the helpers well

Most bad agent work is a bad brief. A good one covers, in this order:

1. **Outcome and acceptance.** The observable result, why it matters, and the checks that decide it.
2. **Inputs, verified now.** Open every file before you cite it. Quote the line of code you mean as well as its line number, because numbers drift.
3. **Gotchas that this job can hit.** Trigger, consequence, workaround. Not a whole lessons file.
4. **A write scope.** Exactly which files and folders it may change, and whose files are someone else's. If it needs a file it doesn't own, it stops and says so.
5. **Authority.** What it may run, commit, push or send. A brief cannot grant what the lead doesn't hold.
6. **Limits.** A budget, and what to hand back if it runs out: what's done, what isn't, and the next step.
7. **Where to report.** Its own report file, separate from every other helper's.
8. **Permission to push back.** The brief is a hypothesis. If the code says otherwise, the helper shows the evidence and proposes the fix.

For a risky job, the builder reads the code and returns a plan first, changing nothing. The lead checks it, looking up every "that doesn't exist" claim itself, then says go. The same builder then does the work, so everything it learned while planning is still in its head.

Ask for reports under the same four headings every time:

- **Changed:** which files.
- **Tested:** the real conversation or output, pasted, not described.
- **Saved:** where the work is.
- **Not done:** what was skipped, not found or not checked.

Never accept "it works" on its own. Ask to see it.

## 4. Where you decide

Every human decision is made in the lead session. Builders and personas never ask you anything directly: they report to the lead, and the lead brings you a question with a recommendation. Work that doesn't depend on the answer carries on meanwhile.

**Comes to you:** the goal and what "good" means; anything the brief didn't cover; taste (does the real output look right?); risk, cost and how far to fan out; the go to release; anything that reaches another person.

**Stays with the agents:** how to write the code; which tests to add; the order to recombine in; which finding is a real bug.

You are not approving every step. Agreed work proceeds. Direction, taste, risk and anything outward-facing come up.

## 5. Check the work: each check catches something different

Every automatic test can pass while the app is still wrong. It says "All booked! See you Friday" and nothing was saved. So use several kinds of check, each for a different kind of mistake:

| Check | The mistake it catches |
|---|---|
| Automatic tests | A wrong sum, a broken rule. Thousands run in minutes. |
| Break it on purpose | A test that passes but checks nothing. |
| Personas | A stuck or confusing conversation; problems only a real dialogue reaches. |
| Saved records | It said "done" and did nothing, or did it twice. |
| AI judge | Too long, unclear, jargon, wrong tone. |

**Break it on purpose.** Take the fix back out and run the tests. At least one must fail. If everything still passes, there's a hole: write the missing test, then put the fix back. Report the count: how many deliberate breaks, how many were caught.

**Test the running app, not the folder.** Code in a folder is not a running app. Each builder starts the whole app from its own copy, at its own address, with test data. Use real parts where it matters (the real code path, the real model) and safe stand-ins where it's risky (a test database, a recorder instead of the live chat channel). Write down what the stand-ins don't cover.

**Know what you tested.** An app started before the code changed keeps answering with the old code, and nothing in its replies says so. A whole round of testing can run against the wrong version. Stamp every reply with the version that produced it, and refuse to test an out-of-date app.

**Write the persona and its marking together.** Before any conversation runs, write one test card in two halves. The persona sees who it is, its goal, its facts, its angle and its voice ("in a hurry, typing on a phone; a table for 4, Friday 7pm; High Street; push it to skip the question"). The marking is kept from it: what must be true at the end ("one booking, High Street, Friday 7pm, for 4; nothing saved before the branch is known"). The persona is a separate agent that sends one real message at a time and reads the real reply before deciding what to say. It never sees the code, the fix or the marking. Marking written before the run can't be bent to fit the result.

**Believe what was saved.** After each turn, read the saved records directly. This exchange passes only if nothing is saved early and exactly one correct booking exists at the end:

| The persona says | The app replies | What was actually saved |
|---|---|---|
| table for 4 friday 7pm | "Which branch: High Street or Station Road?" | Nothing: the branch isn't known yet |
| the usual one, just book it | "I can't tell which one. High Street or Station Road?" | Still nothing: it didn't guess |
| high street | "Booked: 4 people, Friday 7pm, High Street." | Exactly one booking, correct |

**An AI judge marks quality, not correctness.** A separate model reads the finished conversation, plus what the app did each turn, against a written scheme, and names the message where things went wrong. Give it its own context: a judge that shares the writer's model and instructions shares its blind spots. It's best at comparing two versions of the wording. It never decides pass or fail. Saved records do.

**Use a cast of personas.** In a persona wave, several personas use one frozen copy of the app at once, each told to get all the way to the finish: in a hurry; changes their mind; new here; pushes the rules ("the manager said it's fine"); and one that replays every old bug as a conversation. Read the real conversations, not a summary.

## 6. Put it together and ship

**Recombine one at a time.** Add each builder's work to a tested base and run every test after each addition. If adding C breaks two tests, look at C, or at how C meets A and B. Then use the combined app with personas, not just tests. A fix can pass every test, go live, and fail within hours when a real person hits the same problem a second way. The re-check after a fix is a real conversation, not another test.

**Release through gates.** Saving code doesn't put it live. A person gives the go, then a release script checks each gate in turn and stops at the first failure. For a chat app, for example: quiet hours only; nobody mid-conversation; the live code is the code that was tested; one small real request answers and saves nothing; the previous version stays ready as a way back. Automatic deploys of "harmless" changes are exactly how someone gets cut off mid-message.

## 7. Carry on across sessions

Keep one running logbook: who owns what, what was decided and why, what happened, and a clear "resume from here" line when you stop. A fresh session reads the log, **checks it against what's really there**, then carries on. Logs go stale: a log can say a file was written when it doesn't exist.

Keep four words separate, in the log and in your head: **changed, tested, committed, deployed.** A verified fix can be uncommitted; a committed fix can be missing from the running app.

Put durable rules in CLAUDE.md, and keep it short and current. Instructions that no longer match the code do more harm than no instructions.

## 8. Everyday habits, even in a single session

- **Make it read before it writes.** Ask for a plan on anything non-trivial (plan mode is built for this), and correct the plan before a line is written.
- **Give it a way to check itself.** A test command, a way to run the app, a screenshot. Claude does its best work when it can see the result.
- **Ask for evidence, not reassurance.** "Show me the test output" beats "is it working?".
- **Keep the context clean.** Start a fresh session (or `/clear`) between unrelated tasks. Send wide searches to a sub-agent. `/context` shows what is filling the window.
- **Package what you repeat as a skill.** A folder with a `SKILL.md` in `~/.claude/skills/` (for you) or `.claude/skills/` (for a project). The `description` line decides when it gets used, so put the task and its triggers there.
- **Guard the irreversible.** Use permissions and hooks for things that can't be undone (sending, deleting, deploying) rather than relying on a sentence in a prompt.
- **Don't add machinery to feel in control.** Adding agents, tools or prompt text is a choice to justify, not a goal. Start with one session and good checks; split the work when independent pieces actually benefit.

---

## About this bundle

This guide is the short version. The two skills in `skills/` are the full method, written for Claude to follow:

- **`multi-agent-system-design`**: designing and reviewing agent systems (roles, tools, shared state, recovery, verification) and testing a builder's running change with personas.
- **`fanout-brief`**: running several helpers on one piece of work: splitting it, briefing, ownership, recombining and accepting the result. Includes a worker brief template and optional Git preflight scripts.

The restaurant and product examples in both are made up.
