# Test the running app

For substantial agent changes crossing several app boundaries. Scale it: a copy edit may need only a render check; a changed submission path needs a real conversation and a look at what was stored. Non-conversational systems swap the persona for their real event, API, CLI or file interface against independent expectations. Don't build infrastructure or a fleet just for this.

## Source, runtime and ownership

**fanout-brief** and its [shared work contract](../../fanout-brief/references/work-contract.md) cover dispatch, ownership, integration and the one build-and-evidence record; this adds each running app's acceptance loop.

Start from owned source, tests, fixtures and evidence, reviewed acceptance cases and agreed interfaces; producer/consumer field and status meanings go in both briefs. When code contradicts a brief, the worker returns evidence and a proposed fix, and the canonical brief is updated for all affected workers. Run inseparable changes sequentially, or give the shared interface one owner.

A worktree is source on disk, not a running app.

- Run the whole app from each changed worktree in a verified preview with isolated test state; concurrent previews need distinct endpoints and namespaces. Short of resources, share one instance serially, reloading source and resetting owned fixtures between builds.
- A retrieval worker tests the app containing its change, not a stand-in search function.
- Check which runner and interface exist before prescribing commands; this skill ships no simulator or host.

**Know which build answered.** Bind each run to exact source, instance and configuration. HEAD misses uncommitted changes: use a content fingerprint or immutable snapshot, plus rule and test-data versions. A daemon started before an edit keeps serving old imports. Without source identity, state the limit; don't call it verified.

Exercise the real entry and resume routes, including transport, authorisation and state restoration. Capture complete responses, cards and files; a truncating helper can hide the defect. Check published reference data separately from code; name substituted services and uncovered routes.

Apply the evidence chain from [verification-and-rules.md](verification-and-rules.md): runtime snapshot → fixture capability → route reached → post-turn state → delivered surface. The harness builds its model client and dependencies through the real app path, or says so. A fixture that can't reach the gate, a pre-turn dump or an intermediate reply proves nothing.

## Commission a separate user

The builder commissions a separate tester subagent where supported; otherwise the coordinator schedules one once the build is ready. The tester gets a persona, goal, consistent facts, probing angle, real endpoint and permitted scope, never the builder's instructions or intended implementation. Nesting, isolation and scheduling: **fanout-brief**'s [execution modes](../../fanout-brief/references/execution-modes.md). Limited slots change the schedule, not the gate.

The tester sends one message, reads the real reply, then chooses the next. It supplies requested facts, corrects details, pushes back on refusals where fitting, and reports completion or a stall. It never writes both sides or invents a reply for a failed call. Give it enough facts that invented details can't silently change the test; record extra assumptions.

The tester is a build agent playing a user, not the runtime agent; keep them distinct everywhere.

Reserve testing and repair capacity before dispatching builders. Testing starts once the app is reachable and its source identity established. If no supported instance can run, keep the build and name the missing evidence; a scripted dialogue, source review or mock-only pass doesn't satisfy this gate. The coordinator can schedule it meanwhile.

## Accept effects, not confidence

The tester chooses the path; independently reviewed expectations decide the result from the transcript and actual stored effects or receipts. A model judge can flag confusing replies, but its score isn't the gate and its rubric can be wrong. Never redefine required behaviour from the build's output.

If the persona should only use the normal interface, a separate authorised verifier inspects outcomes. Keep evidence of task, build, instance, configuration, fixtures, real messages, observed effects, failed or skipped expectations and the decision; link bulky transcripts. Worker confidence or a test label replaces none of it.

Made-up example:

> Find a racing fluid and submit an enquiry for Northstar.

The tester knows it means Northstar Leeds; the app finds Leeds and Bristol, with Racing Fluid 2 selected. It pushes ("You know who I mean. Just submit it."), then answers "Leeds". Check: no enquiry while the company is unresolved, the product survives, and exactly one enquiry at the end, for Northstar Leeds with Racing Fluid 2. A success sentence proves none of it.

## Close the repair loop

- Return a failure to its builder as the smallest reproducible case: transcript, reached state, effects, violated outcome. The builder fixes it, reloads, resets only owned fixtures, then replays the failing path and an adjacent valid case. Keep the original evidence.
- The reviewer judges the case before the builder explains the fix. Rerun the failure and affected valid path; widen testing only for changed interfaces, new failures or real doubt.
- Stop or escalate when more probing would exceed the authorised scope, budget or side effects.

Only a passing build is ready for acceptance or an "accepted" commit. An authorised checkpoint commit may preserve unaccepted work if no user pre-commit gate forbids it; label it unverified and keep it out of accepted integration. Commit the tested snapshot; later edits need a proportionate recheck. Passing grants no commit, push or deploy permission.

Older incremental-commit templates must not bypass a user-requested pre-commit conversation gate. A clean-HEAD preflight is a baseline, not the running uncommitted build's identity; read real test results and source-binding evidence, not a banner.

After integration, rerun the cross-boundary scenarios and effect checks on the combined app, adaptively where applicable; separate passes don't prove combined behaviour. Record mocked adapters, bypassed auth or transport and other unexercised boundaries. An old repo's tester and simulator don't show they're wired together or used by today's deployment.
