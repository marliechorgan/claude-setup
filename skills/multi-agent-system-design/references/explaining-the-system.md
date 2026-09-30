# Explain the system

For design talks, write-ups and diagrams: keep the useful complexity, remove the decoding effort.

## Organise around capabilities

Keep the runtime apart from the build that changes it. Group runtime decisions by capability: coordinating agents; retrieving, selecting and submitting data; applying rules and checking outcomes. Worktree ownership, persona testing and integration get their own build section. Divide sections when capability or abstraction level changes, not per slide.

Each diagram answers one question. Separate candidate discovery from record selection, and a test setup from an example transcript when one would hide the other. One claim per slide, a short lead, then the mechanism; detail goes in notes.

## Labels that explain the data

- Use recognisable example names (**Blue Fluid**, **Racing Fluid 2**, **Northstar Leeds**, **Northstar Bristol**) and show the catalogue field behind the choice; a name alone doesn't prove suitability. Mark invented data and dialogue as illustrative.
- Show readable names; say once that the code uses validated references, not IDs readers must decode.
- Keep names and action meanings consistent: creating an enquiry, updating a company record, adding a line to an existing request and placing an order are different effects.
- Headings name the general capability; the example records inside only illustrate it.

## Let position and arrows carry meaning

- Coordinator: user message and response on the main path, specialists beneath, with separate delegation and return arrows.
- Containment shows ownership: each build worker owns a worktree, its running test instance and its test data. Code on disk and the running process are separate boxes, joined by start/deploy/restart.
- Put the user's reply outside the agent's reasoning box, or the missing intent looks invented.
- Show shared state before and after an update; never point refreshed consumers at a stale card still showing unresolved values.
- A case and its expected outcome share a lane; shared runtime configuration doesn't merge separate test runs.
- Label branches (pass, blocked, unresolved, retry); route failure evidence to whoever can fix it; draw success exits as well as loops.
- In conversation testing, messages and real replies run between tester and running app; stored effects feed the acceptance checks separately. A box of dialogue is a transcript, not the application.
- Don't draw optional retrieval methods as a mandatory pipeline, or arrows through captions. A labelled connection beats prose.

## Review the rendered result

Check at reading size: label fit, text size, branch direction, containment, state transitions, and whether the evidence connects to the claim. Layout checks catch clipping; only a human catches a misleading arrow or merged concepts. Keep the requested format and brand.
