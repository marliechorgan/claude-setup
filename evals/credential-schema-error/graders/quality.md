---
type: llm
---
PASS only if the answer identifies the over-long `reason` field (about 150+ characters) as the most likely cause of invalid/schema, tells the user to cut it to a short single clause (roughly under 100 characters), and says re-pairing is not the fix. FAIL if it mainly recommends re-pairing, reinstalling or checking permissions.
