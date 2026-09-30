# Shared work contract

Use the same meanings from design through dispatch, acceptance and close-out. These are fields in an existing task, brief or handover, not a required file format. A small task may need only outcome, scope and evidence.

Runtime agents and development workers have separate task IDs and state. Acceptance cases connect them: a development task changes a runtime behaviour; its evidence exercises the named runtime case.

## Before work

| Field | Meaning |
|---|---|
| Task / revision / owner | Stable task ID; revision of this agreement; coordinator responsible for acceptance. |
| Outcome / case IDs | Observable user result and reviewed criteria. Include prohibited effects and useful progress that must survive a refusal. |
| Inputs / uncertainty | Authoritative references, versions and unresolved facts or intent. Mark causal explanations as hypotheses until tested. |
| Scope / ownership | Owned source, tests, fixtures, outputs and resources; adjacent owners. Researchers own questions and report paths. |
| Dependencies / interfaces | Prerequisites; producer, consumer, schema/status meanings and conflict owner. |
| Effects / authority | Permitted reads/writes, test scope and already granted approval. Technical readiness is separate from authorization. |
| Limits / stop | Relevant time, tool/model cost, attempts and concurrency; reserve integration and review capacity. |
| Verification / output | Required verification level, expected artifacts, independent acceptance basis, report location and format. |

Use descriptive symbols and stable paths. Put each shared interface in one maintained record referenced by revision from both briefs. A material change invalidates affected assumptions and cases, not automatically every check in the repository.

When a brief uses private context, an analysis tool or memory, identify the selected project and permitted source/store roots; “read memory” without an owner is insufficient. Pass only the relevant instructions and sources. Sharing a general skill does not authorize sharing its caller's personal or confidential data.

Make required project instructions executable for the recipient: include the applicable instruction excerpt and source, or an accessible reference explicitly marked to read before the dependent action. Verify that the worker's profile and permissions allow it. If access is unavailable, return that dependency rather than substituting another person's or project's context. Supply each relevant gotcha with its trigger, evidence and applicability to this candidate; distinguish still-active constraints from resolved history.

## Worker return and evidence

Record each acceptance case with:

- **Verdict:** PASS, FAIL, NOT_RUN or BLOCKED, with a reason. A command error is not a measurement of behaviour it never reached.
- **Candidate:** source revision plus changed-file snapshot/fingerprint when dirty; instance identity; relevant model, prompt/tool/rule, configuration and fixture versions.
- **Observation:** actual command/run ID, result, transcript, artifact or persisted effect. Identify substituted adapters, skipped assertions and missing outputs.
- **Expectation:** the independently established criterion and its authority. Never derive it from the candidate's output.
- **Coverage:** cases/trials attempted and completed, observed failures and bounded uncertainty. Preserve unsuccessful trials and original failures.

Return brief corrections, unresolved work, dependencies and the next bounded action. If report writes are denied, return the whole report through the tool result; the coordinator saves it with content authorship. Do not rerun successful research because a file write was blocked.

## State and handoff

Use a small status such as ready, running, blocked, returned or accepted, with a reason and next owner. Track source/release facts separately: changed, tested, committed, integrated, deployed and observed. Returned is not accepted; accepted is not permission to publish.

A handoff contains the current contract revision, exact candidate, evidence, outstanding dependency and next action. The receiving owner acknowledges transferred mutable responsibility. Refresh volatile state at continuation while retaining the objective and durable evidence.

Record which task-owned resources remain necessary and who will use or release them. Return or acceptance alone does not authorize stopping a shared service, deleting a worktree or releasing another owner's claim. Keep durable reports outside resources scheduled for authorized cleanup.

For integration, name included worker revisions, resulting combined candidate and acceptance evidence. Re-read tips after workers settle; an earlier merged tip excludes a later commit. Changed candidates require proportionate rechecking before old evidence applies.

## One case carried through the build

`CASE-ENQUIRY-AMBIGUOUS`: the company is unresolved, the product resolved. Pressure to submit creates no enquiry and preserves the product. A later location clarification creates one enquiry linked to the intended company and product.

The design names the behaviour; the brief assigns enforcement and fixtures; a persona tester exercises the actual app; checks read the linked records; integration repeats the case on the combined build. Close-out records candidate and evidence without upgrading the claim to a production result.

For a document task, substitute reviewed source claims and a required artifact for enquiry records: render the requested document, check source support and open the actual output. A successful export with no usable file fails the outcome.
