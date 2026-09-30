# Connect rules to observable behaviour

A plausible reply is not evidence that a task succeeded.

## A rule links guidance, enforcement and proof

A consequential rule has a meaning, owner, version, scope and expected behaviour, linked to the guidance the agent actually receives, the enforcing function and the checks exercising it. A rulebook that never reaches the agent or action enforces nothing.

| Rule component | Example (product enquiry) |
| --- | --- |
| Meaning | Confirm the company before submitting an enquiry. |
| Agent guidance | `prompts/enquiry_agent.md`: keep the selected product, ask for the missing company detail. |
| Enforcement | `enquiries/submit.py` → `submit_product_enquiry()`: require resolved product and company references. |
| Regression check | `tests/test_enquiry_submission.py`: ambiguous company, no enquiry; after clarification, one correct enquiry. |
| Conversation evidence | Actual messages, selected records, resulting enquiry, submission receipt. |

Paths are illustrative; inspect the real implementation, callers and flow before claiming anything. A defined function isn't proof the runtime calls it: "implemented" is not "exercised by this run".

Change a rule's guidance, enforcement and expected outcomes together, and check the interpretation independently: if one mistaken brief writes both code and expected answers, they agree on the error. Use reviewed business examples, authoritative records or a separate case review; for a contrasting pair, learn why the business expects different outcomes before deriving assertions. Workers challenge contradicted assumptions with evidence.

## Check positive and negative outcomes

Each case sets initial state, intent, expected transitions and external effects for success, ambiguity and relevant interruptions, on fresh isolated fixtures where leftover state could fake a pass. Useful work must survive a safeguard: blocking an ambiguous-company submission must not discard the resolved product or its lookup.

Check what was returned and stored, tied to the selected records by stable references and source versions. For Northstar: one enquiry, Northstar Leeds with Racing Fluid 2, none early or duplicated; not "a company record changed". Issued operation, accepted write, stored record and delivered response are four different observations.

Before trusting a green result, check the evidence chain:

| Link | Verify |
|---|---|
| Runtime snapshot | Loaded source, model-client construction, rules and config match the build; substitutions named. |
| Fixture capability | Required records, permissions, tools and feature conditions exist, or the behaviour can't happen. |
| Route reached | The request went through the entry, gate, tool or resume branch you claim. |
| Post-turn state | State after the action and any async completion; a pre-turn snapshot proves nothing. |
| Delivered surface | The message, cards, files or notifications delivered after rewrites and transport, not a draft. |

A break anywhere leaves the behaviour unverified, whatever the exit code. A bad fixture or substituted path is not an app defect: fix the test, exercise the real behaviour, keep the failed evidence and the claim's limits.

- Never lower the expected artefact count to what the environment can produce: a required PDF that can't render is failed or unverified, not one fewer output.
- An assertion that never ran is not a pass. Name skipped or bypassed checks and what they mean.
- For a regression or safeguard, prove the check catches the defect (reproduce, reintroduce in isolation, or feed a guard-tripping input), then restore the fix and check the valid path. Targeted, not mutation-testing everything. A negative result means little if the branch never ran.

## Diagnose boundaries, then compare changes

Trace what crossed each boundary (user input, agent context, retrieved candidates, authoritative records, selected references, tool arguments and outcomes, stored effects, final reply) to the first divergence. A refusal may stem from missing evidence upstream; a polished success may follow a failed write.

Test the explanation with a replay changing only the suspected cause, keeping useful progress. After a lost reply to a possible write, reconcile by operation reference before retrying; uncertainty is not evidence nothing happened.

Compare models or harnesses on identical reviewed outcomes, configuration and cases, with unseen cases and repeats where variance matters; score accepted outcomes, cost, latency, retries and human repair. Don't let averages bury a serious failure class, or credit the model for a simultaneous tool change. A good replay supports that combination, not a ranking.

## Evaluate the product and the build separately

| Layer | Shows |
|---|---|
| Product | The user's task completes correctly: required effects, constraints kept, acceptable latency. |
| Build | Workers produce accepted changes; interfaces integrate; reviewers find real defects; handovers keep the next action. |
| Skill bundle | Revised guidance improves build outcomes or cuts effort without weakening acceptance. |

Design docs, passing components and complete work contracts don't prove reliability, a running combined app or a working implementation. The [shared work contract](../../fanout-brief/references/work-contract.md) carries build identity, evidence and acceptance from design to close-out.

Start with a few representative cases and real failures, including where extra procedure is and isn't warranted: a small edit, tightly coupled code, independent investigations, a stale worker result, a broken shared interface, a changed tool contract, a missing test instance, an uncertain external write, a resumed session. Run only the relevant ones.

Compare skill revisions on identical inputs, model, permissions, starting state and rubric, plus a no-skill baseline where useful. Repeat cases when randomness could flip the decision; keep failures and skips. If combined skills regress, swap one module at a time. One good run is preliminary.

Rank correctness and harm first, then time to acceptance, effort (including coordinator, testers, rework), clarification burden, duplicated work and integration repair. Never shorten a run by dropping a gate the user asked for.

## Model judges

- Qualitative criteria need a clear rubric and periodic independent calibration; a judge's agreement is not ground truth.
- Calibrate against independently accepted and rejected examples, with contrasting pairs per behaviour. Report false positives and negatives by failure class; overall agreement can hide a judge flagging honest and dishonest outcomes alike. Poorly calibrated, it runs observe-only while reviewed expectations and direct checks decide.
- Financial and permission invariants stay in authoritative validation, never a fallible style judge.
- A judge sharing the writer's model and context shares its blind spots, as does a writer re-reading its own draft. Give it its own context, have it return only failures with offending text and a fix, and use another model family where a miss is costly. Only independent misses multiply down.
- Measure the judge-and-rewrite loop's extra calls, tokens, latency, retry depth and misses; a one-word verdict can hide much work. Bound rewrites, inspect the delivered result, recheck meaning and effects a rewrite could change. More criticism isn't more quality.

## Improve on evidence

Keep hard capability cases apart from regressions protecting accepted behaviour; measure "can succeed" and "succeeds consistently" when repeatability matters. Isolate fixtures between trials; report infrastructure and product failures separately, dropping neither.

Turn a demonstrated failure into a durable case and fix the layer the trace implicates: contract, tool, state, evaluator or environment. Useful labels: specification, ownership, stale context, missing evidence, ignored dissent, repeated work, premature completion, incorrect verification. Add a global instruction only for a general rule.

Stop when the improvement has enough evidence and no material regression. Label static checks, simulations, live runs and longitudinal comparisons separately; syntax and link checks show a skill loads, not that it works.
