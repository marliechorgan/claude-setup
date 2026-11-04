# Changelog

## 1.6.0 (skills)
- The safety guards moved to their own repository, [claude-safety-guards](https://github.com/marliechorgan/claude-safety-guards). This repo now holds the skills, agents and templates only, all MIT. If you installed `safety@claude-setup`, its README has the two-line switch.
- `close-out`: the description now says what the skill does: reads which kind of close-out was asked for, looks back on the setup and ends the session where it can.
- `browser-automation`: where to call autofill, and the remaining 1Password failure codes (`transport_error`, `decode`, `not_connected`, `disabled_by_policy`).
- `browser-worker`: page scripts stay on the task's own origin and never read cookies, storage, tokens or typed form values.
- The plugin and marketplace descriptions give the right counts: twelve skills and seven agents.

## 1.5.0 (skills)
- New `build-fast` skill: the default route from "build me X" to something a real person can judge. Name the verdict, kill the biggest unknown first, build the thin version end to end and freeze its contracts, split only what is independent, test the running thing with `test-crew` and replay, hand over a one-screen evidence note.
- New `test-crew` skill and three agents (`ux-tester`, `pentester`, `strategist`): send independent AI testers in parallel at the running app, tool, agent or plan on your own machine, in minutes, each finding with a reproduction; fix blockers and replay only their reproductions; keep them in `.crew/probes.md` as a regression set grown from real failures. Ships a practice app with planted defects (`calibration/`) and a check that proves each is present, so the crew itself can be scored after any change. `code-writing`, `review-changes` and `multi-agent-system-design` point to it. Evals: `test-crew-plan`, `test-crew-not-for-diff`.
- `review-changes`: investigate by running, not by reading. Six checks in the order independent review finds defects (attack each new check across its input class, look for another route around a guard, open every reader of what changed with `code-writing`'s `consumers.py`, check the claims, run it twice / together / late, make the evidence fail on main), then a blocking bar: worse than main, or breaks the change's own claim, with the input that reproduces it. The description now says this.
- `close-out`: read which close-out was asked for (park now, close out, or finish everything first); apply facts the user corrected; record the next step in a file, not the chat; a look-back that fixes what is local and checkable now and logs the rest for a later batch; end the session where the environment allows; a report that puts what the user must do in its own short list and never ends on an offer.
- `fanout-brief`: covers work that isn't code (new `references/non-code-work.md`: research, decisions, audits, drafts, accounts and gathering across channels, each with its acceptance, independent check and way to recombine). One lead and one level of workers by default; effort sized to the question; one named writer per mutable thing; a return contract with a plain-text fallback, and read-only workers return inline; task and progress ledgers with a stall counter; the doer never verifies its own work. Nesting limits and hand-back in `execution-modes.md`; times in the run record come from `date`. The description now names non-code work.
- `worker-brief`: acceptance for non-code work (a draft's facts and sources, an audit's definition and denominator, the end state of a task in the world); point at where the answer lives rather than the topic; budgets sized to the job and a default of no helpers; a report path with a plain-text fallback, and inline returns for read-only workers. A read-only research example in the template.
- `worker-brief` lint: a heading with text after its colon (`## Write scope: these files only`) counts as a write scope, and titles such as `## W6 report: ...` still name no section. Three tests; the first fails on 1.4.0.
- `write-human`: dates are short and checked on the day the draft goes ("tomorrow" is fine in a message sent the day it is written); an email or update opens on the one point it must land, then one or two proof points; never supply a reason, news or apology the sender did not give; read the live thread when its state matters. The lint's date hint asks whether the draft goes today, with a test. The description now says time words are checked against the day the draft is sent.
- `multi-agent-system-design`: one lead and one level of workers by default; task and progress ledgers with a stall counter; start a model judge on about 20 real cases with a person reading its verdicts.
- `oss-contribute`: re-quarantine in every new worktree; a PR into an existing PR's branch is a valid contribution, with `owner/repo#N` references in a fork; check `gh` credentials before trusting an empty list.
## 1.4.0 (skills)
- `code-writing`: a pre-submit pass aimed at what independent review most often finds. An independent reviewer read 201 machine-written pull requests and blocked 91 (471 blocking findings): a matcher that missed real spellings or over-matched (28%), a guard with another route around it (23%), a broken caller (12%), a claim the code does not meet (9%). The pass: list every reader of a contract you changed (`scripts/consumers.py` finds candidates and flags callers that discard the status), run each check over its whole input class, list the other routes to the effect a guard prevents, and think through twice / together / late.
- `code-writing`: check the premise before building on it; keep the invariant the code already embodies; add no limit nobody asked for; prefer a structured signal to a text match; a caller that ignores the status turns a refusal into silence; and a "Say what changed" section for reports written for someone who wasn't watching. Replayed on real cases, the new text beat the old 6 to 2 in blind comparisons.

## README
- README rewritten for newcomers: a five-minute start, a glossary, a map of the repository and the 18+ requirement for a Claude account.

## 1.3.1 (skills)
- The fanout preflight falls back to the system `python3` when no virtual environment is active.
- The brief linter's tests run on Linux, where temporary folders live under `/tmp`.

## 1.3.0
- Repository renamed to `claude-setup`; the skills plugin is now called `skills` (`/plugin install skills@claude-setup`).
- The plugin now lives under `plugins/`, so installing it copies only the plugin.
- New agents: `worker` (one briefed build job in its own git worktree), `researcher` (sourced answers from the web) and `reviewer` (an independent review before shipping).
- New `templates/`: a starter `CLAUDE.md` and a `settings.json` that denies reading secrets.
- Automatic checks on every push (macOS and Linux), a security policy and issue templates.

## 1.2.0
- The `safety` plugin, now in its own repository, `claude-safety-guards`.

## 1.1.0
- `browser-automation` skill and `browser-worker` agent.

## 1.0.0
- Nine skills.
