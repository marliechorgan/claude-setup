# Runtime lifecycle and recovery

For shared state, resumption, waits, consequential effects and long runs. Not for read-only queries.

## Authority and transitions

The task's authoritative record is neither the conversation nor the source records. Each mutable field or aggregate has one writer or an explicit conflict policy. Results carry task reference, producer, input-state version, source references and status; reject, refresh or reconcile one whose inputs changed.

Record only states the app can distinguish and enforce, such as `ready`, `running`, `waiting`, `completed`, `failed`, `cancelled`, `unknown-effect`. An external action that can outlive the task gets an operation record. Each transition has an owner and evidence; a tool's success doesn't satisfy acceptance.

For each boundary that writes, decide:

- **Preconditions** still true at execution: identity, tenant, intent, source versions, permissions.
- **Write ownership:** who commits, and how stale or concurrent updates are caught.
- **Operation identity:** a stable reference for the effect across retries and reconciliation.
- **Completion:** the stored result or receipt proving the effect and its links.
- **Recovery:** which failures get retry, reconciliation, compensation or escalation, and who decides.

Authorisation is per operation and scope: a changed payload, tenant or destination re-opens preconditions. Worker text can't raise its own authority.

## Safe resumption

- At meaningful boundaries, persist results, pending operation references, unresolved intent and next step. Know the replay boundary: restarting a node or activity can repeat earlier I/O. A checkpoint must survive the deployment's real failure modes.
- One layer owns each operation's retries, or provider, client and orchestrator retries multiply. Retry transient reads within budget; after a write that may have landed, reconcile by operation reference first.
- Tie an idempotency key to the intended effect, reuse it within the attempt, and define what a changed payload does. State deduplication retention and the real delivery guarantee; never promise exactly-once.
- Cancellation stops new work and propagates to active branches where supported; accepted effects may still finish, so reconcile and report partial completion. Compensation is a separate authorised action. Plan for late results, lost workers, lease expiry and duplicate delivery.
- A parallel join names required branches, useful partial results, a deadline and who resolves a failed branch. Keep finished work; after refreshing volatile state, resume from the first unresolved dependency, not from scratch or an old summary.

## Context that stays useful

Conversation, task state, retrieved evidence and learned guidance each get a scope, writer, retention and refresh rule. Fetch current facts by reference, with provenance and effective dates.

Handoffs and compacted context keep objective, constraints, selected records, open decisions, operation references and evidence links; transcripts go to retrievable files. Summaries must not turn uncertainty into confirmation. If continuity matters, test resuming from real compacted or restored context.

Promote a lesson only after checking outcome and scope; one task's observation isn't global policy. Conflicting or stale guidance needs an owner and correction path. Shared memory enforces tenant and permission boundaries on write and read.

## Limits and observability

Limit elapsed time, tool and model work, concurrent branches, retries and external effects. Reserve capacity for joining, outcome checks and recovery so a stalled branch can't take every slot. At a limit, keep useful state and return an explicit incomplete or pending result.

Traces correlate task, agent-call, operation and source-state references and record dispatch, transitions, retries, waits and completion evidence, without unneeded sensitive data. Measure accepted outcomes, latency, resource use, duplicate or wrong effects and human repair; don't let averages hide a serious failure class.

Before claiming recovery, exercise the cut: worker loss, stale return, duplicate message, timeout before a write, lost receipt after a write, cancellation or restart mid-wait. Check the recovered result and any unintended effects. Unexercised recovery is a design claim.
