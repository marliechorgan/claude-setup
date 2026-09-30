---
name: fanout-brief
description: Run several Claude workers on one piece of work and get back a result you can trust — parallel subagents, background agents, a sequence of build sessions, or sessions driving a live app. Use when the user says fan out, split this up, use sub-agents in parallel, run these at the same time, or when a task has independent parts worth doing concurrently; also for deciding who owns which files, checking a shared base before dispatch, relaying a finding to running workers, reviewing what workers returned, and merging their work into one tested result. Each worker's own brief is written with worker-brief. Not for a single bounded edit or an ordinary question.
---

# Fanout brief

You are the lead. You plan, brief, dispatch, relay, recombine and accept. Workers answer to you; the user talks only to you. A worker may prove its brief wrong, which is useful. Accepting the combined result stays with you even when agents did the checking.

## Decide what the user asked for

A request for briefs or prompts ends with ready-to-use briefs, not a running job. A request to do the work goes through dispatch, recombination and acceptance. A request to review returns starts from what came back. Do not turn one into another.

## Split by dependency, not by headcount

Write down the result and the evidence that will establish it before splitting. Then draw the dependencies:

- **Independent questions or changes with stable interfaces** go in parallel.
- **Tightly coupled changes** stay with one owner, or run in sequence.
- **Readers** (investigation, review) can share one checkout. **Builders** each need their own git worktree.
- Reserve capacity for review, testing and recombination. Filling every slot with builders starves the work that finishes the job.

Name what each extra worker buys: separate context, parallel time, or an independent view. If you cannot, use fewer. A one-line fix needs one session and a test.

Work goes out in waves. A **planning** wave (readers, no edits) returns findings and plans. A **build** wave (one job and one worktree each) returns changed code and a report. A **use** wave (testers on one frozen, recombined copy) returns real conversations and findings. Only a build wave has anything to recombine; real bugs from a use wave become the next build wave.

## Ground the run before dispatch

Workers inherit your mistakes at scale, so check the base once:

- Open every path you cite. Record the base commit and the verified baseline test command, and whether it passes now.
- For a repository build, the optional script does this mechanically:
  ```bash
  bash scripts/fanout-preflight.sh /absolute/repo --test 'the verified baseline command'
  ```
  A nonzero exit blocks any claim that the baseline passes. Exit 0 means the command completed, not that the product works. See [preflight](references/preflight.md) for flags.
- Give each worker the project rules it needs (the relevant CLAUDE.md lines, conventions, gotchas) inside its brief. A link it cannot read, or does not know it must read, is not a rule it will follow.
- For research outside a repository, record the source list and the time instead.

Use [grounding and evidence](references/grounding-and-evidence.md) when a cause, count or regression claim will travel between workers.

## Dispatch the set

Write each brief with **worker-brief**, then read the whole set side by side. The set carries three things no single brief can:

- **Ownership.** Write scopes do not overlap, and each brief names its neighbours. A worker never reverts another's edits. It asks you before touching another owner's file or a shared contract, and continues its own work meanwhile.
- **Interfaces.** Each shared contract (a field, a status value, an API shape) lives in one record, cited by revision from both the producer's and the consumer's brief.
- **Resources.** A worktree isolates files, not databases, ports, queues, browser tabs or outbound messages. Allocate those explicitly, along with each worker's scratch directory and report path.

The bundled **worker** agent runs one briefed build job in its own git worktree and reports under the fixed headings; **researcher** and **reviewer** cover read-only questions and the independent check. [Execution modes](references/execution-modes.md) covers Claude subagents, worktree isolation, agent teams, background runs and resuming interrupted work. [Live driving](references/live-driving.md) covers a session that operates a running app.

## Coordinate while work runs

Keep a small run record: worker IDs, worktrees, base commits, ownership, contract revision and status ([template](references/coordination-doc-template.md)). When a finding affects others, relay it with the changed contract revision and ask for acknowledgement; silence is not agreement. If a change invalidates running work, name what must be redone.

Use the waiting time for synthesis and dependency work. Do not edit workers' files, poll without reason, or assume an interrupted process finished. Save each report as it arrives, and check that the saved body really is that worker's (its own title or task ID), not just filed under the right heading.

## Recombine and accept

Read each worker's diff and evidence against the original acceptance checks, not against its own summary. Reproduce anything disputed and anything high-consequence yourself.

Recombine one candidate at a time onto a tested base, and run the tests after each. If adding C breaks two tests, look at C or at how C meets A and B. Passing alone is not passing together: the combined build is a new candidate and needs its own run. For an agent or chat product, test the combined app through its real entry point with **multi-agent-system-design**'s testing loop; mocked parts stay named as unverified. For research or documents, reconcile sources, claims and versions, then read the combined deliverable.

[Integration and acceptance](references/integration-and-acceptance.md) has the git steps, the scope checker and how to reconcile producers and consumers.

Keep five words separate in everything you report: **changed, tested, committed, integrated, deployed.** A tested uncommitted change can be ready for approval; a committed one can be missing from the running app. Commits, pushes and anything sent outward follow the user's existing permission; this skill grants none.

## Finish

Deliver the result before housekeeping can eat the remaining context: what changed, how it was checked, what remains and who continues it. Then release what this run acquired (processes, ports, worktrees no longer needed), keeping anything still needed for acceptance. If the work continues, hand over with **close-out**. When a brief turned out wrong, fix the brief template or the project's notes, not just this run.

The [work contract](references/work-contract.md) defines the shared vocabulary (verdicts, candidate identity, status) used across briefs, returns and handovers. Map it onto whatever task tracker the project already has; do not create a new one to use this skill.
