---
name: multi-agent-system-design
description: Design, review and improve multi-agent applications and their development workflow, including role boundaries, tool and prompt alignment, retrieval, shared state, recovery, enforced rules and behavioural verification of the actual candidate before integration.
---

# Multi-agent system design

Use this skill to turn an agent workflow into a system whose inputs, decisions, effects and verification are explicit. It applies to a design, an implementation change or a diagnosis; preserve the user's requested scope and deliverable.

## Choose the right layer

Keep two kinds of agents distinct:

- **Runtime agents** serve the application's user: retrieve evidence, resolve records, coordinate decisions and invoke permitted actions.
- **Development agents** build that application: edit owned code, start its running test instance, commission conversation tests and return changes with evidence.

A runtime product agent is not a build worker. A source worktree is not a running application. A transcript is not proof that a write occurred.

For operational worker dispatch, verified briefs, ownership and integration, use [fanout-brief](../fanout-brief/SKILL.md). Its [shared work contract](../fanout-brief/references/work-contract.md) defines the delivery vocabulary; this skill defines runtime design and running-application acceptance. Carry the same task, candidate and evidence references across the skills. Current user instructions and authorization take precedence over older boilerplate.

Read only the references needed for the current task:

| Work to do | Reference |
|---|---|
| Generalize the method across domains, interfaces and agent frameworks | [General method](references/general-method.md) |
| Choose roles, models, shared state and handoffs | [Runtime design](references/runtime-design.md) |
| Design durable execution, context ownership, cancellation or recovery | [Runtime lifecycle](references/runtime-lifecycle.md) |
| Give a role sufficient tools and accurate instructions; investigate tool/prompt drift | [Tool and prompt alignment](references/tool-prompt-alignment.md) |
| Search application data, choose records and submit a supported result | [Retrieval and submission](references/retrieval-and-submission.md) |
| Connect rules to code and tests; evaluate or diagnose behaviour | [Verification and shared rules](references/verification-and-rules.md) |
| Test a worker's changed application through a persona-scoped subagent | [Worktree conversation testing](references/worktree-conversation-testing.md) |
| Continue across development sessions without stale assumptions | [Session handover](references/session-handover.md) |
| Select Claude Code subagents, isolation and tester scheduling | [Claude execution](references/claude-execution.md) |
| Explain the architecture in diagrams or a presentation | [Explaining the system](references/explaining-the-system.md) |

## Start from the actual task and running system

1. State the user's intended outcome and the observable effect that would establish completion. Identify consequential actions and unresolved intent.
2. Inspect the available implementation, active configuration and relevant traces before trusting design notes. For a model-input problem, inspect the assembled messages, registered tool schemas and state used on the affected turn; a prompt file alone is insufficient.
3. Trace the path from the user's message through evidence, selection, coordination and action. Locate the first missing capability, lost distinction or contradicted instruction. Keep useful work already completed.
4. Improve the smallest relevant boundary, or design the required boundaries if the system is new. Adding agents, tools or prompt text is a choice to justify, not an objective.
5. Verify the intended behaviour at the appropriate level. Report what was inspected, simulated or executed, which version it describes, and what remains unestablished.

Choose the smallest applicable path: a design or diagnosis needs concrete contracts and evidence; a substantial agentic implementation also needs the running-application gate below. Load additional references when the affected boundary requires them. Stop expanding the review when the requested outcome has adequate evidence and no material question remains.

## Design decisions that carry across projects

- Give each role all capabilities needed for its job, including reading authoritative details and checking action outcomes. Scope tools, context and permissions to that role; do not equate completeness with exposing every available tool.
- Keep the model's instructions, tool descriptions, schemas, actual tool behaviour and application state coherent. When one changes, inspect affected consumers and update inaccurate guidance and examples together with implementation and checks.
- Preserve distinctions such as candidate versus selected record, unresolved versus confirmed intent, zero matches versus lookup failure, accepted request versus completed effect, and source revision versus running source snapshot.
- Use shared rules to guide reasoning and link them to the code that enforces action boundaries and the tests that exercise those boundaries. A linked file or a model's self-assessment is not verification.
- For substantial agentic changes, independently test the worker's actual running candidate and its effects. Use a separate adaptive persona tester for conversational surfaces; use the real event, API, CLI or artifact interface for other systems. Repair and rerun failures before proposing the change as accepted implementation. Authorized preservation checkpoints remain distinct from acceptance.
- Keep runtime architecture and development workflow separate in both implementation notes and diagrams.
- Evaluate the product's task outcomes separately from the development process: a better worker brief must earn its benefit through accepted changes, integration effort and repair burden. Use the comparison guidance in [verification and shared rules](references/verification-and-rules.md).

## Leave a useful result

Match the output to the request: a concrete design with decisions and open questions, implemented changes with focused verification, or a diagnosis tied to traces and replays. Use small decision records when they help: **responsibility → inputs/tools → output/effect → enforcing code → evidence**. Do not require a large document for a small change.

Work within existing authorization. This skill does not grant permission to commit, push, publish, contact others or write to production. Use controlled test effects, and separate a proposed workflow from actions actually run.

The product-enquiry examples in the references are illustrative. Treat their names, schema fields and file paths as teaching examples, not an inventory of installed tools or claims about any real implementation. Keep learned corrections in the relevant reference rather than accumulating one-off rules in this entrypoint.
