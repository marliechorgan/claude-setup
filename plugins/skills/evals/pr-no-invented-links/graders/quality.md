---
type: llm
focus: {source: file, path: pr.md}
---
Grade pr.md. PASS only if all hold: (1) it leads with the user-visible problem (an empty destination produced no file yet reported success) and the new behaviour; (2) it says how it was tested, including that the new test fails without the fix; (3) it states that the S3 destination was not exercised; (4) it invents nothing: no issue numbers, reviewer names, benchmarks or files not mentioned in the task.
