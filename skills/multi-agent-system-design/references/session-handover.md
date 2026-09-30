# Leave a usable continuation

Use a short maintained handover when work will continue in another session or pass between workers and a coordinator. Its purpose is to let a fresh reader act correctly without reconstructing the conversation. Scale it to the work; a small completed edit does not need an operational dossier.

Use the [shared work contract](../../fanout-brief/references/work-contract.md) and your project's existing task or handover record for the canonical task state. Update that record and link evidence from it; avoid a second independent ledger with competing status or ownership. Runtime task state follows [runtime-lifecycle.md](runtime-lifecycle.md) and remains separate from this development handover.

Record the current state with the time it was measured. Separate source on disk from the running application: relevant revision, meaningful dirty changes, tested source snapshot, running instance or deployment, and configuration or data versions affecting the result. Identify concurrent owners where their edits constrain the next action. Do not include credentials or an unrelated environment inventory.

Keep four distinctions visible: changed, tested, committed and deployed. They are not interchangeable. A verified fix can remain uncommitted; a committed fix can be absent from the running process; a deployed fix can still have untested integration boundaries. Preserve the user's current authorization separately from technical readiness.

Include only the decisions that constrain continuation, their rationale and any condition that would reopen them. Link to the current rule or implementation rather than copying an entire specification. Mark unresolved assumptions as assumptions. When evidence disproves stale guidance, correct its maintained source within the authorized scope; do not leave two conflicting instructions and expect the next session to infer which wins.

Link evidence by the claim it supports: the run and source it exercised, the decisive messages, stored effect or artefact, and relevant checks. State whether evidence comes from a read of code, a local run, an isolated preview or the deployed system. Name material mocks, skips and unknowns. A green summary without its scope is easy to overread.

End with the next bounded task, its owner and completion condition. Include the first useful path or command only when it has been verified in this environment; otherwise describe what must be located. Prefer “Owner: coordinator; combine the tested changes and verify one correct enquiry through the combined app” over “continue testing.” Name a blocking decision only when it genuinely prevents progress.

At continuation, recheck volatile state before acting. Yesterday's branch, dirty files, daemon and configuration can all have moved. Retain the objective, accepted decisions and proven evidence while refreshing the state they depend on. Avoid accumulating a chronological diary: the handover should reduce context drift, not make every future session read every previous one.
