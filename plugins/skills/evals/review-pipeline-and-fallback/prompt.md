---
tags: [review-changes]
max_turns: 12
allowed_tools: [Read, Glob, Grep, Skill]
---
Can you review this diff before I merge it? It's the nightly job that computes the accuracy number we publish.

```diff
--- a/nightly.sh
+++ b/nightly.sh
@@
-python run_eval.py --out results.json
-if [ $? -ne 0 ]; then echo "eval failed"; exit 1; fi
+python run_eval.py --out results.json 2>&1 | tee eval.log
+if [ $? -ne 0 ]; then echo "eval failed"; exit 1; fi
 python publish.py results.json
--- a/publish.py
+++ b/publish.py
@@
 def accuracy(results):
-    return results["accuracy"]
+    return results.get("accuracy") or results.get("last_good_accuracy", 0.0)
```
