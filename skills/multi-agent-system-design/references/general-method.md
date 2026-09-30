# General method: preserve meaning from intent to verified outcome

Use this reference to apply the design method to a new domain, interface or agent framework. Product catalogues, enquiries, browser previews and supervisor topologies are examples. Extract the underlying decision and evidence obligations before selecting those implementations.

## Seven contracts

| Contract | Question the design must answer |
|---|---|
| Outcome | What result does the user intend, what would establish it, and which decisions remain theirs? |
| Decision environment | At this decision, can the role observe the relevant state, use the necessary capabilities and interpret their results? |
| Evidence and selection | What supports the choice, which constraints were checked, and what remains uncertain? |
| Coordination | Who owns each result/update, what assumptions does a handoff depend on, and how are disagreement and partial results handled? |
| Action and recovery | Which component may cause the effect, under what preconditions, and what happens after timeout, retry, cancellation or restart? |
| Acceptance | Which independent expectation and observed output/state establish success, including preserved useful work and prohibited effects? |
| Change and continuation | Which candidate/configuration was tested, what invalidates that evidence, and what must the next owner recheck? |

Map these questions onto existing architecture and task records. They are not seven services, seven agents or seven mandatory documents. A deterministic component or one agent may satisfy several contracts. Introduce a separate role when its distinct context, permissions, parallel work or decision quality earns the coordination cost.

## Generalize the example without erasing its precision

| Example mechanism | Transferable principle | Domain-specific choice |
|---|---|---|
| Search a product catalogue | Gather scoped candidates without upgrading relevance to correctness | SQL, exact lookup, text/semantic retrieval or another evidence source |
| Read full product/company records | Obtain authoritative details sufficient for this decision | Required fields, provenance and effective period; not every physical column |
| Ask which company location | Resolve missing user intent while retaining established work | Which ambiguity matters, who can resolve it, and whether asking is necessary |
| Create one linked enquiry | Validate the authorized effect and verify its required relationships | Database write, file, ticket, recommendation, approved response or other output |
| Shared task version | Prevent an update from silently invalidating newer decisions | Single writer, transactions, conditional writes or explicit merge policy |
| Rulebook → prompt → code → check | Maintain one owned rule meaning across its consumers and evidence | Rule locations, role views and which parts require judgement |
| Worker worktree → preview → persona test | Exercise the actual changed candidate from an independent user's perspective | Browser, API, CLI, test tenancy or scheduled shared environment |
| Combine worker commits and rerun | A composition is a new candidate with new interaction risks | Merge, patch application, configuration assembly or generated artifact composition |

“One owner” applies to the mutable fact or aggregate, not necessarily the whole application. Parallel independent facts can have different owners. A changed state version is a reason to validate a result's assumptions; a result whose dependencies are unchanged may be safely retained under an explicit merge rule. Do not discard valid work indiscriminately or overwrite new intent with a stale proposal.

“One rule” means one authoritative meaning, owner, scope and version. Several role-specific views may be useful. Exact wording equality does not establish semantic agreement, and clear numbered prompt steps do not enforce execution order.

## Two systems, connected by acceptance

The product runtime transforms a user request into a supported outcome. The development process transforms a requested change into an accepted candidate. Both need scoped work, current state, stable interfaces, limits and verifiable outputs. They do not share identities, permissions or resource budgets automatically.

Keep these correspondences explicit:

- Product task and pending operation ↔ development task and candidate under review.
- Product role's permitted tools ↔ worker's owned files, test environment and effects.
- Source-record and task-state freshness ↔ source snapshot, running process and effective configuration.
- Product completion evidence ↔ acceptance-case evidence for the candidate and integrated build.
- Runtime recovery ↔ recovering a stopped worker's files, reports and processes before rebuilding.

The bridge is a reviewed acceptance case. Trace `requirement/rule → intended behaviour → enforcing or reasoning boundary → case → worker change → observed candidate outcome`. Keep claims of implementation, exercise, acceptance and deployment separate. The [shared work contract](../../fanout-brief/references/work-contract.md) supplies the development record; [runtime-lifecycle.md](runtime-lifecycle.md) supplies product execution semantics.

## Transfer to different work

For research, acceptance may mean supported claims, explicit counterevidence and a usable report. A source is not independent corroboration merely because several agents repeat it; a readable citation is not proof the cited source supports the claim. An external write may not be needed at all.

For document generation, inspect the rendered deliverable, source support and required content. Successful generation with a missing or unusable file fails the task. Content approval and permission to distribute the document are separate facts.

For support or operations, resolve the target account and intended action, carry its access scope, execute the permitted operation and inspect its resulting state. A closed ticket or confident reply does not establish the underlying problem was resolved.

For a non-conversational service, use actual events, API calls or CLI inputs and verify outputs/state. Adaptive persona conversations are valuable for conversational surfaces; they are not a universal testing interface. A simulator may drive the real changed application or substitute a controlled external dependency; it cannot replace the implementation under test and still satisfy actual-candidate acceptance. Name every bypassed transport, service and other untested boundary.

## Avoid universalizing a useful local pattern

Choose models and topology together using comparable task outcomes; do not prescribe model choice first or last for every system. Preserve unchanged evidence where its dependencies still hold, and rerun affected cases when they change. Use deterministic enforcement for stable action invariants and calibrated judgement for genuinely interpretive work.

A method succeeds when a new domain retains the decision, authority and evidence distinctions without importing the old domain's entities, tools, business rules, cloud provider, agent count or document volume.
