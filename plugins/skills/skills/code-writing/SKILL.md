---
name: code-writing
description: Use this skill whenever you write, edit, fix or run code, scripts, shell one-liners or config, even small or quick ones. Habits for writing, changing, fixing, refactoring or reviewing code with fewer silent mistakes — think first, keep it simple, change only what the task needs, and prove the result by looking at what the code actually produced. Load it before the first line is written, including bug fixes, new features, data reports, config changes, bulk find-and-replace, reviewing a diff and directing an AI agent to code. Includes the traps that make broken code report success (fallbacks that swap in a different input, success signals with no output behind them, find-and-replace that matched nothing, configs stitched from two templates). Use judgment on trivial one-liners.
license: MIT
---

# Code writing

Four habits cut most coding mistakes, human and AI alike. Then come the traps that let broken code report success; they cost the most because nobody goes back to look.

## 1. Think before coding

- State your assumptions. If something is unclear, name what is confusing and ask before writing.
- If the request has several readings, lay them out rather than picking one silently.
- If a simpler approach exists, say so. Push back when it is warranted.

## 2. Keep it simple

Prefer, in order: don't build it, reuse what exists, one line, minimal new code.

- Nothing beyond what was asked: no speculative options, no abstraction for a single caller, no config nobody requested.
- No handling for impossible cases, but never cut validation, security or data-loss handling.
- If 200 lines could be 50, rewrite it. Would a senior engineer call this overcomplicated?
- Mark a deliberate shortcut with its upgrade path so the next reader knows it was a choice.
- **Share code between two callers only if they share a data model, not just a shape.** A helper that encodes "this caller's inputs differ from its parent's" is not generic. The tell: a constant named for what it *removes*, imported by a second caller that nobody re-derived it for.
- **A replacement that doesn't delete is an addition.** Introducing Y to replace X means removing X in the same change; "we'll retire the old one later" means running both forever, plus whatever keeps them in step. The tell: a field written and read by nothing, a helper with no callers.

```python
# Overcomplicated
class UserNameFormatter:
    def __init__(self, config=None):
        self.config = config or {}
    def format(self, user):
        if self.config.get("strategy", "default") == "default":
            return f"{user.first} {user.last}"

# Right-sized
def full_name(user):
    return f"{user.first} {user.last}"
```

## 3. Change only what the task needs

- Don't "improve" adjacent code, comments or formatting. Match the existing style even if you'd do it differently.
- Remove imports and variables your change orphaned. Flag pre-existing dead code; don't delete it uninvited.
- The test: every changed line traces to the request. If a diff line doesn't, drop it.

## 4. Turn the task into a check, then loop until it passes

- "Add validation" → write tests for invalid inputs, then make them pass.
- "Fix the bug" → write a test that reproduces it, watch it fail, then fix.
- "Refactor X" → tests pass before and after.
- For multi-step work, plan with a check per step: *step → verify: check*.

Strong success criteria let you work alone; "make it work" needs constant clarifying.

## The traps that report success

Each of these produced a confident wrong answer in real work. The shared lesson: **check the output the step was for, never the step's opinion of itself.**

- **A fallback that substitutes a different input turns a missing measurement into a wrong one.** `results.get(10000) or results.get(5000)` scores a checkpoint that doesn't exist and reports it as the one asked for. A log that counts items *found* rather than items *written* says the job succeeded when the only item failed. The tell is `or`, `.get(k, default)`, `getattr(..., fallback)` or a bare `except` on the path to a reported value. A missing input must produce an absent result that names itself (`{"verdict": "unscored", "why": "no 10k checkpoint"}`). A missing number is a question someone will chase; a substituted one is an answer nobody reopens.
- **Exit 0 is not evidence of work.** A cloud job can print a traceback and then "completed successfully" with zero rows written. A glob that matches nothing makes a loop do nothing, quietly. Assert the artefact: rows in the table, a file with content, a count that moved. A run that finishes far faster than the work could take *is* the finding.
- **A pipeline's exit code is the last command's.** `pytest | tail -40` is green whatever pytest did. Redirect to a file and check `$?`, or use `set -o pipefail`.
- **A patch that matched nothing also exits 0.** `sed -i 's/old/new/'` succeeds when `old` is absent, and the job then runs with defaults. Make every scripted edit assert its anchor (`assert text.count(old) == 1`) and read the changed line back before acting on the file.
- **Don't edit a file a running process owns.** A background build that holds a manifest writes its copy back over your edit. Wait for it or stop it; a file is not a lock.
- **A config assembled from two templates has fields that are right alone and wrong together.** A batch size from one recipe and a length limit from another can combine into zero, and the run dies after the expensive part has loaded. Constraints *across* fields (`a % b == 0`, "x only with y", "must fit the machine") are exactly the ones neither source states. Write them as a check that runs before the costly step, and test it against a broken copy of the real config.
- **Check your fix isn't an instance of the bug it fixes.** A fix for "fallback substituted the wrong input" written as another fallback can quietly repeat the original error. When you fix a class of defect, run the new code against every case in the class, and read the output, not just the diff.
- **Removing whatever a guard refused on runs the code past it for the first time.** A guard that kept firing was hiding the rest of the function. After the fix, treat everything downstream as new, never-executed code.

## When you are directing an AI agent

The same habits, plus one rule: **when an instruction fails twice, stop adding prompt text and make a structural fix** — remove the tool, change its inputs, inject the state it needs, or add a deterministic check. For systems of several agents, shared state or human sign-off, use **multi-agent-system-design**.

## Credits

The four habits follow the *Karpathy-Inspired Claude Code Guidelines* by Jiayuan (forrestchang), github.com/multica-ai/andrej-karpathy-skills (MIT), derived from Andrej Karpathy's post on LLM coding pitfalls. The traps are from our own work.
