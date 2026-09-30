# Integrate and accept a fan-out

Integration owns the combination, not merely the merges. Use the [work contract](work-contract.md) and applicable review/release process. The Git steps below apply to repository changes.

For research or artifact work, record exact source and output versions, reconcile contradictory claims, duplicated evidence and missing requirements, then inspect the combined deliverable against independently reviewed expectations. Preserve attribution and uncertainty. Use the relevant meaning, evidence and acceptance steps below; branch checks and running-application tests apply only when the deliverable includes those boundaries.

## Receive exact candidates

Record worker/task ID, branch, returned revision or dirty snapshot, changed files and evidence. Read the diff and untracked outputs. Confirm evidence applies to the candidate and identify post-test edits.

Use the scope checker with an explicit map and base; see [preflight.md](preflight.md). Errors and unsupported claims leave scope unresolved. File ownership is the default; symbol regions are an explicit exception with coordinator-managed integration.

Own tests, fixtures, generated outputs, prompt/tool descriptions and evaluators too. A necessary scope extension is a proposed contract change: ratify or redirect before the worker touches another owner's files.

## Reconcile meaning

Review producers and consumers together: fields, units, null/error/partial meanings, references, permissions and effects. Missing information must not become a confident zero. Inspect affected registration, descriptions, prompts, notices, rules and expected outcomes.

Predict regression-marker and fixture changes. Shared marker files have one owner. Do not remove an assertion or expected failure just to get green; verify the business expectation and tested surface.

Regenerate emitted data from combined code and correct inputs. Do not pick one side of conflicting generated data. Reconcile changed test identities and intentional skips; counts can hide replaced or lost coverage.

## Verify the combination

Combine candidates in the agreed integration worktree under the existing authorization for Git operations. Run interface checks and required project checks on that source. Reuse unchanged evidence only when relevant dependencies match.

For substantial agentic changes, run reviewed actual-interface scenarios and effect checks through the combined application's real entry/resume routes. Use adaptive persona conversations for conversational surfaces and the actual event/API/CLI interface for other systems. Record source, instance, configuration and fixture identity. Helper tests or separate previews cannot prove the combined route.

Review and execute before outward-facing release. A local reversible integration candidate is often necessary to test the combination; constructing it does not authorize push, deployment or publication. Present the concrete verified result for any remaining approval.

## Reconcile scoped work

Run closeout preflight against named task branches and worktrees. With no selectors, repository-wide inventory may include unrelated work; do not call that this task's debt. Conversely, never ignore owned dirty source or a worker tip advancing after the recorded merge.

Freeze returned candidates or obtain acknowledgement that contributions are final. Re-read scoped tips and verify ancestry in the combined candidate. Preserve interrupted work with provenance; a rescue checkpoint is not accepted implementation.

Report included revisions, evidence, uncertainty and release state. Code review follows the project's review process; `multi-agent-system-design` owns runtime acceptance; the project's handover record owns continuation. The coordinator remains responsible for acceptance even when agents perform checks.
