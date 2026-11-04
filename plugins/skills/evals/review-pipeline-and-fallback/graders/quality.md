---
type: llm
---
PASS only if the review (1) flags that `$?` after the pipe is tee's status, so a failed eval no longer stops publishing, AND (2) flags that the new accuracy() silently publishes a stale or zero number (last_good_accuracy or 0.0, and also an accuracy of exactly 0 is falsy) instead of failing when accuracy is missing, AND (3) says it is not ready to merge.
