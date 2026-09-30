# Tool and prompt alignment

Aim for a decision environment the model can act in, not more instructions or tools.

## Inspect what the model actually receives

For a representative role and stage (and an ambiguous or interrupted case), read a real assembled request or rebuild one identically, and compare:

1. **Registered tools:** names, handlers, role allowlists, stage restrictions, active flags. A function in the repo may not be registered or reachable.
2. **Exposed schemas:** argument names, required fields, types, defaults, units and descriptions, checked against validation and implementation, not generated docs.
3. **Assembled guidance:** system and role prompts, injected state, rule versions, examples, conditional fragments; precedence, conflicts, truncation.
4. **Visible results:** real successful, empty, ambiguous, denied, failed and partial responses, and which fields reach the model.
5. **Running configuration:** source snapshot, model, tool versions, permissions, flags. The process may run an older revision than the checkout.

Then read the decision as the model would: can it find the rule, see the trigger, supply valid arguments, read the response and take the next permitted step? Separate judgements it should make from facts it was never given.

"Submit when ready" needs an observable readiness condition (selected product, company-resolution status, task type) or a code check; a rule with an invisible trigger fails even when every tool exists.

## Keep data apart from instructions

- Build load-bearing state from validated fields, never from retrieved prose promoted to instructions. A record can be authoritative about a product with no authority over policy or permissions.
- Keep source content, worker claims, reviewed decisions and executable authority distinct through handoffs. If the workflow reads untrusted text, test a planted malicious instruction: permissions, tenant scope and preconditions must hold even if the model obeys it.
- Redact credentials and unneeded personal data from prompts, traces and exports, keeping identifiers needed to investigate.

## Completeness without a giant toolset

Map each role's obligations, including clarification and recovery, to reachable operations. A coordinator can delegate product lookup and company resolution yet still needs a way to keep progress and complete the enquiry; specialists get only their subset.

Fix a missing path at its seam (registration, role permission, stage transition, schema mismatch, unavailable source, weak instructions), not with an emphatic prohibition. Tool descriptions state purpose, required inputs, result meaning and effects.

## Map tool changes to their consumers

Compare old and new contracts; review only the affected guidance, code, tests and examples.

| Change | Reconsider |
|---|---|
| Name, registration or stage | Prompt references, delegation paths, examples; is an owed action still reachable? |
| Arguments, types, defaults, units | Call guidance, schema validation, consumers, valid and invalid calls |
| Status or result shape | Handling of empty, ambiguous, denied, retryable, partial outcomes; parsing and next-step tests |
| Source, scope, freshness | Authority claims, tenant filters, effective dates, evidence fields, retrieval expectations |
| Side effects or retries | Permissions, user-facing claims, operation IDs, duplicate prevention, recovery scenarios |
| Rule or precedence | Runtime rule views, enforcing functions, reviewed expectations, old-meaning examples |

A refactor with unchanged behaviour may need no prompt edit; record why and verify the contract. Guidance naming a removed tool, passing an obsolete argument or treating a new ambiguous status as success is hard stale: fix it first.

Derive role views from one canonical meaning per shared rule; fixing a copied fragment leaves its source and other consumers wrong. A file path in an enforcement field doesn't prove the function runs.

## Verify the revised path

Reassemble the affected role's request, run representative conversations and inspect the resulting records. Include the case that broke the old guidance and a permitted case that must still work: a safeguard blocking every submission passes the negative test and fails the user.

Still unsure? Compare trajectories with corrected context, restored access or another model. A trace's first broken contract is where to look, not necessarily the only cause.

Record old and new contract, affected roles and fragments, edits or justified non-edits, cases run, effects, tested configuration, and whether evidence is static inspection, behaviour tests or both. Recheck when these change.
