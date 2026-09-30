---
type: llm
focus: {source: file, path: diagnosis.md}
---
Grade diagnosis.md. PASS only if ALL hold: (1) it identifies that create_booking returns ok:true without writing anything when the branch is missing, so "ok" does not mean a booking exists; (2) the fix enforces it in code (e.g. return a not-booked/needs-branch status or refuse) rather than relying only on prompt wording; (3) it notes the prompt rule "never ask for information already given" pushes the model not to ask which branch, and that "the usual place" is unresolved intent that needs a question; (4) the test plan checks the stored database state (no booking before the branch is known, exactly one correct booking after), not just the assistant's reply; (5) it proposes a conversation-level test, e.g. a simulated customer who pushes to skip the question.
