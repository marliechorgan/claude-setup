---
type: llm
focus: {source: file, path: plan.md}
---
Grade plan.md. PASS only if ALL hold: (1) builders that edit code in parallel get separate git worktrees (or the plan explains why a change is sequenced instead); (2) it notices that (a) and (b) are coupled (the prompt must describe the tool that actually exists) and that (c) depends on the `status` values the tool writes, and handles that with a shared contract or sequencing; (3) it allocates the shared Postgres database and port 8000 so parallel workers don't collide; (4) it recombines the work and tests the combined chatbot end to end, not only each piece alone; (5) it does not treat three parallel agents as automatically better, i.e. it justifies the split or reduces it.
