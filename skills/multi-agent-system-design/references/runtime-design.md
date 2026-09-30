# Runtime design

For agent roles, architecture reviews and explaining how agents complete one task. Start from the existing system and outcome; supervisor-plus-specialists is an option, not the default.

## Define the decision and how it is accepted

Name what the system must establish and may change: a relevant product, resolved company, accepted enquiry and delivered notification are different outcomes. Mark which facts come from records, user intent or judgement. Give each consequential output a check: source comparison, recomputation, stored-state inspection or a reviewed criterion.

Find exceptions in corrections and contrasting cases: record which fact makes similar requests end differently, and who settles disagreement. A past correction is evidence, not policy. Start with a few ordinary cases and key exceptions; no finite set defines all acceptable behaviour.

## Give each role a complete, bounded job

| Responsibility | Establish |
|---|---|
| Job and completion | What it returns, including partial or unresolved results |
| Context | Instructions, state, evidence, shared rules for its decisions |
| Tools | Operations for the ordinary path, ambiguity, failure and recovery |
| Permissions | Reads and effects the execution boundary allows |
| Handoff | Evidence, uncertainty, remaining work, next owner |
| Model choice | Quality, latency and cost on representative work |

Complete means a path for each obligation, not every tool for every role. Stable business logic goes in cohesive domain operations; investigative tools only where work needs exploring. If a role lacks a needed operation, add it, delegate or change the obligation; never let a prompt promise an unreachable action.

One prompt holds job, actions, constraints, result meanings and completion condition; rules and current state load at the decision point. Check the assembled request, not templates ([tool-prompt-alignment.md](tool-prompt-alignment.md)).

Choose models from measured completed work (errors, retries, clarification, latency), fast for routine matching, stronger for hard interpretation; model and architecture inform each other. A model change never grants permissions.

## Earn every extra agent

- Run the same cases with one agent and cohesive tools first. Each new boundary must buy separate context, permissions, parallelism or better decisions. Stable calculations stay functions; a diagram's empty box is no reason for an agent.
- Draw dependencies before the roster. A tightly coupled decision has one owner; parallelise work useful on its own.
- Central delegation when a coordinator must reconcile evidence and accept effects; peer coordination only for ongoing interaction that bounded requests can't express. Revisit when integration, waiting or rebuilt context outweighs the gain.
- Measure whole-task cost (coordination, retries, waiting, human correction, integration) on like-for-like budgets. Without a baseline, label the choice a hypothesis with a test case. A universal agent count, model family or benchmark threshold justifies nothing.

## Keep task state outside conversations

Persist selected records, open questions, pending action, versions and remaining budget; each agent gets its part. Define who updates state and how stale proposals fare. Task-state and source-record versions are separate; neither proves the other fresh.

Injected state informs; runtime checks enforce permissions, budgets and transitions. Recheck sensitive conditions just before an effect. State in one process is invisible to other replicas.

Lifecycle, retries and recovery: [runtime-lifecycle.md](runtime-lifecycle.md). Runtime records stay separate from the build's [shared work contract](../../fanout-brief/references/work-contract.md).

## Preserve meaning across agent boundaries

- Results separate candidates from selections and proposals from completed effects, carrying evidence references, open assumptions, state version and owner. A specialist's "two companies fit" must not become "company confirmed" in a coordinator's summary.
- Parallel work needs a join condition and one owner per mutation. Keep finished work when another branch stalls or fails: keep Racing Fluid 2 while asking "Northstar Leeds or Northstar Bristol?".
- Worker conclusions are proposals. Check structure, source authority and disagreements before accepting. Similar agents share errors, so majorities prove little; keep a supported dissent and the facts to settle it. Consequential decisions need independent evidence or a checked outcome, and one accountable acceptor.
- Block the rule-breaking action, not the task: an unresolved submission is blocked while product lookup and clarification keep working. Test that permitted work still completes.

## Return a reviewable design

A role map, state and handoff contracts, one end-to-end scenario and its key failure branches. Separate proposed mechanisms from exercised behaviour; put the tested version on the evidence. A design authorises no commits, sends or production writes.
