# Shared work contract

Terms that briefs, returns and handovers share. Put them in an existing task, brief or handover, not a new file; a small task may need only outcome, scope and evidence. Write and lint each worker's brief with **worker-brief**.

Runtime agents and build workers have separate task IDs and state. Acceptance cases link them: a build task changes a named runtime behaviour, and its evidence exercises that case.

## Before work

- **Task, revision, owner:** Stable ID; agreement revision; the lead who accepts.
- **Outcome, case IDs:** Observable user result and reviewed criteria, with forbidden effects and progress that must survive a refusal.
- **Inputs, uncertainty:** Authoritative references, versions, open facts or intent. Causes are hypotheses until tested.
- **Scope, ownership:** Owned source, tests, fixtures, outputs, resources; neighbouring owners. Researchers own questions and report paths.
- **Dependencies, interfaces:** Prerequisites; producer, consumer, schema and status meanings, conflict owner.
- **Effects, permissions:** Allowed reads and writes, test scope, approvals given. Being technically ready does not make an action permitted.
- **Limits, stop:** Time, cost, attempts, concurrency; reserved review and integration capacity.
- **Verification, output:** Verification level, artifacts, independent acceptance basis, report path and format.

Use descriptive symbols and stable paths. Each shared interface lives in one record, cited by revision from both briefs; a material change invalidates only the assumptions and cases it touches.

For private context, an analysis tool or memory, name the project and allowed source or store roots; "read memory" with no owner is not enough. Pass only relevant instructions and sources; sharing a skill does not share its caller's personal or confidential data.

Give project instructions as an excerpt with its source, or a reachable reference marked "read before <step>", and check the worker's profile and permissions allow it; otherwise it returns the missing dependency rather than borrowing another project's context. Each gotcha gets its trigger, evidence and relevance, with live constraints apart from resolved history.

## Worker return and evidence

Per acceptance case:

- **Verdict:** PASS, FAIL, NOT_RUN or BLOCKED, with a reason. A command error measures nothing it never reached.
- **Build under test:** revision, plus a file snapshot or fingerprint if uncommitted; instance; model, prompt/tool/rule, configuration and fixture versions.
- **Observation:** command or run ID, result, transcript, artifact or saved effect; name substituted adapters, skipped assertions, missing outputs.
- **Expectation:** the independently set criterion and its authority, never derived from the output under test.
- **Coverage:** cases and trials attempted and completed, failures, remaining uncertainty. Keep failed trials and original failures.

Also return brief corrections, unfinished work, dependencies and the next bounded step. If the report write is denied, return it inline and the lead saves it with its author; do not rerun successful research over a failed write.

## State and handover

Status is small (ready, running, blocked, returned, accepted), with a reason and next owner. Track changed, tested, committed, integrated, deployed and observed separately. Returned is not accepted; accepted is not permission to publish.

A handover carries the contract revision, exact build, evidence, open dependency and next step; the receiver acknowledges mutable responsibility. On resuming, refresh volatile state and keep the objective and durable evidence.

Record which task-owned resources are still needed and who uses or releases them; returning or accepting work does not permit stopping a shared service, deleting a worktree or releasing another's claim. Keep durable reports outside anything due for cleanup.

For integration, name included worker revisions, the combined build and its evidence. Re-read tips once workers settle: an earlier merged tip misses a later commit. A changed build needs proportionate rechecking before old evidence applies.

## One case through the build

`CASE-ENQUIRY-AMBIGUOUS`: company unresolved, product resolved. Pressure to submit creates no enquiry and keeps the product. A later location clarification creates one enquiry linked to the intended company and product.

The design names the behaviour; the brief assigns enforcement and fixtures; a persona tester drives the real app; checks read the linked records; integration repeats the case on the combined build. Close-out records build and evidence without upgrading the claim to a production result.

For a document task, reviewed source claims and a required artifact replace enquiry records: render it, check source support, open the actual output. An export that succeeds with no usable file fails.
