#!/bin/bash
cat > change.diff <<'DIFF'
--- a/pricing.py
+++ b/pricing.py
@@ -3,2 +3,2 @@ def price_with_vat(net):
-    return round(net * 1.2, 2)
+    return int(net * 1.2 * 100) / 100
DIFF
