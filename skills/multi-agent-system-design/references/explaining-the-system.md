# Explain the system so its meaning is visible

Use this reference when presenting a design, writing a technical explanation or creating a diagram. Preserve useful complexity; remove decoding effort.

## Organise around capabilities

Keep runtime architecture distinct from the development sessions building it. Within runtime design, group related decisions: coordinating agent work; retrieving, selecting and submitting data; applying rules and checking outcomes. Put worktree ownership, persona testing and integration in a separate build section. Use section dividers when a long presentation changes capability or level of abstraction, rather than creating a divider for every individual slide.

Give each diagram one question to answer. Separate candidate discovery from record selection, and separate a worker's test architecture from an illustrative transcript when showing both would obscure either. A slide should make one claim, develop it in a short lead, and show its mechanism. Move substantial detail into notes or references.

## Choose labels that explain the data

Use recognisable examples such as **Blue Fluid**, **Racing Fluid 2**, **Northstar Leeds** and **Northstar Bristol**. Show the relevant catalogue field that supports the choice: a product name alone does not prove suitability. Label fictional attributes and conversations as illustrative.

Friendly display names and stable internal references serve different purposes. Explain once that implementation uses validated references; do not make readers decode arbitrary IDs to follow the diagram. Keep the same names and action semantics throughout. Creating a product enquiry, updating a company record, adding a line to an existing request and placing an order are different effects.

The examples should illustrate a general pattern. Headings can name the capability, while concrete records inside the diagram make it understandable. Do not turn the whole architecture into a special-purpose fluid sales system.

## Let position and arrows carry meaning

- For a coordinator, put the user message and response on the primary reading path. Put peer specialists beneath it, with separate delegation and return arrows.
- Use containment to show ownership: each build worker owns a worktree, its running test instance and its isolated test data. Show code on disk and the running process as distinct objects connected by start/deploy/restart.
- Put an external user reply outside the agent's reasoning box. Otherwise the diagram can suggest the agent invented missing intent.
- Show shared state before and after a meaningful update. Do not point refreshed consumers back into an unchanged card that still displays unresolved values.
- Keep a case and its expected outcome on the same visual lane. Show a shared runtime configuration without merging the identity of separate test runs.
- Label important branches: pass, blocked, unresolved or retry. Return failure evidence to the actor that can repair the cause. Include success exits as well as refinement loops.
- In conversation testing, draw messages and actual replies between tester and running application. Draw stored effects separately into acceptance checks. A box containing dialogue is a transcript, not the application process.

Do not draw optional retrieval methods as a mandatory serial pipeline. Avoid crossing arrows through captions. Prefer a visible connection with a short label over prose that asks the reader to imagine the connection.

## Review the rendered result

Inspect diagrams at their intended reading size. Check label fit, text size, branch direction, containment, state transitions and whether the purported evidence is actually connected to the claim. Layout bounds can catch clipping; human review must still catch a misleading arrow or conflated concept. Preserve the requested format and brand rather than imposing a universal diagram library, slide count or style.
