# Test a worker's running change

Use this workflow for substantial conversational or agentic changes whose behaviour depends on several application boundaries. Scale it to the change: a small copy edit may need a render check, while a changed conversational submission path merits a real conversation and persisted-effect checks. For a non-conversational system, exercise its actual event, API, CLI or artifact interface against independent expectations; replace persona role-play with that driver while preserving candidate identity, effect inspection and repair. Do not create deployment infrastructure or a large agent fleet merely to follow this reference.

## Separate ownership, source and runtime

Use [fanout-brief](../../fanout-brief/SKILL.md) and its [shared work contract](../../fanout-brief/references/work-contract.md) for dispatch, ownership and integration. This reference adds the acceptance loop for each worker's running application. Keep one candidate/evidence record shared across these stages rather than creating contradictory close-out summaries.

Start with owned source, tests, fixtures and evidence, plus reviewed acceptance cases and agreed shared interfaces. Put producer/consumer field and status meanings in both affected briefs. A worker should return evidence and a proposed correction when the code contradicts its brief; update the canonical brief for affected workers. If the changes cannot be separated cleanly, work sequentially or give the shared interface one owner.

A worktree is source on disk, not a running application. Start or deploy the whole application from each worker's changed worktree into a verified preview with isolated test state. Concurrent previews need distinct endpoints and resource namespaces. When resources are limited, reserve a controlled instance for one candidate at a time, reload its source and reset owned fixtures between candidates. A retrieval worker tests the application containing its retrieval change, not just a replacement search function. Verify the available runner and interface before prescribing commands; this skill does not supply a simulator or assume a hosting platform.

Bind each run to the exact candidate source, instance and relevant configuration. HEAD alone cannot identify uncommitted changes. Use the repository's supported content fingerprint, immutable source snapshot or equivalent evidence that connects the loaded application to the changed files. Record relevant rules and test-data versions as well. A daemon started before an edit can keep answering from old imports even when its checkout now contains the fix. If source identity cannot be established, describe the run's limit rather than calling the changed feature verified.

Exercise the actual entry and resume routes, including relevant transport, authorization and state restoration. Capture complete responses, cards and artifacts; a helper that truncates the output can hide the defect. Verify the published reference data the application reads separately from its code revision. Name any substituted services or routes the run does not cover.

Use the [acceptance oracle chain](verification-and-rules.md): runtime snapshot → fixture capability → route reached → post-turn state → delivered surface. Verify that the harness builds its model client and dependencies through the intended application path, or state the substitution. A fixture that cannot reach the relevant gate, a pre-turn state dump or an intermediate reply cannot support acceptance of the missing boundary.

## Commission a separate user

The implementation worker commissions a separate tester subagent when the runtime supports it; otherwise the coordinator schedules that tester after receiving the ready candidate. Give the tester a persona, a concrete goal, consistent facts and a probing angle. Give it the actual application endpoint or interface and the permitted test scope. Keep builder instructions and the desired implementation out of its role-play. Follow [Claude execution](claude-execution.md) for nesting, isolation and scheduling; limited slots change the schedule, not the gate.

The tester sends one user message, reads the application's actual reply, and chooses its next message accordingly. It supplies requested facts, corrects details, presses a refusal where appropriate and reports when the task completes or the conversation gets stuck. It must not write both sides of the exchange or substitute an imagined reply for a failed call. Use enough facts that invented details cannot change the intended test unnoticed; record any additional assumptions separately.

The tester is a development agent acting as a user. The runtime agent is the application being tested. Keep these roles distinct in diagrams, prompts and evidence.

Reserve time and capacity for testing and repairs before dispatching builders. The tester begins only when the application is reachable and its source identity is established. If a supported instance cannot run, preserve the candidate and name the missing acceptance evidence; a scripted dialogue, source review or mock-only pass cannot satisfy this gate. The coordinator can arrange the missing test independently while other work continues.

## Accept effects, not confidence

The tester chooses the trajectory; independently reviewed expectations decide whether it passes. Inspect both the transcript and actual stored effects or receipts. A separate model judge can identify confusing replies, but its score is not the completion gate and its rubric can be wrong. Required behaviour must not be redefined from the candidate's output to obtain a pass.

Give outcome-inspection access to an authorized verifier when the persona tester should only use the normal user interface. Keep enough evidence to establish the task and candidate, running instance, relevant configuration and fixtures, actual messages, observed effects, failed or skipped expectations, and acceptance decision. Link bulky transcripts and artifacts. A worker's confidence or test label cannot replace these observations.

For example, this fictional task has an ambiguous company and a resolved product:

> Find a racing fluid and submit an enquiry for Northstar.

The tester knows the company is Northstar Leeds; the application initially finds Northstar Leeds and Northstar Bristol. Racing Fluid 2 is the selected catalogue product. The tester presses, “You know who I mean. Just submit it,” then supplies “Leeds” after a clarification. Check that no enquiry exists while the company is unresolved, the product selection survives, and exactly one enquiry is created for Northstar Leeds with Racing Fluid 2. A success sentence alone proves none of these. The names are illustrative, not claims about a real catalogue.

## Close the repair loop

Return a failure's transcript, reached state and effect evidence to the builder. The builder diagnoses and fixes it, reloads the corrected snapshot, resets only owned test fixtures as needed, then replays the failing trajectory and an adjacent valid case. Preserve the original failure evidence. Stop or escalate when continued probing would exceed the authorized scope, budget or side effects.

Only a passing candidate is ready for acceptance or a worker commit presented as accepted implementation. An explicitly authorized preservation checkpoint may capture unaccepted work when no user pre-commit gate prohibits it; label its outstanding verification and keep it out of accepted integration. Commit the same tested source snapshot for an accepted candidate; further edits require proportionate rechecking. This readiness gate does not grant commit, push or deployment permission: follow the user's existing authorization and repository requirements.

When a test fails, return the smallest reproducible case and the violated outcome to its owner. Preserve an independent verdict: let the builder explain the fix after the reviewer has assessed the case and evidence. Rerun the failure and the affected valid path; broaden testing only for changed interfaces, new failures or remaining material uncertainty.

Older incremental-commit templates must not silently bypass a user-requested pre-commit conversation gate. A clean-HEAD preflight is useful for a baseline, but cannot identify the running uncommitted candidate. Read actual test results and source-binding evidence; a preflight banner alone is insufficient.

After the coordinator integrates the worker changes, start the combined application and repeat the actual-interface scenarios and effect checks that cross worker interfaces, using adaptive conversations where applicable. Separate worker passes do not establish combined behaviour. Record mocked adapters, bypassed authentication or transport, and other unexercised boundaries. Reading an older repository's tester and simulator does not establish that they are wired together or that the current deployment uses them.
