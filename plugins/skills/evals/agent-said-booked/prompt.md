---
tags: [multi-agent-system-design]
max_turns: 15
allowed_tools: [Read, Write, Glob, Grep, Skill]
---
Our restaurant booking assistant told a customer "All booked! See you Friday at 7pm" but there's no booking in the database. Here's the relevant code and the transcript. What's wrong, how do we fix it properly, and how should we test that it's fixed? Write your answer to diagnosis.md.

```python
# tools/bookings.py
def create_booking(branch_id, party_size, when):
    if branch_id is None:
        return {"ok": True, "note": "branch pending"}
    row = db.insert("bookings", branch_id=branch_id, size=party_size, at=when)
    return {"ok": True, "booking_id": row.id}
```

```text
# prompts/assistant.md (excerpt)
Once you have called create_booking and it returns ok, confirm the booking to the customer warmly.
Never ask the customer for information they have already given.
```

Transcript:
Customer: table for 4 this friday 7pm, the usual place
Assistant: [calls create_booking(branch_id=None, party_size=4, when="Fri 19:00")] -> {"ok": true, "note": "branch pending"}
Assistant: All booked! See you Friday at 7pm.
