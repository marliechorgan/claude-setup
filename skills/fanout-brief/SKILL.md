---
name: fanout-brief
description: Coordinate several workers on one arc — parallel Claude subagents, serial build sessions, background or headless build waves and sessions driving a live application. Use for fan out or pan out (sub-agents in parallel), splitting work between workers, ownership and interface contracts, preflight of a shared base, relaying findings to running workers, reviewing worker returns, integrating workstreams and accepting the combined result, and rebriefing work from a previous session. Includes a template for each worker's own brief. Not needed for a single bounded edit or an ordinary answer.
---

# Fanout brief

Coordinate work that returns corrections, usable changes and evidence. A worker may disprove its brief; the coordinator owns the resulting decision and combined outcome. This skill owns the run: what to split, who owns what, dispatch, relaying, integration and acceptance. Write each worker's brief from [the worker brief template](references/worker-brief-template.md).

## Choose the work before the workers

Select the deliverable from the user's request. A request for a brief or prompts produces a grounded packet without dispatching workers. A request to execute or coordinate work proceeds through dispatch, integration and acceptance within existing authorization. A request to review worker returns starts with their evidence and identifies only the missing work. Do not turn an execution request into a prompt-writing task, or a prompt-writing request into a running job.

State the intended result and the evidence that will establish it. Inspect current code, source material, relevant prior results and unfinished verification. Separate observations from proposed causes and fixes. A missing capability in a report is a question to check, not a fact to propagate.

Map dependencies before splitting. Parallelize independent questions or bounded changes with stable interfaces. Keep tightly coupled changes with one owner or sequence them. Read-only investigators can share a checkout; concurrent builders need isolated worktrees. Name why each worker helps and reserve capacity for review, testing and integration.

Use one [work contract](references/work-contract.md) across brief, worker return, integration and handover. Map its fields onto the repo's existing record; do not create another board or schema just to use this skill.

## Ground the run

For a repository build, run the preflight from this skill directory against the actual target tree:

```bash
bash scripts/fanout-preflight.sh /absolute/repo --test 'the verified baseline command'
```

Read [the preflight contract](references/preflight.md) before selecting flags. Replace the example baseline with the repository's verified command. A nonzero exit blocks the claim that supplied checks passed. Omitted or unavailable checks stay unmeasured. A successful command is not proof of acceptance, a running deployment, or complete test coverage.

Preserve the report once and give workers its path and relevant observations. Re-run volatile checks when the base, environment, ownership or dependency changes; do not rerun a costly suite on every message. For research outside a repository, record the source inventory and timestamp instead of manufacturing a Git preflight.

Use [grounding and evidence](references/grounding-and-evidence.md) for causal claims, counts and regression checks that travel between workers. Pass the applicable project instructions (the relevant CLAUDE.md rules, conventions and gotchas) as part of each worker's scoped input pack, with their source and permitted roots. A link alone is insufficient when the worker cannot read it or does not know it must.

## Dispatch the set

Write each brief from [the worker brief template](references/worker-brief-template.md), then read the whole set side by side: every cited path opened, write scopes disjoint, and no two workers sharing a return path. The set adds three things no single brief carries:

- **Ownership.** Write scopes are disjoint, and each brief names its neighbours. The worker must not revert others' edits. It obtains coordinator acknowledgement before editing another owner's files or changing a shared contract, and continues independent in-scope work meanwhile.
- **Interfaces.** One maintained record per shared contract, cited by revision from both briefs, with its producer, consumer and integration owner.
- **Resources.** A worktree isolates files, not databases, ports, queues, browser tabs or external writes. Allocate those explicitly, along with each worker's own scratch directory and report path.

Use [execution modes](references/execution-modes.md) for Claude subagents, serial sessions, resource limits and durable reports. Use [live driving](references/live-driving.md) when a session narrates or controls a live application.

## Coordinate while work runs

Keep a small run record: task and worker IDs, actual worktrees, pinned bases, ownership, dependencies, contract revision and current status. Match recipients by recorded ID. Relay verified cross-cutting findings with the changed contract revision and request acknowledgement; silence is not agreement. If a change invalidates running work, identify affected evidence and its restart point.

One coordinator owns integration. If another coordinator is active, agree ownership explicitly before overlapping mutations. A Markdown record informs agents; it is not a filesystem lock.

Do useful synthesis and dependency work while workers run. Avoid changing their files, repeated unchanged polling, or assuming an interrupted process completed. Preserve reports and original failures before retrying.

## Accept, integrate and explain

Read worker changes and evidence against the original acceptance cases. Review can be delegated; acceptance responsibility stays with the coordinator. Reproduce disputed results and high-consequence boundaries; reuse trustworthy checks for the same unchanged snapshot instead of blindly repeating everything.

For substantial conversational or agentic changes, use `multi-agent-system-design` and its running-application acceptance loop. Independently test each candidate through the real entry/resume routes with controlled state and effect checks. Use a separate adaptive persona tester for conversational surfaces, or the actual event/API/CLI/artifact interface for other systems. Queue testers or test instances when resources are limited. Mocked boundaries remain explicitly unverified.

Use [integration and acceptance](references/integration-and-acceptance.md). For code changes, verify exact returned revisions, reconcile interfaces and changed tests, then exercise the combined application as a new candidate. Recheck scoped branch tips and owned dirty work. For research or artifact work, reconcile sources, claims and versions, then inspect the combined deliverable. Separate worker passes do not establish that the combined result meets the task.

Preserve the distinction between changed, tested, committed, integrated and deployed. Commits, pushes, external sends and production effects follow the user's existing authorization; this skill grants none. A tested uncommitted snapshot can be ready for approval. An authorized checkpoint commit preserves work but does not establish acceptance.

Deliver a concise result and evidence locations before optional housekeeping can consume the remaining context: what changed, how it was checked, what remains and who continues it. Correct a bad brief at its source; keep project-specific incidents in the project's own record and reusable mechanisms in these references.

Once their dependent work is finished, release resources actually acquired for this task using the ownership record. Preserve evidence first; keep or transfer a resource still needed for acceptance or continuation. Follow the cleanup and handoff rules in [execution modes](references/execution-modes.md).
