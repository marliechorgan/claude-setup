---
name: build-fast
description: The default route from "build me X" to something working that a real person can judge - a new app, tool, AI agent or workflow, prototype, MVP, demo or substantial feature - as fast as possible without fooling yourself. Use when the user says build, make, prototype, spin up, get this working, MVP, demo by a date, as fast as possible, or hands over an idea to turn into software. Sequences the other skills - outcome and outside verdict first, the riskiest unknown spiked in minutes, a thin end-to-end version, parallel workers only for independent pieces, the test-crew on the running thing, and a short evidence page - so the session spends its time on what moves the result. Not for a small fix or edit (code-writing alone) or for the mechanics of splitting work across workers (fanout-brief).
license: MIT
---

# Build fast

Get from an idea to something a real person can use and judge, quickly, with evidence that it works. Most build time is lost in five places: building before knowing who will judge it, scaffolding around an unknown that later kills the idea, splitting work that depends on itself, checking text instead of running the thing, and polishing before anyone outside has looked. Each step below removes one.

## 1. Name the verdict (two minutes)

Write three lines before any code: **who judges it** (a named user, customer, owner or reviewer), **what they do with it** in one observable sentence ("books a table and sees it in My bookings"), and **by when**. If nobody outside can judge it this week, say what the smallest judgeable version is and build that instead.

## 2. Kill the biggest unknown first (minutes)

List what could make this impossible or worthless: an API that can't do it, a model that can't follow it, data you can't get, a performance wall. Spike the worst one in a scratch file, one session, no structure. Stop or change course if it fails; that is the cheapest result you will ever get.

## 3. Build the thin version end to end

One real path from the real entry point through real storage to the real output, ugly but working, before any second feature. For an AI agent, that is one real conversation that causes one real saved effect. Freeze the contracts the rest will lean on (API shapes, schema, a fixture or two) as soon as this path works.

## 4. Split only what is independent

With the contracts frozen, independent pieces (a screen, an integration, a data import) go to workers in their own worktrees, in one message, one level deep; tightly coupled work stays with one owner. If you cannot name what each extra worker buys, use fewer. Mechanics, ownership and recombination: **fanout-brief**; each brief: **worker-brief**. Read-only research and prior-art checks can run beside the build from the start.

## 5. Test the running thing, then replay

At each "it runs" point, send the **test-crew** (a user, an attacker, a strategist) at the running build: minutes, local, every finding reproducible. Fix blockers, replay only their reproductions, keep them as the project's regression set. For an agent app, **multi-agent-system-design** says what to assert about stored effects. A pull request is for merging finished work, not for finding out whether it works.

## 6. Hand over something judgeable

A URL or command that runs, a short demo path, and a one-screen evidence note: what it does, what the crew tested and found, what was fixed and replayed, what is untested or mocked. That note is what makes a build trustworthy to a stranger, and it is usually more persuasive than the feature list. Then **close-out**.

## Rules of thumb

- Time-box each step and say when one overruns; a spike that needs a second day is an answer.
- Reuse before building: an existing library, service, template or skill beats new code, and new machinery around the build (dashboards, gates, trackers) waits until someone outside has judged the thing itself.
- Ask the person only for what the machine cannot check or decide: taste, access, money, people. Everything else, check and carry on.
- Code enforces, tests prove, AI testers find. A model's "done" is a claim until a check of the saved effect says so.
