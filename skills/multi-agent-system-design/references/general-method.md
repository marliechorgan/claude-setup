# General method

For a new domain, interface or framework: find the decision and evidence obligations under the examples (catalogues, enquiries, previews, supervisors).

## Seven contracts

| Contract | The design must answer |
|---|---|
| Outcome | What does the user want, what would show it, which decisions stay theirs? |
| Decision environment | Can the role see the state, use the tools and read their results here? |
| Evidence and selection | What supports the choice, which constraints were checked, what is uncertain? |
| Coordination | Who owns each update, what does a handoff assume, how are disagreement and partial results handled? |
| Action and recovery | Who may cause the effect, on what preconditions, and what happens after timeout, retry, cancellation or restart? |
| Acceptance | Which independent expectation and observed state show success, including work preserved and effects prohibited? |
| Change and continuation | Which build and configuration was tested, what invalidates that, what must the next owner recheck? |

These are questions, not seven services, agents or documents; one component can answer several.

## Generalise the example, keep its precision

| Example | Principle | Domain choice |
|---|---|---|
| Search a catalogue | Scoped candidates; relevance isn't correctness | SQL, exact, text or semantic retrieval |
| Read full records | The authoritative details this decision needs | Required fields, provenance, effective period |
| Ask which company location | Resolve missing intent, keep work done | Which ambiguity matters, who resolves it, whether to ask |
| Create one linked enquiry | Validate the authorised effect and its links | Database write, file, ticket, approved reply |
| Shared task version | No update silently invalidates newer decisions | Single writer, transactions, conditional writes, merge policy |
| Rulebook → prompt → code → check | One owned rule meaning across consumers | Where rules live, role views, what needs judgement |
| Worktree → preview → persona | Exercise the real changed build as an independent user | Browser, API, CLI, test tenancy, shared environment |
| Combine commits and rerun | A combination is a new build with new risks | Merge, patch, config or artefact assembly |

"One owner" is per mutable fact or aggregate, not per application. After a state-version change, recheck a result's assumptions; one whose dependencies are unchanged can stay under an explicit merge rule. Don't discard valid work wholesale or let a stale proposal overwrite new intent.

"One rule" is one authoritative meaning, owner, scope and version, with role views where useful. Identical wording doesn't prove identical meaning; numbered prompt steps don't enforce order.

## Two systems, joined by acceptance

Runtime and build share no identities, permissions or budgets by default. Corresponding parts:

- product task and pending operation ↔ build task and change under review
- a role's permitted tools ↔ a worker's owned files, test environment and effects
- source and task-state freshness ↔ source snapshot, running process, effective config
- product completion evidence ↔ acceptance evidence for the change and the integrated build
- runtime recovery ↔ recovering a stopped worker's files, reports and processes before rebuilding

The bridge is a reviewed acceptance case: `requirement/rule → intended behaviour → enforcing boundary → case → worker change → observed outcome`. "Implemented", "exercised", "accepted" and "deployed" are separate claims. The [shared work contract](../../fanout-brief/references/work-contract.md) holds the build record; [runtime-lifecycle.md](runtime-lifecycle.md) the runtime side.

## Other kinds of work

- **Research:** acceptance may be supported claims, stated counter-evidence and a usable report, no write. Agents repeating one source is not corroboration; a readable citation doesn't prove support.
- **Documents:** inspect the rendered file, its sources and required content. A "successful" run with a missing or unusable file fails. Approving content and permission to distribute are separate.
- **Support or operations:** resolve the account and action, carry its access scope, run the permitted operation, inspect the result. A closed ticket or confident reply isn't a fix.
- **Non-conversational services:** drive real events, API calls or CLI inputs and check outputs and state; personas are for conversations. A simulator may drive the real app or replace a controlled external dependency, never the code under test. Name every bypassed transport, service or boundary.

## Don't universalise a local pattern

Choose models and topology together from comparable outcomes. Keep evidence while its dependencies hold; rerun cases they affect. Enforce stable action invariants in code; use calibrated judgement for interpretive work.

Success: the new domain keeps the decision, authority and evidence distinctions without importing the old one's entities, tools, rules, cloud provider, agent count or document volume.
