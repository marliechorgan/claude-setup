---
type: llm
focus: {source: file, path: test-plan.md}
---
Grade test-plan.md. PASS only if ALL hold: (1) it sends at least three independent testers in parallel - a user, an attacker and a strategist (or clearly equivalent roles); (2) all testers share one short brief naming who the site is for, the one job that must happen as an observable effect (e.g. the booking appears in the list or database, not just a success message), where to reach it, and what is off-limits; (3) testers are not given the builder's plan or implementation details; (4) every finding must come with an input or steps that reproduce it; (5) the attacker is limited to the local site and the plan stubs or forbids real emails, texts or payments; (6) it says to fix blockers and replay only their reproductions rather than re-running everything or opening a PR to get it reviewed.
