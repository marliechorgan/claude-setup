---
tags: [worker-brief]
max_turns: 15
allowed_tools: [Read, Write, Glob, Grep, Skill]
---
I'm about to hand a job to a sub-agent and want you to write the prompt it will get. Save it to brief.md; don't run anything.

The job: our Flask app's `/search` endpoint (app/search.py, function `search_products`) times out for queries over 3 words. I think it's the N+1 query in the loop that fetches each product's supplier, but I haven't confirmed it. The sub-agent should find the cause and fix it. Tests run with `pytest tests/`. There's another agent working on app/checkout.py at the same time. It shouldn't push anything.
