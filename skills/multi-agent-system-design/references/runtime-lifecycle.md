# Runtime lifecycle and recovery

Use this reference when agents share mutable state, continue after interruption, wait for people, perform consequential effects or run beyond one request. Select the relevant mechanisms; an ephemeral read-only query does not need a distributed workflow engine.

## Establish authority and transitions

Define the task's authoritative record separately from conversation history and source records. Give each mutable field or aggregate one writer, or an explicit conflict-resolution policy. A result carries the task reference, producing role, input-state version, source references and outcome status. Reject, refresh or reconcile a result whose input assumptions no longer hold.

Record only states that the application can distinguish and enforce. A useful starting vocabulary is `ready`, `running`, `waiting`, `completed`, `failed`, `cancelled` and `unknown-effect`; use separate operation records when an external action can outlive the task. Specify the allowed transition, responsible actor and evidence for it. A tool call returning successfully does not establish that the task's acceptance conditions hold.

For each mutating boundary, answer:

| Contract | Decision to make |
|---|---|
| Preconditions | Which identity, tenant, intent, source versions and permissions must still hold at execution? |
| Write ownership | Which component commits the transition, and how does it detect concurrent or stale updates? |
| Operation identity | Which stable reference identifies this intended effect across retries and reconciliation? |
| Completion | Which persisted result or receipt proves the effect and required relationships exist? |
| Recovery | Which failures permit retry, reconciliation, compensation or escalation? Who owns that choice? |

Use existing transaction, conditional-write or queue mechanisms where they fit. Keep authorization attached to the permitted operation and scope; changing the payload, tenant or destination requires re-evaluating its preconditions. Worker text must not upgrade its own authority.

## Make resumption safe

Persist completed results, pending operation references, unresolved intent and the next useful step at meaningful boundaries. Identify the replay boundary of the actual framework: restarting a node or activity can repeat earlier I/O. A checkpoint is useful only when its storage and recovery behavior match the deployment's failure modes.

Give retry ownership to one layer for each operation; account for provider, client and orchestrator retries to avoid multiplication. Retry a transient read within its budget. After a possibly completed write, reconcile by stable operation reference before retrying. Use an idempotency key tied to the intended effect when supported; preserve it for the same attempt and define what happens when the payload changes. Specify deduplication retention where it affects guarantees. State the real delivery guarantee rather than promising universal exactly-once effects.

Cancellation stops new work and propagates to active branches where supported. Already accepted effects may still finish. Reconcile them and report partial completion; compensation is a separate authorized action, not an assumption that cancellation rewinds the world. Define how to handle late worker results, lost workers, lease expiry and duplicate delivery when those conditions can occur.

For a parallel join, state which branches are required, which partial results are useful, the deadline, and who resolves a failed branch. Preserve completed independent work. Resume from the first unresolved dependency after refreshing volatile state, rather than rediscovering everything or trusting an old summary blindly.

## Keep context useful and current

Distinguish working conversation, authoritative task state, retrieved evidence and durable learned guidance. Decide their scope, writer, retention and refresh conditions. Retrieve current facts by reference when needed; keep source provenance and effective dates with facts whose meaning depends on them.

A handoff or compacted context preserves objective, constraints, selected records, unresolved decisions, operation references and evidence links. Put verbose transcripts in retrievable artifacts. Do not allow summarization to turn uncertainty into confirmation. Test resumption from the actual compacted or restored context for a workflow that depends on long-term continuity.

Promote a lesson only after checking its supporting outcome and applicability; task-specific observations should not silently become global policy. Conflicting or obsolete guidance needs an owner and a correction path. Shared memory must respect tenant and permission boundaries at both write and read time.

## Bound and observe execution

Set limits appropriate to the service: elapsed time, tool/model work, concurrent branches, retries and allowed external effects. Reserve capacity for joining, outcome verification and recovery. A stalled branch should not exhaust every slot needed to finish or diagnose the task. On exhaustion, preserve useful state and return an explicit incomplete or pending result.

Correlate task, agent invocation, operation and source-state references through traces. Record branch dispatch, state transitions, retry decisions, waits and completion evidence without retaining unnecessary sensitive content. Measure accepted outcomes, latency, total resource use, duplicate or incorrect effects and human repair; averages should not conceal a serious failure class.

Before claiming recovery, exercise the relevant cut: worker loss, stale return, duplicate message, timeout before a write, lost receipt after a write, cancellation or restart during a wait. Verify both the recovered result and absence of unintended effects. A documented recovery path that was not exercised remains a design claim.
