# Claude Code execution adapter

Use this reference when turning the development workflow into Claude Code workers and testers. Verify the installed version, available tools and effective configuration before choosing a mechanism. Capabilities described in current documentation may differ on another host.

## Choose a supported execution path

Keep coordination that depends on the evolving conversation in the main session. Use ordinary subagents for bounded implementation, investigation or testing with a complete task packet. A skill with `context: fork` starts without the conversation history; only use it when the skill and supplied arguments fully describe the work. Do not put this orchestration skill in a fork merely to save context.

Native subagents can have scoped tools, preloaded skills and worktree isolation. Their default context is fresh; include the objective, owned files, verified baseline, interfaces, constraints and evidence destination. Preload only relevant skills, or give verified paths to the necessary references. Do not assume a worker received the skills or files already read by its parent.

Subagent nesting and concurrency depend on version and configuration. Current Claude Code supports bounded nesting; do not encode a universal prohibition. If the worker cannot spawn a tester or capacity is exhausted, the coordinator queues a separate tester using the worker's candidate packet. Reserve tester and integration capacity instead of filling every slot with builders. This changes scheduling only: it does not waive required independent outcome testing, including persona conversations for conversational changes.

Agent teams are an optional mechanism for continuing peer coordination. They remain experimental and require explicit enablement and an interactive session. Use ordinary subagents when teams are unavailable. A task list or teammate message is useful coordination state; inspect the actual artifact and result before accepting completion.

## Verify source isolation

For concurrent writers, use an isolated worktree or another verified repository-supported boundary. Record the path, base revision and ownership in the [shared work contract](../../fanout-brief/references/work-contract.md). Native worktree defaults can start from the repository's default branch; verify that the worker actually has the required candidate baseline and dependencies.

With agent teams enabled, naming an Agent call can create a teammate in the shared working directory. Call-level worktree isolation prevents that conversion; frontmatter isolation alone does not. Confirm the running worker's actual directory and source identity before edits. Worktree isolation does not isolate databases, ports, external effects or credentials; allocate those separately where tests need them.

For a conversational application, its worker provides a ready candidate and running-instance packet before a persona tester starts. The tester gets the user goal and actual endpoint, while the outcome verifier gets independently reviewed acceptance criteria and permitted inspection access. Other systems provide the actual event/API/CLI/artifact interface and corresponding candidate evidence. Use [worktree-conversation-testing.md](worktree-conversation-testing.md) for the acceptance gate applicable to that interface.

## Keep skills discoverable

Maintain the canonical package under `~/.claude/skills/`; project skill directories can symlink to it. Claude Code deduplicates identical skill targets. Descriptions should put the intended task and applicability first. Keep the entrypoint short and link conditional references, since a large installed skill inventory can shorten descriptions in the model's listing.

Use `/doctor`, `/context` and supported skill diagnostics to inspect actual discovery. Validate frontmatter and referenced paths before relying on automatic invocation; successful manual loading alone does not prove the description is discoverable. Do not silently change permissions, experimental features or global limits to satisfy a skill.

Official references, checked 10 September 2026: [skills](https://code.claude.com/docs/en/skills), [subagents](https://code.claude.com/docs/en/sub-agents), [agent teams](https://code.claude.com/docs/en/agent-teams). Recheck version-sensitive behavior when the installed runtime changes; model names and fixed team sizes are configuration choices, not skill invariants.
