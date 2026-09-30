# Coordination record template

Use the project's existing task/handover surface. Describe current state and decisions, not a growing diary. Keep confidential facts and secrets inside the project's boundary.

```markdown
# <task ID> — <outcome>

Acceptance owner: <coordinator>. Contract revision: <revision>.
Completion: <reviewed cases and observable result>.
Authority: <scope and approvals; remaining outward actions>.
Measured state (<time>): <source, dirty work, runtime, configuration>.
Evidence: <baseline and current acceptance records>.

| Worker | Mission | Owned paths/resources | Dependency | Candidate | Status |
|---|---|---|---|---|---|
| <ID> | <outcome> | <scope> | <input> | <pin/snapshot> | <state + reason> |

Shared contracts: <path/revision, producer, consumer, owner>.
Decisions: <rationale, owner and reopening condition>.
Test capacity: <instance/fixture owners; persona/review queue>.
Integration: <included revisions, combined candidate and evidence>.
Remaining: <next bounded task, owner and acceptance; unresolved limits>.
```

Refresh volatile facts when relevant state changes or work resumes. A new task should not require every old prompt. Ownership transfers require acknowledgement; silence is not a lease. The coordinator may do independent integration/verification work while respecting worker ownership.
