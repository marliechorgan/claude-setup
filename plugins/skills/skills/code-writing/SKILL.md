---
name: code-writing
description: Use this skill whenever you write, edit, fix or run code, scripts, shell one-liners or config, even small or quick ones. Habits for writing, changing, fixing, refactoring or reviewing code with fewer silent mistakes — think first, keep it simple, change only what the task needs, and prove the result by looking at what the code actually produced. Load it before the first line is written, including bug fixes, new features, guards, matchers and parsers, data reports, config changes, bulk find-and-replace, reviewing a diff and directing an AI agent to code. Includes a pre-submit pass aimed at what independent review most often finds (a matcher that misses real spellings, a guard with another route around it, a caller nobody opened, a claim the code does not meet) and the traps that make broken code report success. Use judgment on trivial one-liners.
license: MIT
---

# Code writing

Four habits cut most coding mistakes, human and AI alike. Then a pre-submit pass aimed at the defects independent review actually finds, and the traps that let broken code report success; those cost the most because nobody goes back to look.

## 1. Think before coding

- State your assumptions. If something is unclear, name what is confusing and ask before writing.
- If the request has several readings, lay them out rather than picking one silently.
- If a simpler approach exists, say so. Push back when it is warranted.
- **Check the premise before building on it.** "X is broken", "Y is still pending", "nothing calls Z": look at the system that would show it (the log, the queue, git, the callers) first. A fix for a problem that isn't there is a new problem.
- **Find the decision the code already embodies** (the design note, README, recent commits, the task's stated goal) and keep its invariant. A fix that undoes the point of the last redesign is a regression, however clean it looks.

## 2. Keep it simple

Prefer, in order: don't build it, reuse what exists, one line, minimal new code.

- Nothing beyond what was asked: no speculative options, no abstraction for a single caller, no config nobody requested.
- No handling for impossible cases, but never cut validation, security or data-loss handling.
- If 200 lines could be 50, rewrite it. Would a senior engineer call this overcomplicated?
- Mark a deliberate shortcut with its upgrade path so the next reader knows it was a choice.
- **Add no limit nobody asked for.** A new cap, quota, retention cut, deletion or approval step takes something away from the user. Propose it; don't ship it inside another change.
- **Prefer a structured signal to a text match.** Before writing a regex or keyword list to classify free text, titles or commands, look for a field, flag, source tag, exit code or real parser that already carries the fact. A pattern over prose is beaten by the next wording, and patching it rarely converges: pattern matchers were the most common defect class in the review data below, and the usual reason a PR was sent back for redesign. When a matcher is unavoidable, write its probe table first (§4).
- **Share code between two callers only if they share a data model, not just a shape.** A helper that encodes "this caller's inputs differ from its parent's" is not generic. The tell: a constant named for what it *removes*, imported by a second caller that nobody re-derived it for.
- **A replacement that doesn't delete is an addition.** Introducing Y to replace X means removing X in the same change; "we'll retire the old one later" means running both forever, plus whatever keeps them in step. The tell: a field written and read by nothing, a helper with no callers.

## 3. Change only what the task needs

- Don't "improve" adjacent code, comments or formatting. Match the existing style even if you'd do it differently.
- Remove imports and variables your change orphaned. Flag pre-existing dead code; don't delete it uninvited.
- The test: every changed line traces to the request. If a diff line doesn't, drop it.
- What the change's contract reaches is in scope: if you change what a function returns, refuses or prints, its callers are part of the change. When the user asked you to fix everything, the in-scope problems you find are the task, not a list to offer back.

## 4. Turn the task into a check, then loop until it passes

- "Add validation" → write tests for invalid inputs, then make them pass.
- "Fix the bug" → write a test that reproduces it, watch it fail, then fix.
- "Refactor X" → tests pass before and after.
- "Add or change a matcher, guard or parser" → write the probe table first: real inputs taken from logs or the existing corpus, plus the variants of its input class (below), each with the verdict it should get. Run the old and the new code over the table and read every row where they differ.
- For multi-step work, plan with a check per step: *step → verify: check*.

Strong success criteria let you work alone; "make it work" needs constant clarifying.

## Before you call it done

An independent reviewer read 201 machine-written pull requests to two repositories (Oct 2026) and blocked 91 of them, with 471 blocking findings over all review rounds, each naming an input that reproduced it. Roughly: a matcher missed real spellings or over-matched (28%); a guard had another route around it (23%); an existing caller or consumer broke (12%); the PR body or a comment claimed what the code does not do (9%); state, ordering or replay went wrong (9%); an edge input was mishandled (7%). The authors had the tools to find every one. Before you submit, do these four, in proportion to what the change can break:

1. **Readers.** List every contract the change touches: what a function returns, refuses or prints, an exit code, a flag, a field or class value, an environment variable, a file's path or format, a schedule. Find every reader: `python3 scripts/consumers.py --base <ref>` (in this skill's folder) lists candidates and marks callers that discard the status, where a new refusal vanishes without a trace. Open each and run its real input through the new code. Deploy scripts, mirrors and test harnesses are readers too.
2. **The input class.** For each check, matcher, guard or parser you added or changed, run the variants rather than reasoning about them: other spellings and casings; quoting; `--x=y` and `--x y`; glued and separate option values; a wrapper before the command (`env`, `sudo`, `timeout`, `xargs`); a second line; empty, whitespace-only, missing, huge and flag-shaped values; non-ASCII digits and lookalikes; path spellings (a symlink, `/private/var` and `/var`, relative, a trailing slash); several arguments where you handled one.
3. **Other routes.** For a guard, name the effect it prevents and list the routes to that effect: another command or tool, a copy or rename, a derived variable, another encoding, another file playing the same role. Key the guard on the effect or the resolved object (the real path, the parsed command), not on the spelling you were shown, and make it refuse when it cannot tell.
4. **Twice, together, late.** What happens if this runs twice, two at once, after a partial failure, or against state an older version wrote (a replay, rewritten history, a stale file, a newer head)?

