# Execution modes

Check what this session actually supports (nesting, background runs, isolation, resume) before relying on it. Finish the deliverable asked for. Brief-only work ends with ready-to-use briefs and the baseline's known limits; doing the work runs through worker returns to combined acceptance; integration-only work starts from existing returns. A good brief is not evidence that its workers ran.

| Mode | Use for | What it needs |
|---|---|---|
| Read-only subagents | Independent investigation or review | Separate questions, inputs, report IDs and evidence; one shared checkout is fine. |
| Parallel builders | Independent code changes | Own worktree each, explicit base, file and resource ownership, interfaces, an integration owner. |
| Serial sessions | Coupled phases or scarce resources | One builder per checkout; fresh verification and current decisions at each handover. |
| Live driver | Exercising the real application | Actor, endpoint, test permissions, run/thread/tab map; see [live-driving.md](live-driving.md). |

## Dispatching Claude workers

- **Keep the lead in the main conversation**, where the objective and permissions live; dispatch bounded work with the `Agent` tool.
- **A subagent's context is fresh.** It can have scoped tools, preloaded skills and worktree isolation, but has not seen your skills or files. Give it the objective, owned files, verified baseline, interfaces, constraints and evidence destination; preload only the skills it needs, or give verified reference paths.
- **A `context: fork` skill starts without the conversation history.** Use one only when the skill and its arguments fully describe the job. Keep orchestration skills like this one inline.
- **Nesting is bounded and varies by version and configuration**, so assume neither "can't spawn" nor "always can". A worker that cannot start a tester returns a test request; the lead queues a separate tester from the worker's candidate packet. Independent outcome testing, including persona conversations for conversational changes, still happens.
- **Agent teams are experimental and opt-in** (explicit enablement, interactive session). Otherwise use subagents; do not enable teams to match a diagram. A team task list or teammate message is coordination state: inspect the actual artifact before accepting.

## Verifying isolation

- **Worktree defaults may start from the default branch.** Check the worker's base against the agreed pin, and its dependencies, before it edits.
- **With teams enabled, naming an `Agent` call can create a teammate in the shared working directory.** Worktree isolation on the call prevents that; isolation only in the agent's frontmatter does not. Confirm the worker's directory and source before edits, and check ownership even when isolation was requested.
- **Worktrees isolate files, not databases, ports, external effects or credentials.** Give each concurrent runtime its own endpoint/port, fixture or database namespace, queue, cache and output location. If separate instances are too costly, test candidates one at a time, reloading and binding each first.

Model names and team sizes are configuration, not rules. Docs: [skills](https://code.claude.com/docs/en/skills), [subagents](https://code.claude.com/docs/en/sub-agents), [agent teams](https://code.claude.com/docs/en/agent-teams); recheck version-sensitive behaviour when the installed version changes.

## Scheduling and saving returns

Run only as many lanes as are usefully independent, and reserve capacity for review, persona tests, disputed evidence and combined acceptance. Starting every builder at once starves the work that finishes the job.

Give briefs and outputs distinct owned paths; save each report as it returns, and if a worker could not write one, save its full result with author and task ID. While the originals are still in context, check each saved body's own title or task ID against the worker it is filed under: a pasted body under the right heading passes every check that reads the heading, and after compaction the original is gone. Use a native task-output path only after confirming it exists and holds the report.

## Interruption and resuming

Before resuming, inspect source, processes, partial outputs and external effects. Do not relaunch a costly run because observation was interrupted; check existing handles and outputs first, and keep complete, partial and unknown states apart.

Cancellation behaviour is something you observe in this harness, not assume. Relay at a safe boundary when interrupting would waste work; an urgent correction says what stops and what reruns. Background runs are fine when supported and observable; no blanket rule either way.

## Finishing or handing over resources

Once dependent checks are done, stop this task's processes and release its claims the normal way. Match recorded handles first: a familiar port or process name does not prove ownership. Do not stop a build a tester or the next owner still needs.

Before temporary resources go, save reports, original failures and the identity of what was tested. Keep worktrees and partial outputs needed to continue; record the next owner and remaining cleanup. Deleting files, changing shared services or ending another owner's work needs its own permission. If something cannot be released safely, name it and its owner instead of reporting cleanup done.

## Decisions across serial sessions

Keep one current ruling per question, with owner, reason and what would reopen it. Settled preferences stay settled without new evidence; a ruling whose factual premise failed or whose conditions changed reopens.

Routine reversible implementation choices are the worker's. Scope, shared contracts, business policy and external permissions go to their owner while independent work continues. Do not invent a sign-off at each phase of agreed work.

For substantial multi-session work use [the coordination template](coordination-doc-template.md); do not make workers read the chain of old prompts.
