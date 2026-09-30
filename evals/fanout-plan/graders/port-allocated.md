---
type: regex
pattern: "8000[^\\n]{0,160}(only|reserved|lead|combined|single|one at a time|shared)|(only|reserved|single|one at a time)[^\\n]{0,160}8000"
flags: "i"
target: {source: file, path: plan.md}
---
