---
type: llm
focus: {source: file, path: brief.md}
---
Grade brief.md as a prompt for a sub-agent that has seen nothing of the conversation. PASS only if ALL hold: (1) it states a checkable finish line (e.g. a failing test or timing check that must pass), not just "fix it"; (2) it presents the N+1 cause as a hypothesis to confirm, not a fact; (3) it names which files the agent may change AND says app/checkout.py belongs to another agent; (4) it forbids pushing; (5) it gives a budget or a point at which to stop and report partial work; (6) it says where or how to report back.
