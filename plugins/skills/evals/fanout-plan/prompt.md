---
tags: [fanout-brief]
max_turns: 15
allowed_tools: [Read, Write, Glob, Grep, Skill]
---
I want to use several Claude sub-agents in parallel on this and I'd like the plan first, written to plan.md (don't start anything):

Our booking chatbot needs three changes: (a) a new `cancel_booking` tool in tools/bookings.py, (b) the system prompt in prompts/assistant.md updated to describe cancelling, and (c) the web widget in web/widget.js showing a "Cancelled" badge, which reads the booking's `status` field. The chatbot uses a shared Postgres test database and runs on port 8000 locally.
