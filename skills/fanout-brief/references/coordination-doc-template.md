# Coordination record template

Use the project's existing task or handover surface. Record current state and decisions, not a diary. Keep confidential facts and secrets inside the project.

```markdown
# <task ID> — <outcome>

Acceptance owner: <lead>. Contract revision: <revision>.
Done when: <reviewed cases and observable result>.
Permissions: <scope and approvals; outward actions still pending>.
Measured state (<time>): <source, uncommitted work, runtime, configuration>.
Evidence: <baseline and current acceptance records>.

| Worker | Mission | Owned paths/resources | Depends on | Build under test | Status |
|---|---|---|---|---|---|
| <ID> | <outcome> | <scope> | <input> | <commit/snapshot> | <state + reason> |

Shared contracts: <path/revision, producer, consumer, owner>.
Decisions: <rationale, owner, what would reopen it>.
Test capacity: <instance/fixture owners; persona/review queue>.
Integration: <included revisions, combined build and its evidence>.
Remaining: <next bounded task, owner and acceptance; open limits>.
```

Refresh volatile facts when state changes or work resumes; a new task should not need every old prompt. Ownership transfers need acknowledgement: silence is not a lease. The lead may integrate and verify independently, outside workers' owned files.
