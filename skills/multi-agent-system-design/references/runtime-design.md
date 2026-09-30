# Runtime design

Use this reference when defining agent responsibilities, reviewing a runtime architecture, or explaining how several agents complete one user task. Start from the existing system and requested outcome; a supervisor with several specialists is an option, not a required topology.

## Define the decision and its acceptance

Name what the system must establish and what it may change. A relevant product, a resolved company, an accepted enquiry and a delivered notification are different outcomes. Identify which facts come from records, which require user intent, and which decisions need judgement. Give each consequential output an acceptance method: a source comparison, recomputation, stored-state inspection or reviewed qualitative criterion.

Use corrections and contrasting cases to discover exceptions. Compare similar requests with different outcomes and ask which fact changes the decision; record that predicate and who may resolve disagreement. A historical correction is evidence, not automatically current policy. Begin with a few ordinary cases and material exceptions rather than claiming a finite test set defines every acceptable behaviour.

## Give each role a complete, bounded job

For each role, record:

| Responsibility | What to establish |
|---|---|
| Job and completion | What this role returns, including partial or unresolved results. |
| Context | Instructions, relevant state, evidence and shared rules needed at its decisions. |
| Tools | Operations needed for the ordinary path, ambiguity, failure and recovery. |
| Permissions | Reads and effects permitted by the execution boundary. |
| Handoff | Evidence, uncertainty, remaining work and the next owner. |
| Model choice | Required reasoning quality, latency and cost on representative work. |

Completeness means the role has a supported path for its obligations. It does not mean every role receives every tool. Prefer cohesive domain operations where stable business logic can live in software. Use flexible investigative tools when the work actually requires exploration. If a role lacks a required operation, provide it, delegate to a capable role or revise the obligation; do not leave the prompt promising an unreachable action.

Keep prompts cohesive: explain the job, available actions, relevant constraints, result meanings and completion conditions together. Load applicable shared rules and current state at the decision point. Inspect the assembled runtime request using [tool-prompt-alignment.md](tool-prompt-alignment.md), rather than assuming source templates represent what the agent sees.

Choose models with measurements of completed work, including errors, retries, clarification burden and latency. A faster model can suit routine matching; difficult interpretation may justify a more capable model. Model capability and architecture inform each other. Changing the model must not grant more permissions: tool and service boundaries enforce those independently.

Compare the same cases with one agent and cohesive tools before adding specialists. Name what each boundary buys: distinct context, permissions, useful parallelism or better decisions. Stable calculations can remain functions; another agent is not required to complete a diagram.

Draw the dependencies before the agent roster. Keep a tightly coupled decision with one owner; parallelize work that can reach a useful result independently. Choose centralized delegation when a coordinator must reconcile evidence and accept effects. Use peer coordination only when agents need continuing interaction that cannot be expressed as bounded requests and results. Reconsider the topology when integration cost, waiting or repeated context reconstruction outweighs the benefit.

Measure the completed task including coordination, retries, waiting, human correction and integration. Compare like-for-like budgets; adding agents usually changes compute as well as architecture. Begin with a measured baseline or label the choice a hypothesis with a concrete validation case. A universal agent count, model family or benchmark threshold is insufficient justification.

## Keep task state outside individual conversations

Persist the selected records, unresolved questions, pending action, relevant versions and remaining budget. Give each agent the current portion it needs. Define who may update state and how stale proposals are handled. Separate task-state versions from source-record versions; one does not establish the other's freshness.

An injected state block informs the model. Runtime checks enforce permissions, budgets and transitions. Recheck sensitive conditions before an effect. A fact stored in one server process is not automatically available to another replica; state location and persistence are deployment properties.

For long-running, concurrent or consequential workflows, use [runtime-lifecycle.md](runtime-lifecycle.md) to define authoritative state, safe transitions, context refresh, bounded execution and recovery. Keep these runtime records separate from the build's [shared work contract](../../fanout-brief/references/work-contract.md).

## Preserve meaning across agent boundaries

A result should distinguish candidates from selections and proposals from completed effects. Carry evidence references, unresolved assumptions, state version and ownership alongside the answer. A specialist's “two companies fit” must not become a confirmed company merely because a coordinator shortens its response.

Parallel work needs a join condition and an owner for each mutation. Preserve useful completed work when another branch needs clarification or fails. In the fictional product-enquiry example, retain Racing Fluid 2 while asking whether the user means Northstar Leeds or Northstar Bristol.

Treat worker conclusions as evidence-bearing proposals. Validate result structure, source authority and material disagreements before accepting them. A majority of similar agents can share the same error; preserve a supported dissent and the facts needed to resolve it. Use independent evidence or a checked outcome for consequential decisions, with one accountable acceptance owner.

Constrain the action that violates a rule without unnecessarily stopping other obligations. Blocking an unresolved enquiry submission should leave product investigation and clarification available. Also test that permitted work completes: a safeguard can prevent one mistake while making the whole task unusable.

## Return a reviewable design

Produce a role map, the state and handoff contracts, a concrete end-to-end scenario and its important failure branches. Mark proposed mechanisms separately from behaviour actually exercised, and attach tested versions to evidence. Design or testing instructions do not themselves authorize commits, external sends or production writes; preserve the user's established scope and permissions.
