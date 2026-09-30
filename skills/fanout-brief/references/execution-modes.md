# Execution modes

Choose a mode available in this Claude session. Inspect actual tools and installed capabilities before assuming nesting, background execution, isolation or resumption behaviour.

The requested deliverable comes first: brief-only work ends with ready-to-use packets and known baseline limits; execution work continues through worker returns and combined acceptance; integration-only work begins with existing returns. Choose the execution modes below only for work the request authorizes you to run. A useful brief is not evidence that its workers ran.

| Mode | Use | Obligation |
|---|---|---|
| Read-only subagents | Independent investigation/review | Separate questions, input packs, report IDs and evidence; shared source is acceptable. |
| Parallel builders | Independent code changes | Isolated worktrees, explicit base, file/resource ownership, interfaces and integration owner. |
| Serial sessions | Coupled phases or limited resources | One builder per checkout; fresh verification and maintained decisions at handoff. |
| Live driver | Exercise the actual application | Actor, endpoint, test authority and run/thread/tab map; [live-driving.md](live-driving.md). |

## Native Claude dispatch

Use Claude's `Agent` tool for bounded subagents when available. Keep the coordinator in the conversation containing the user's evolving objective and authorization. Give fresh workers complete task packets and relevant references; do not assume they inherit conversation history or loaded skills.

Verify isolation at the dispatch call and returned checkout. Native worktrees may begin at the repository's default branch: check the actual base against the agreed pin before edits. Check ownership even when an agent definition requests isolation.

Agent teams are optional when enabled and supported. Do not enable them to satisfy a diagram. Check whether a named dispatch creates a teammate or subagent and shares the checkout. Nesting, permissions and spawn capacity vary; a worker unable to commission a tester returns a test request to the coordinator.

Keep orchestration skills inline. A forked skill suits a self-contained task with all necessary context supplied; it does not automatically carry the coordinating conversation. Do not preload every workflow skill into every worker.

Capability references: [Claude subagents](https://code.claude.com/docs/en/sub-agents), [agent teams](https://code.claude.com/docs/en/agent-teams). Verify installed-version behaviour when it matters.

## Scheduling and recovery

Limit active work to useful independent lanes. Reserve slots/time for review, persona tests, disputed evidence and combined acceptance; starting every builder at once can starve completion work.

Allocate endpoint/port, fixture/database namespace, queue, cache and output location for each concurrent runtime. If independent instances are expensive or unavailable, schedule candidates sequentially in a controlled environment; reload and bind each candidate before testing. Code isolation alone does not isolate these resources.

Keep briefs and outputs in distinct owned paths. Save important reports as workers return. If a worker cannot write its report, save the complete result with authorship and task identity. Then check each saved body's own title or task ID against the worker it is filed under, not the heading you wrote above it, while the originals are still in context: a pasted body under a correct heading passes every check that reads the heading, and after compaction the original is gone. Use a native task-output path only after verifying it exists and contains the report; do not promise a universal path.

Before resuming interrupted work, inspect source, processes, partial artifacts and possible external effects. Do not relaunch a costly run because observation was interrupted. Check existing process/job handles and outputs first; retain complete, partial and unknown states.

Treat cancellation behaviour as an observed harness property. Relay at a safe boundary when interruption would waste work; urgent corrections name what stops and what must be rerun. Bounded background execution is valid when supported and observable; avoid blanket always/never-background rules.

## Finish or transfer resources

After dependent verification is complete, stop task-owned temporary processes and release task-owned claims or reservations through their normal supported mechanism. Check recorded handles and ownership first; a familiar port or process name alone does not identify this task's resource. Do not stop a candidate while a tester or receiving owner still needs it.

Save reports, original failures and candidate identity in a maintained task location before temporary resources disappear. Keep worktrees and partial artifacts required for continuation; record the next owner and remaining cleanup. Removing files, changing shared services or ending another owner's work still requires the applicable authorization. When safe release is unavailable, report the specific remaining resource and its owner instead of claiming cleanup succeeded.

## Serial decisions

Keep one current ruling with owner, rationale and reopening condition. Do not relitigate settled preferences without new evidence; reopen contradicted factual premises or changed conditions.

Routine reversible implementation choices belong to the worker. Scope, shared contract, business policy and external authority changes go to the responsible owner while independent work continues. Do not invent a human approval at each phase of already authorized work.

Use [the coordination template](coordination-doc-template.md) for substantial multi-session work; do not make workers copy the entire chain of old prompts.
