# Retrieval, selection and submission

For agents that find records, pick entities and submit the result. Steps need not be separate agents or calls. Roles and tool drift: [runtime-design.md](runtime-design.md), [tool-prompt-alignment.md](tool-prompt-alignment.md).

## What each step proves

| Step | Establishes | Does not establish |
|---|---|---|
| Search | Possibly relevant candidates from names, aliases or meaning | Identity, eligibility or authority to act |
| Query | Records and relationships matching explicit predicates | Which entity the user meant |
| Match | A supported selection, or a clear unresolved ambiguity | That every required field is current and complete |
| Retrieve | Authoritative details, stable references, versions | That the record fits this request |
| Refine | The next query, fetch or question, from what is still unknown | Permission to quietly weaken a hard requirement |

Order varies: an exact ID skips search, matching may need full records first, one service can combine steps. Keep the contracts distinct enough to locate uncertainty.

## Build a scoped shortlist

- Exact fields where known, lexical search for names and descriptions, semantic retrieval where meaning helps; mix as needed.
- Apply access scope before restricted records reach the model, plus the hard filters you can; keep constraints that need authoritative fields for later.
- Top-k caps the results; ranking is relevance, not identity, suitability or uniqueness. A lone result can be wrong; the right one can be outside the shown results. Check what reached the model (ranking, truncation), not whether the database holds the answer.
- "No matches" (revise the query or ask a focused question) is not "denied" or "unavailable" (unresolved). Neither licenses inventing a record. Bound investigation and retries, and report when stuck.

## Select from full records

Decide from authoritative records, not snippets: the authorised details this operation needs, not every column. Keep source, version and effective period where they matter; fresh data can still be expired or inapplicable.

Missing data is not missing intent. A tool can fetch a company's city; it can't tell which of two cities the user meant. Ask the smallest deciding question; keep finished work.

People see readable names; tools carry stable references, because names collide and change. Carry the selection reason and evidence through handoffs, or a summary turns a ranked candidate into a confirmed one.

## Example: a product enquiry

"Find a racing fluid and submit a product enquiry for Northstar." The made-up catalogue returns Blue Fluid and Racing Fluid 2, whose records say general use and racing use. Racing Fluid 2 fits because of that field, not its name.

Company records hold Northstar Leeds and Northstar Bristol, so ask "Leeds or Bristol?", keeping Racing Fluid 2 selected. "Leeds" resolves it, and the selected records supply the enquiry.

Don't generalise it: never turn an enquiry into an order, infer quantities or assume an existing draft.

## Submit and check the effect

- At the execution boundary, validate the selected references, constraints and permission to submit. While the company is unresolved, code blocks submission but keeps the product and the clarification path. Prompts guide; code enforces.
- Keep selected, submitted and confirmed apart. Inspect the stored enquiry and receipt: right product, right company, right count. A "submitted" reply proves nothing stored.
- If the response is lost after submission, reconcile via a stable operation reference before retrying. Use idempotency keys where supported, report partial completion honestly, never promise exactly-once.
- Test completion, ambiguity, blocked submission and uncertain completion against independently reviewed outcomes, with controlled effects. Testing this does not permit submitting real enquiries.

Asynchronous operations: **accepted + operation reference → status lookup → stored result with links checked → completion response**. Keep pending, failed and unknown distinct. If the external service completed but the app failed to link the result to the right company, repair the link; repeating the effect can duplicate it. The role needs the reconciliation reads, not only the action.
