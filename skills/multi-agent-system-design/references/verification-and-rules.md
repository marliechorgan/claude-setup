# Connect rules to observable behaviour

Use this reference when a rule must remain consistent across agent guidance, code and evaluation, or when a plausible reply is insufficient evidence that a task succeeded. Match verification effort to the change and its consequences.

## A rule links guidance, enforcement and proof

For a consequential rule, maintain its meaning, source or decision owner, version, scope and the behaviour expected when it applies. Connect that record to the prompt or tool guidance the agent actually receives, the function that enforces the action, and the checks that exercise that function. A long rulebook that never reaches the relevant agent or action is not enforcement.

Illustrative paths for a product-enquiry workflow:

| Rule component | Example link or behaviour |
| --- | --- |
| Meaning | Confirm the company before submitting an enquiry. |
| Agent guidance | `prompts/enquiry_agent.md`: retain the selected product and ask for the missing company detail. |
| Enforcement | `enquiries/submit.py` → `submit_product_enquiry()`: require resolved product and company references. |
| Regression check | `tests/test_enquiry_submission.py`: ambiguous company produces no enquiry; clarification permits one correct enquiry. |
| Conversation evidence | Actual messages, selected records, resulting enquiry and submission receipt. |

These paths are examples. Inspect the real implementation, callers and flow before making claims about existing code. A function definition does not prove that the relevant runtime path calls it. Distinguish “implemented” from “exercised by this run.”

When a rule changes, update affected guidance, enforcement and expected outcomes together. Preserve an independent check on the interpretation: if the same mistaken brief supplies the implementation and every expected answer, agreement can reproduce the error. Use reviewed business examples, authoritative records or a separate review of the acceptance cases. For a contrasting pair, establish why the business expects different outcomes before deriving assertions from the implementation. A worker should challenge a contradicted assumption with evidence rather than implement it faithfully.

## Verify the task's positive and negative outcomes

Specify the initial state, user intent, expected state transitions and external effects for each case. Include success, ambiguity and relevant interruption paths. Use fresh isolated fixtures where prior state would otherwise produce a false pass. Require useful work to survive a safeguard: blocking an ambiguous-company submission should not discard a resolved product or disable its lookup.

Check what the system actually returned and persisted. Names make diagrams readable; stable references and source versions connect the selected records to the write. For the illustrative Northstar case, inspect an enquiry for Northstar Leeds with Racing Fluid 2, rather than asserting only that a generic company record changed. Verify no premature or duplicate enquiry. An issued operation, an accepted write, a stored record and a delivered response are different observations.

Establish the acceptance oracle through this chain before interpreting a green result:

| Evidence boundary | What to verify |
|---|---|
| Runtime snapshot | The loaded source, model-client construction, rules and configuration match the intended candidate; name any harness substitutions. |
| Fixture capability | Required records, permissions, tools and feature conditions exist in this test world. An absent prerequisite can prevent the behavior under test from occurring. |
| Route reached | The actual request traversed the entry, gate, tool or resume branch being claimed as exercised. |
| Post-turn state | Inspect state after the tested action and relevant asynchronous completion; a pre-turn snapshot cannot prove the resulting transition. |
| Delivered surface | Inspect the final message, cards, files or notifications actually delivered after rewrites and transport, rather than an intermediate draft. |

A break in this chain leaves the claimed behavior unverified even if the harness exits successfully. Diagnose an invalid fixture or substituted path separately from an application defect, then repair the test and exercise the intended behavior. Preserve the failed evidence and the limits of the original claim.

Do not derive the expected artefact count from the environment's ability to produce the artefact. If a required PDF cannot render, report that requirement as failed or unverified according to the supported environment contract; silently asserting one fewer output hides the missing feature. Likewise, a conditional assertion that never ran is not passing evidence. Identify skipped or bypassed checks and interpret their consequences.

Where useful for a regression or safeguard, demonstrate that the check catches the defect: reproduce it, deliberately reintroduce it in isolation, or use an input that must trip the guard. Restore the fix and verify the valid path too. This is targeted evidence, not a requirement to mutation-test every low-impact change. A negative result proves little if the relevant branch was never reached.

## Diagnose boundaries, then compare changes

