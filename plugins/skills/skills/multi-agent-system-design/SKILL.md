---
name: multi-agent-system-design
description: Design, debug and test applications built from AI agents — chatbots, assistants, tool-using agents and multi-agent workflows. Use when designing agent roles, tools, prompts, shared state or handoffs; when an agent misbehaves (asks for things it was already told, ignores an instruction, calls the wrong tool, says it did something that never happened, loops or stalls); when reviewing an agent architecture; or when proving an agent change works by testing the running app with a simulated user and checking what was actually saved. Covers retrieval and record selection, recovery and retries, rules that must hold, and explaining the design. For splitting the build across several Claude workers, use fanout-brief.
---

# Multi-agent system design

Turn an agent workflow into one whose inputs, decisions, effects and checks are explicit, so that "it said it worked" and "it worked" can be told apart.

## Two systems, kept apart

- **The runtime** serves the product's user: agents that retrieve, decide and act.
- **The build** changes the runtime: Claude sessions that edit code, run the app and test it.

A runtime agent is not a build worker. A git worktree is not a running app. A transcript is not proof that a write happened. Keep the two separate in notes, briefs and diagrams.

## Start from what actually ran

1. **State the outcome** as something observable: "one booking for 4, Friday 7pm, High Street, and nothing saved before the branch was known". Name which decisions stay with the user.
2. **Look at what the model received**, not the prompt file: the assembled messages, the registered tool schemas, the injected state, on the failing turn. A tool that exists in the repo may not be registered; a prompt fragment may be truncated; the running process may be on older code.
3. **Trace the path** from the user's message through retrieval, selection, handoffs and the action. Find the *first* place a fact was missing, a distinction was lost, or an instruction contradicted another. Keep the work that was already right.
4. **Fix the smallest boundary that explains it.** Adding an agent, a tool or a paragraph of prompt is a choice to justify, not progress.
5. **Verify at the right level**, and report which version you tested and what remains unproven.

## Design rules that carry across projects

- **Give each role everything its job needs, and nothing it doesn't** — including a way to read back the effect it just caused. "Submit when ready" needs an observable readiness condition; a rule whose trigger the model cannot see will fail even when every tool exists.
- **Preserve distinctions through every handoff:** candidate vs selected record, "zero matches" vs "lookup failed", unresolved vs confirmed intent, request accepted vs effect completed. A specialist's "two companies match" must not become "company confirmed" because a coordinator summarised it.
- **Prompts guide, code enforces, tests prove.** A rule that matters links to the function that blocks the bad action and the test that exercises that function. A rulebook the agent never sees, or a model's promise to comply, is not enforcement.
- **When an instruction fails twice, stop adding prompt text.** Remove the tool, change its inputs, inject the state the model lacks, or add a deterministic gate. The third emphatic paragraph rarely holds.
- **Task state lives outside the conversation,** with one writer per mutable fact. Record selected records, open questions, pending actions and versions, so a restart or a second replica sees the same truth.
- **A safeguard must leave permitted work usable.** Blocking an unconfirmed submission should keep the product the user already chose and the path to ask the missing question. Test that the allowed path still completes, not just that the bad one is refused.
- **Earn every extra agent.** Measure one agent with cohesive tools on the same cases first. A new boundary should buy separate context, separate permissions, useful parallelism or better decisions.

## Prove it works: test the running app

For any substantial agent change, test the builder's actual running candidate, not the folder:

- **Know what you tested.** An app started before the edit keeps serving the old code and nothing in its replies says so. Stamp replies or logs with the source version, and refuse to test a stale instance.
- **Write the persona and its marking together, before the run.** The simulated user sees who it is, its goal, its facts and its angle ("in a hurry; table for 4 Friday 7pm; High Street; push it to skip the question"). The marking is hidden from it: what must be true at the end. The persona is a separate agent that sends one real message, reads the real reply, then decides what to say. It never sees the code or the marking, so the marking cannot be bent to fit the result.
- **Believe what was saved.** After each turn read the stored records. "All booked!" with nothing saved, or saved twice, is a failure however good the reply reads.
- **Check the whole evidence chain:** the running source matches the candidate → the test data can reach the behaviour → the request took the route you claim → the state *after* the action is right → the message actually delivered is right. A break anywhere leaves the claim unproven, even with a green exit code.
- **Break it on purpose.** Remove the fix and rerun: a test that still passes checks nothing.
- **An AI judge marks quality, never pass or fail.** Give it its own context; a judge that shares the writer's model and instructions shares its blind spots. Saved records and real checks decide correctness.

For a non-chat system use its real event, API, CLI or file output instead of a persona, with the same evidence chain.

## Read only what the task needs

| Task | Reference |
|---|---|
| Choose roles, models, shared state and handoffs | [Runtime design](references/runtime-design.md) |
| Durable state, retries, cancellation, recovery, resuming | [Runtime lifecycle](references/runtime-lifecycle.md) |
| Tool/prompt mismatch; a tool changed; the model "ignores" clear guidance | [Tool and prompt alignment](references/tool-prompt-alignment.md) |
| Search data, pick the right record, submit and confirm | [Retrieval and submission](references/retrieval-and-submission.md) |
| Keep a rule consistent across prompt, code and tests; evaluate changes and judges | [Verification and rules](references/verification-and-rules.md) |
| Test a builder's change through the running app with a persona | [Testing the running app](references/worktree-conversation-testing.md) |
| Apply the method to a new domain or framework | [General method](references/general-method.md) |
| Explain the design in diagrams or slides | [Explaining the system](references/explaining-the-system.md) |

For dispatching Claude workers, isolation and scheduling testers, see **fanout-brief** and its execution modes. For continuing across sessions, see **close-out**.

## Leave a useful result

Match the request: a design with decisions and open questions, a change with focused evidence, or a diagnosis tied to traces and replays. A compact record per decision works well: **responsibility → inputs and tools → output or effect → enforcing code → evidence**. Mark what was proposed separately from what was run.

The restaurant bookings, "Northstar" companies and racing fluids in the references are made-up teaching examples.
