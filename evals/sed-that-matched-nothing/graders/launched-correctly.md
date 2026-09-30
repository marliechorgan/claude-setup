---
type: regex
pattern: "b\\.yaml:learning_rate:\\s*(0\\.0003|3e-4)"
target: {source: file, path: launch.log}
---
