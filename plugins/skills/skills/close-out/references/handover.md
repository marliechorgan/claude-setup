# Leave a usable continuation

A handover lets a fresh session act correctly without reconstructing the conversation. Scale it to the work: a small finished edit needs none. Keep it in the project's existing task or handover file and update it in place; a second log with competing status is worse than none.

A good handover holds:

1. **State, with the time it was measured.** Code on disk and the running app are different things: the commit, any meaningful uncommitted changes, what was tested, what is running or deployed, and config or data versions that affect the result. Note who else is editing nearby. No credentials.
2. **Changed / tested / committed / deployed**, kept separate. A deployed fix can still have untested edges.
3. **Only the decisions that constrain what comes next,** with the reason and what would reopen each. Link to the rule or code rather than copying it. Mark assumptions as assumptions. If this work proved an old instruction wrong, fix that instruction now; don't leave two conflicting ones for the next session to referee.
4. **Evidence linked to the claim it supports:** which run, which source, the decisive message, stored record or file, and whether it came from reading code, a local run, a preview or production. Name mocks, skips and unknowns; a green summary without its scope is easy to over-read.
5. **One next step:** the task, its owner, what finished looks like. Include a command or path only if you ran or opened it here; otherwise say what must be found. "Combine the tested changes and check one correct booking through the combined app" beats "continue testing".

On resuming, recheck anything volatile before acting: branches, uncommitted files, running processes and config move between sessions. Keep the objective, accepted decisions and proven evidence; refresh the state they depend on. A handover should shrink what the next session must read, not grow into a diary.

For multi-worker runs, the fields map onto the [work contract](../../fanout-brief/references/work-contract.md). For a product's own runtime task state (retries, resumable jobs), see **multi-agent-system-design**'s runtime lifecycle; it is separate from this development handover.