Then write every claim (title, PR body, code comment, final report) from the last run's output. Copy numbers from it. Say "every" or "never" only about what you grepped or tried; anything else carries its scope ("on the 14 cases in the test").

## The traps that report success

Each of these produced a confident wrong answer in real work. The shared lesson: **check the output the step was for, never the step's opinion of itself.**

- **A fallback that substitutes a different input turns a missing measurement into a wrong one.** `results.get(10000) or results.get(5000)` scores a checkpoint that doesn't exist and reports it as the one asked for. A log that counts items *found* rather than items *written* says the job succeeded when the only item failed. The tell is `or`, `.get(k, default)`, `getattr(..., fallback)` or a bare `except` on the path to a reported value. A missing input must produce an absent result that names itself (`{"verdict": "unscored", "why": "no 10k checkpoint"}`). A missing number is a question someone will chase; a substituted one is an answer nobody reopens.
- **A caller that ignores the status turns a refusal into silence.** `cmd >/dev/null 2>&1 || true`, a reply that says "started" without checking the command's exit code, `except: pass`. When your change adds a refusal or a new failure, the callers that throw the status away are where it disappears.
- **Exit 0 is not evidence of work.** A cloud job can print a traceback and then "completed successfully" with zero rows written. A glob that matches nothing makes a loop do nothing, quietly. Assert the artefact: rows in the table, a file with content, a count that moved. A run that finishes far faster than the work could take *is* the finding.
- **A pipeline's exit code is the last command's.** `pytest | tail -40` is green whatever pytest did. Redirect to a file and check `$?`, or use `set -o pipefail`.
- **A patch that matched nothing also exits 0.** `sed -i 's/old/new/'` succeeds when `old` is absent, and the job then runs with defaults. Make every scripted edit assert its anchor (`assert text.count(old) == 1`) and read the changed line back before acting on the file.
- **Don't edit a file a running process owns.** A background build that holds a manifest writes its copy back over your edit. Wait for it or stop it; a file is not a lock.
- **A config assembled from two templates has fields that are right alone and wrong together.** A batch size from one recipe and a length limit from another can combine into zero, and the run dies after the expensive part has loaded. Constraints *across* fields (`a % b == 0`, "x only with y", "must fit the machine") are exactly the ones neither source states. Write them as a check that runs before the costly step, and test it against a broken copy of the real config.
- **Check your fix isn't an instance of the bug it fixes.** A fix for "a pattern missed a wording" written as a wider pattern, or for "a fallback substituted the wrong input" written as another fallback, quietly repeats the original error. When you fix a class of defect, run the new code against every case in the class, and read the output, not just the diff.
- **Removing whatever a guard refused on runs the code past it for the first time.** A guard that kept firing was hiding the rest of the function. After the fix, treat everything downstream as new, never-executed code.

## Say what changed

The user reads your report, not the diff, and has usually not followed the work. Write it for someone who wasn't watching:

- One sentence on what the work was for; then what now behaves differently in their terms (what they will see, what no longer happens); then what is not done or not checked; then anything only they can do.
- Leave out dead ends, retracted claims, internals and side notes unless they change what the user does next. They belong in the PR or the log, which you can point to.
- No function names, flags, library internals or ticket numbers unless the reader asked for them. If a sentence would need explaining, rewrite it or drop it.
- A few short paragraphs. A report the reader has to ask to have explained again has failed, however accurate it is.

For a wrap-up at the end of the work, use **close-out**.

## When you are directing an AI agent

The same habits, plus one rule: **when an instruction fails twice, stop adding prompt text and make a structural fix**: remove the tool, change its inputs, inject the state it needs, or add a deterministic check. For systems of several agents, shared state or human sign-off, use **multi-agent-system-design**.

## Credits

The four habits follow the *Karpathy-Inspired Claude Code Guidelines* by Jiayuan (forrestchang), github.com/multica-ai/andrej-karpathy-skills (MIT), derived from Andrej Karpathy's post on LLM coding pitfalls. The traps and the review data are from our own work.