Trace what crossed each boundary: user input, context supplied to the agent, retrieved candidates, authoritative records, selected references, tool arguments, tool outcomes, persisted effects and final reply. Find the first divergence from the expected path. A downstream refusal may reflect missing evidence upstream; a polished success reply may follow a failed write.

Use a targeted replay to test the explanation. Change the suspected cause while keeping the case and relevant conditions comparable. Preserve useful progress and add the demonstrated failure to a durable regression case. If a reply was lost after a possible write, reconcile by a stable operation reference before retrying; an uncertain result is not evidence that nothing happened.

For model or harness comparisons, use the same reviewed outcomes, configuration record and representative cases, including unseen cases and repeated runs where variance matters. Compare accepted task outcomes, total effort or cost, latency, retries and human repair. Do not hide a serious failure class inside an average score or attribute a model difference to a simultaneously changed tool interface. A stronger model is a candidate intervention; a successful replay supports that specific combination, not a universal model ranking.

## Evaluate the product and the building process

Maintain separate questions and evidence for these layers:

| Layer | What the evaluation establishes |
|---|---|
| Product | The application's user task completes correctly, with required effects, preserved constraints and acceptable latency. |
| Development | Workers produce accepted changes; shared interfaces integrate; reviewers find relevant defects; handovers preserve the next action. |
| Skill bundle | Revised guidance improves those development outcomes or reduces effort without weakening acceptance. |

A good design document does not establish product reliability. Passing component checks does not establish a running conversation or combined application. A complete work contract does not establish a successful implementation. Use the [shared work contract](../../fanout-brief/references/work-contract.md) to carry candidate identity, evidence and acceptance between design, fan-out and close-out.

Start with a small set of representative cases and actual failures. Include both appropriate use and non-use of extra procedure: a small edit, tightly coupled code, independent investigations, a stale worker result, a broken shared interface, a changed tool contract, a missing test instance, an uncertain external write and a resumed session. Select cases relevant to the proposed change rather than executing the whole list on every task.

For a skill revision, compare the previous and proposed guidance against the same inputs, model, permissions, starting state and acceptance rubric. Keep a no-skill baseline where it answers whether the skill adds value. Repeat cases when stochastic variation could change the decision; retain failures and skipped cases. If combining skills introduces a regression, remove or substitute one module at a time to locate the interaction. A single favorable run is preliminary evidence.

Assess task correctness and harmful effects first, then time to accepted result, total effort, clarification burden, duplicated work and integration repair. Count the coordinator, testers and rework in the process cost. Do not optimize a shorter run by removing a required user-requested gate. Qualitative criteria need a clear rubric and periodic independent calibration; a generated judge's agreement is not ground truth.

Calibrate model judges against independently accepted and rejected examples, including contrasting pairs for each important behavior. Report false positives and false negatives by failure class; aggregate agreement can hide a judge that flags honest and dishonest outcomes alike. When calibration is inadequate, run the judge in observe-only mode while reviewed expectations and direct checks govern acceptance. Keep financial and permission invariants in authoritative validation; a fallible style judge must not decide them. A judge that shares the writer's model and context shares its blind spots, so a writer re-reading the rules against its own draft is not an independent check: give the judge its own context, return only what failed with the offending text and a fix, and use a different model family where a miss is costly. Only independent misses multiply down.

Measure the judge and rewrite loop's additional model calls, total token use, latency and retry depth, including cases it lets through. A one-word verdict can require substantial hidden work. Bound rewrites, inspect the delivered result after them, and recheck substantive meaning and preserved effects when a rewrite can change either. More criticism or more rewrites are not evidence of higher quality.

Keep challenging capability cases separate from regressions that protect behavior already accepted. Measure both finding a successful attempt and succeeding consistently when the product needs repeatability. Isolate fixtures across trials; record infrastructure failure separately from product failure without quietly dropping either from the report.

Convert a demonstrated failure into a durable case and repair the responsible layer. Useful labels include specification, ownership, stale context, missing evidence, ignored dissent, repeated work, premature completion and incorrect verification. Choose a contract, tool, state, evaluator or environment correction supported by the trace. Add a global instruction only when the evidence supports a general rule.

Stop when the intended improvement has adequate evidence and no material regression remains. Label static checks, scenario simulations, live application runs and longitudinal comparisons separately. Skill syntax and link validation establish that guidance can load; behavioral effectiveness requires observed task outcomes.
