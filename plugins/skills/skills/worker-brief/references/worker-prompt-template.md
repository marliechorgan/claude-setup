# Worker brief template

The fields from [worker-brief](../SKILL.md), in order. Delete what does not apply; a read-only lookup keeps only Outcome, Inputs and Return. When the worker is one of several, fill it from the [work contract](../../fanout-brief/references/work-contract.md).

```markdown
# <task> / <worker> — <mission in a few words>

Outcome: <observable result and why it matters>.
Acceptance: <checks that fail now and must pass, or questions to answer or mark
unresolved; effects that must not happen>.
Inputs: <base commit or snapshot time; evidence paths; code as `path:line` `text on that line`>.
Unresolved: <hypotheses this worker may confirm or disprove>.
Project rules: <the excerpt of CLAUDE.md or conventions it needs, with source>.
It has not seen this conversation or any loaded skill.
Gotchas: <trigger → consequence → workaround, only those this task can hit>.

Write scope: <files and dirs it may change, derived from the acceptance; its own
scratch dir; or "read-only">.
Neighbours: <who owns what next to it; their files are not in scope>.
You are not alone: do not revert others' edits. Ask before touching another
owner's files, and carry on with your own work meanwhile.

Authority: <what it may run, commit, push or send; what stays with the coordinator>.
Budget: <tool calls, time or attempts>. When it runs out, return what is done,
what is not, and the next step.
If a claim in this brief is wrong, say which, show the evidence, propose the fix
and continue with what still holds. Routine choices inside the scope are yours.

Return: <owned report path, not this brief's> under Changed / Tested (real output,
pasted) / Saved / Not done. If the write fails, return the whole report inline.
```

## A filled example

```markdown
# booking-fix / w2 — stop re-asking the party size

Outcome: when a customer gives size, day, time and branch in one message, the
booking assistant books without asking for any of them again.
Acceptance: tests/test_slots.py::test_full_request_one_turn fails today and must
pass; tests/test_slots.py as a whole stays green; no booking is written while the
branch is unknown.
Inputs: base a41c9e2. Transcript of the failure: evidence/2026-09-29-reask.txt.
Suspect: app/slots.py:88 `if not state.get("party_size"):` reads the key before
extract_slots() has filled it (hypothesis, untested).
Project rules (from CLAUDE.md): run tests with `uv run pytest`; never call the
live booking API from tests, use FakeBookings.
Gotchas: the dev server caches prompts at start-up → restart it after editing
prompts/ or you test the old text.

Write scope: app/slots.py, tests/test_slots.py, scratch/w2/.
Neighbours: w1 owns app/branches.py (branch lookup). Not yours.
Authority: run tests and the dev server locally. Do not commit.
Budget: 40 tool calls. On running out, return what is done and the next step.

Return: scratch/w2/report.md under Changed / Tested / Saved / Not done.
```
