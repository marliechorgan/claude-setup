# Calibration scores

One line per crew or lens change. Black-box run against `app.py`, scored against `KEY.md`.

| Date | Change | Testers | Hits | Wall time | Missed |
|---|---|---|---|---|---|
| 2026-11-01 | first version | user, attacker, strategist, breaker | 8/10 | ~100 s | D2 reflected XSS in search, D4 prompt injection via notes |
| 2026-11-01 | attacker lens: reflected fields; several injection phrasings, read by another user | attacker replay | D2, D4 found (10/10 combined) | ~110 s | none |
