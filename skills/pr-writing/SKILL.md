---
name: pr-writing
description: Write a pull request title and description a reviewer who never saw the conversation can assess quickly — the concrete problem, the resulting behaviour, how it was checked and what was left out. Use when drafting or opening a PR, preparing a branch for review, writing a PR for an open-source project, or rewriting a PR after its scope changed. Follows the target repository's template, branch and commit conventions. Drafting is not permission to push or open the PR.
license: MIT
---

# Write a reviewable pull request

Write for a reviewer triaging a queue who has not seen your conversation. Lead with what was wrong and what behaves differently now, then the evidence, then anything they must decide.

## Check the target first

Read the diff, the repository's contributing guide, any PR template under `.github/`, and the last dozen merged PR titles for the real house style. Confirm which branch takes contributions; don't assume `main` or trust a stale local ref. Look for a policy on AI-assisted contributions and follow it: some projects require disclosure, some hold agent-opened PRs as drafts until a human has reviewed them.

With no convention to follow, `area: imperative summary` makes a good title. Never invent reviewer names, issue links, decisions or dates.

## Write to the actual change

A small change can be two sentences and a test result. A larger one usually covers, in this order:

1. **What broke, for whom:** the concrete trigger, before and after.
2. **What the change is, and what it deliberately is not.** Naming what you left out shows you saw it and chose one change per PR.
3. **How it was tested:** what ran, what it establishes, what remains unmeasured. "The new test fails without the fix and passes with it" is the most persuasive sentence a bug-fix PR can contain.
4. **Rollout notes or an open question** for the reviewer, only if real.

Use the template when the repository has one. Cite line numbers only where a reviewer would click. Rewrite the title and body around the final implementation if the scope moved during the work.

When addressing several review comments, track each to its resolution; a small table helps when coverage would otherwise be hard to check.

## Keep it reviewable

Group changes that must land together; split independent ones when that makes review and rollback easier. A coherent change across many files is not automatically too big, and splitting dependent halves that each fail on their own is worse. If a check was already failing before your change, say so and whether you affected it; don't call everything green.

## Deliver

For a draft, return a finished, copyable title and body. When the user has authorised publishing, use the repository's normal flow, pass multi-line bodies through a file or the tool's body field rather than shell quoting, and confirm the PR opened against the right base. Stage only your own changes. Keep "drafted", "pushed", "opened", "approved" and "merged" distinct, and report only what actually happened.

> **Title:** exports: reject an empty destination before starting
>
> An export with an empty destination started and reported success without producing a file. This validates the destination before dispatch and returns an actionable error.
>
> The new test fails on main and passes here; a valid destination still produces a readable export. Delivery to production storage was not exercised.
