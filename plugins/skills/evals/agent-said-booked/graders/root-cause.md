---
type: regex
flags: "i"
pattern: "(branch_id\\s+is\\s+None|branch.{0,40}(None|missing|unresolved|pending)|\"ok\"\\s*:\\s*True)"
target: {source: file, path: diagnosis.md}
---
