# Tool and prompt alignment

Use this reference when a role lacks the machinery its instructions assume, a tool changes, or a model appears to ignore otherwise clear guidance. The target is an executable, coherent decision environment, not the maximum number of instructions or tools.

## Inspect what the model actually receives

Choose a representative role and stage, including an ambiguous or interrupted case where relevant. Inspect an actual assembled model request or reproduce its assembly under the same configuration. Compare these surfaces:

1. **Registered tools:** callable names, handlers, role allowlists, stage restrictions and active feature flags. A function present in the repository may not be registered or reachable now.
2. **Exposed schemas:** argument names, required fields, types, defaults, units and descriptions supplied to the model. Compare them with validation and implementation, not only generated documentation.
3. **Assembled guidance:** system and role prompts, injected state, applicable rule versions, examples and conditional fragments. Check precedence, conflicting instructions and any context selection or truncation.
4. **Visible results:** representative successful, empty, ambiguous, denied, failed and partially completed tool responses. Inspect the fields and evidence actually exposed to the model.
5. **Running configuration:** source snapshot, model configuration, tool versions, permissions, flags and deployment posture. A process may still run an earlier revision than the checkout.

Read the resulting decision as the model would. Can it identify the applicable rule, observe the trigger, supply valid arguments, interpret the response and take the next permitted step? Distinguish a judgement it is meant to make from a fact the system has failed to provide.

For example, “submit when ready” needs an observable readiness condition. Expose the selected product, company-resolution status and task type, or let software evaluate that condition. A valid rule with an invisible trigger can fail even when every named tool exists.

Keep retrieved prose distinguishable from control instructions. A record can be authoritative about a product without having authority to change policy or tool permissions. Assemble load-bearing state from validated fields rather than promoting arbitrary tool text into trusted instructions.

Keep source content, worker claims, reviewed decisions and executable authority distinct across every handoff. Test a relevant malicious or misleading source instruction when the workflow consumes untrusted text. Runtime permissions, tenant scope and action preconditions must still hold if the model follows that text. Redact credentials and unnecessary personal data from prompts, traces and evidence exports; keep enough identifiers to investigate the permitted operation.

## Check completeness without adding a giant toolset

Map each role's obligations to reachable operations. Include clarification and recovery, not just the happy path. A coordinator may delegate product retrieval and company resolution, but still needs an explicit way to retain progress and complete the authorized enquiry. Each specialist needs the necessary subset, not the entire organization's tool inventory.

If a path is missing, locate the seam: tool registration, role permission, stage transition, schema mismatch, unavailable source or deficient instructions. Fix the seam rather than adding an emphatic prompt prohibition. A tool description should state its purpose, necessary inputs, result meaning and effects clearly enough to support correct selection.

## Map tool changes to their consumers

For a changed tool, compare the old and new contract. Review the affected guidance, code, tests and examples rather than mechanically rewriting every prompt.

| Change | What must be reconsidered |
|---|---|
| Name, registration or stage availability | Prompt references, delegation paths, examples and whether an owed action remains reachable. |
| Arguments, types, defaults or units | Call guidance, schema validation, consumers and representative valid and invalid calls. |
| Status or result shape | Instructions for empty, ambiguous, denied, retryable or partial outcomes; parsing and next-step tests. |
| Source, scope or freshness | Authority claims, tenant filters, effective-date assumptions, evidence fields and retrieval expectations. |
| Side effects or retry behaviour | Permissions, user-facing claims, operation identifiers, duplicate prevention and recovery scenarios. |
| Applicable rule or precedence | Runtime rule views, enforcing functions, reviewed expectations and examples that encode the earlier meaning. |

An implementation refactor with unchanged observable behaviour may require no prompt edit. Record why the guidance remains accurate and verify the relevant contract. Conversely, an instruction naming a removed tool, supplying an obsolete argument or treating a new ambiguous status as success is hard stale: repair it before relying on that path. A syntactically valid prompt can still be semantically wrong.

Keep one canonical meaning for shared rules and generate or maintain the appropriate role views. Avoid fixing a copied prompt fragment while leaving its source or other active consumers incorrect. Do not assume a filepath in an enforcement field proves that the function runs.

## Verify the revised decision path

Reassemble the request for the affected role and stage. Exercise the changed contract through representative conversations and inspect resulting records or artefacts. Include the case that made the previous guidance incorrect and a permitted case that must remain usable. A safeguard that blocks every submission can pass a negative test while failing the user's task.

Where uncertainty remains, compare trajectories with corrected context, restored access or another model. A trace records what happened; the first broken contract is an investigation point, not necessarily the sole root cause. Keep suspected causes and supporting evidence distinct.

Return a concise change record: old and new contract, affected roles and prompt fragments, required edits or justified non-edits, executed cases, resulting effects and tested configuration. Recheck these dependencies when their implementations or runtime settings change. Static inspection and behaviour tests provide different evidence; state which was performed.
