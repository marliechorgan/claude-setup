# Worker brief template

One brief, one worker: a Claude subagent, a background session or a headless run. The worker starts with this text and whatever it names, nothing else: no conversation, no loaded skills. When several workers share an arc, [fanout-brief](../SKILL.md) owns the split, the ownership map and integration; each worker's brief is still written here.

## Write it in this order

1. **Outcome and acceptance, first.** One observable result and why it matters. Then the cases that decide it: checks that fail now and must pass (write them before the fix), or for research, the questions to answer with evidence or mark unresolved. Name the effects that must not happen. An unwritten acceptance means unjudged work.
2. **Inputs verified now.** Open every path before citing it. A moved or archived file reaches the worker as "nothing found", not as an error. Cite code as `file:N` followed by the text on that line in backticks: line numbers drift, and the text is how the worker re-finds the line. Pin the base (commit, or snapshot time) and hand over evidence paths rather than your summary of them. Mark causes as hypotheses until tested.
3. **Gotchas as trigger, consequence, workaround.** Only the ones this task can hit. Never a whole lessons file.
4. **A write scope derived from the task.** List the files, repos, worktrees and directories this worker may change: every path its acceptance needs, plus its own scratch directory. Say what wins when rules meet. Read-only work says so. Name the neighbours whose files are not its own. A generic "write nowhere except X" line that the acceptance contradicts leaves the worker to break one rule or the other.
5. **Effects and authority.** What it may run, commit, push, send or publish, citing the approval that already exists, and what stays with the coordinator or the user. A brief cannot grant what the delegator does not hold.
6. **Limits, and when to return partial work.** A budget (tool calls, time, attempts) and what to hand back when it runs out: what is done, what is not, and the next step.
7. **A return path apart from the brief.** An owned report path, different from the brief's own path and from every sibling's. If writing it fails, the worker returns the whole report inline. Each worker gets its own scratch directory; shared scratch makes proof files unattributable.
8. **An invitation to challenge the brief with evidence.** The brief is a hypothesis and the worker is the one who tests it. When a claim in it is wrong, the worker names the claim, shows the evidence, proposes the correction and carries on with what still holds. Routine choices inside the write scope are the worker's to make.

Before dispatch, read the brief once as the worker will: every cited path opened, every quoted line still at its line number, a write scope that covers everything the acceptance needs, and a return path no sibling shares.

## Template

Omit fields that do not apply. When the worker is one of several, fill it from the [work contract](work-contract.md).

```markdown
# <task ID> / <worker ID> — <mission>

Outcome: <observable result and why it matters>.
Acceptance: <case IDs, checks that fail now and must pass, reviewed expectations
and required evidence; for research, the questions to answer or mark unresolved>.
Contract revision: <revision>. Acceptance owner: <coordinator>.
Inputs: <source pin, evidence and baseline report path; code as `file:N` `text on that line`>.
Unresolved: <facts/hypotheses this worker may settle>.
Read first: <necessary source symbols, rules and gotchas>.
Scoped context: <project and permitted source roots>.
Project instructions: <needed excerpt + source, or an accessible reference
marked read-first>. Do not assume inherited skills or context.
Gotchas: <trigger → consequence → workaround, only those this task can hit>.

Write scope: <files, repos, worktrees and dirs this worker may change, derived
from the acceptance; its own scratch dir; or read-only>.
Neighbours: <other owners and dependencies; their files are not in scope>.
Interface: <shared contract path/revision and meanings>.
You are not alone. Do not revert others' edits. Request an acknowledged scope
change before touching another owner's files; continue independent owned work.

Effects/authority: <permitted test scope and existing approvals>.
Limits/stop: <time, attempts, concurrency and partial-return condition>.
Challenge contradicted brief claims with evidence and a proposed correction.
Make routine implementation choices inside the agreed boundary yourself.

Return: <owned path, not the brief's> with candidate identity, changes,
case verdicts, actual evidence, mocks/skips, brief corrections and unfinished work.
Include resources still needed, recorded handles/owners and the next recipient.
If report writes are blocked, return the complete report in your result.
For substantial agentic changes, supply a running candidate and commission or
request independent outcome testing through its actual interface. Use adaptive
persona testing for conversations; preserve failures and inspect effects.
Do not call a checkpoint accepted, committed or deployed without evidence.
```

The coordinator revalidates affected facts before rebriefing. Workers may propose a next task; they cannot assign another worker's scope or manufacture authorization.
