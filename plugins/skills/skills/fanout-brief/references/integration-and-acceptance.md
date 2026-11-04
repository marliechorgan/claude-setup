# Integrate and accept a fan-out

Integration owns the combined result, not just the merges. Terms follow the [work contract](work-contract.md); Git steps apply to repository changes.

For research or documents: record source and output versions, reconcile contradictions, duplicate evidence and gaps, and check the combined deliverable against independently reviewed expectations, keeping attribution and uncertainty.

## Receive exactly what was built

Record worker ID, branch, commit or uncommitted snapshot, changed files and evidence. Read the diff and untracked outputs; confirm the evidence is for this build and nothing changed after testing.

Run the scope checker with an explicit map and base ([preflight.md](preflight.md)); errors or unsupported claims leave scope unresolved. Ownership is per file (symbol regions are an explicit exception the lead integrates) and covers tests, fixtures, generated outputs, prompt and tool descriptions and evaluators. A needed scope extension is a contract change: approve or redirect it first.

## Reconcile meaning

Review producers and consumers together: fields, units, null/error/partial meanings, references, permissions, effects. Missing data must not become a confident zero. Check affected registrations, descriptions, prompts, notices, rules and expected outcomes.

Predict marker and fixture changes; a shared marker file has one owner. Never delete an assertion or expected failure to get green. Regenerate emitted data from the combined code and correct inputs instead of picking a side. Reconcile renamed tests and intentional skips; counts hide lost coverage.

## Verify the combination

Combine in the agreed integration worktree and run interface and project checks there. Reuse evidence only when its dependencies are unchanged.

For substantial agent changes, run reviewed scenarios through the combined app's real entry and resume routes and check effects (personas for conversation, the real event/API/CLI otherwise), recording source, instance, configuration and fixture. Helper tests and separate previews do not prove the combined route.

A local combined build made for testing does not permit push, deploy or publish; bring the verified result to whoever approves those.

## Close out this run

Run close-out preflight on this run's named branches and worktrees; without them it sweeps unrelated work too. Never ignore owned uncommitted source or a worker tip that moved after the recorded merge.

Freeze returns (or get them acknowledged final), re-read the tips and verify each is an ancestor of the combined build. Keep interrupted work with provenance; a rescue checkpoint is not accepted work.

Report included revisions, evidence, uncertainty and release state. Code review: **review-changes**. Testing the running app: **multi-agent-system-design**. Handover: **close-out**. The lead owns acceptance even when agents did the checks.
