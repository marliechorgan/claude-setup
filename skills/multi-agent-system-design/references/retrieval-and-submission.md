# Retrieval, selection and submission

Use this reference when agents find records in application data, select entities and submit the chosen information. Treat the following as logical responsibilities; they need not be separate agents, services or model calls. For role design and tool drift, use [runtime-design.md](runtime-design.md) and [tool-prompt-alignment.md](tool-prompt-alignment.md).

## Separate the claims made at each step

| Operation | Establishes | Does not establish by itself |
|---|---|---|
| Search | Potentially relevant candidates from names, aliases or meaning. | Identity, eligibility or authority to act. |
| Query | Records and relationships satisfying explicit database predicates. | Which entity the user intended. |
| Match | A supported selection or a clearly unresolved ambiguity. | That every required source field is current and complete. |
| Retrieve | Authoritative record details, stable references and relevant versions. | That the record satisfies this particular request. |
| Refine | A useful next query, detail fetch or clarification based on what remains unknown. | Permission to silently weaken a hard requirement. |

The order can vary. An exact, valid identifier can bypass search, and full records may be needed before matching. A domain service can combine several operations. Keep their contracts distinct enough to locate remaining uncertainty.

## Build a scoped shortlist

Use exact fields where known, lexical search for names and descriptive terms, and semantic retrieval where meaning-based discovery helps. Choose or combine these methods rather than requiring every query to run all three. Apply access scope before restricted records reach model context. Apply available hard filters and preserve constraints that still require authoritative fields to verify.

Top-k is a limit on returned candidates. Ranking is relevance, not proof of identity, suitability or uniqueness. A single returned candidate can be wrong, and the correct answer can be outside the displayed results. Inspect what reached the model, including ranking and truncation, rather than merely confirming that the database contains the answer.

A successful query with no matches differs from a denied call or an unavailable source. No matches may justify a revised query or a focused question. Failure leaves the result unresolved. Do not interpret either as permission to invent a record. Bound investigation and retries; report the unresolved issue when the system cannot make useful progress.

## Use full records to support selection

Fetch the authoritative business records needed for the decision, rather than relying on search snippets. “Full” means the authorized record details required by the operation, not every physical database column. Preserve source, version and business effective period where relevant; recently fetched data can still be expired or inapplicable.

Distinguish missing record data from missing user intent. A tool can retrieve a company's city. It cannot determine which of two cities the user meant when no other evidence resolves that ambiguity. Ask the smallest discriminating question and retain independently completed work.

Use readable names in diagrams and user responses, while tools carry stable record references beneath them. Names alone can collide or change. Preserve the selection reason and relevant evidence across handoffs, so a ranked candidate does not become a confirmed destination through summarization.

## Illustrative product-enquiry task

The user asks: “Find a racing fluid and submit a product enquiry for Northstar.” The fictional catalogue returns Blue Fluid and Racing Fluid 2. Their full records state general use and racing use respectively. Racing Fluid 2 meets the requested use; the selection depends on that field, not just its name.

Company records contain Northstar Leeds and Northstar Bristol. Ask “Leeds or Bristol?” A reply of “Leeds” resolves Northstar Leeds. Retain Racing Fluid 2 while this question is pending. The selected product and company records then supply the enquiry inputs.

This is an example, not a universal workflow. Do not turn an enquiry into an order, infer quantities or assume an existing draft. Adapt acceptance to the actual business operation and established authorization.

## Submit and verify the effect

At the execution boundary, validate the selected references, applicable constraints and permission to submit. If the company is unresolved, block that submission while retaining the product selection and clarification path. Prompt guidance helps the agent reason; code enforces the action conditions.

Keep selected, submitted and confirmed states separate. Inspect the persisted enquiry and available receipt: the intended product, intended company and intended number of effects must agree with the task. An application's “submitted” message alone does not prove the stored result.

If a response is lost after submission, reconcile through a stable operation or resource reference before retrying. Use idempotency support where available and describe partial completion honestly; do not promise universal exactly-once execution. Test ordinary completion, ambiguity, blocked submission and uncertain completion against independently reviewed outcomes using controlled effects. Testing or documenting this workflow does not grant permission to submit real enquiries.

For an asynchronous operation, a valid sequence is **accepted + operation reference → supported status lookup → persisted result + required links verified → completion response**. Keep pending, failed and unknown states explicit. If an external service completes while the application fails to attach the result to the intended company, repair or reconcile the missing linkage; creating the external effect again can duplicate it. Verify that the role can perform the required reconciliation reads, not only initiate the action.
