# Working on this repo

A Claude Code marketplace with two plugins: `plugins/skills` (skills and agents) and `plugins/safety` (guard hooks). It is public: everything committed here is published.

## Checks (run before every commit)
- `python3 tools/build.py`: skill frontmatter (the claude.ai upload rules), links and each skill's own tests.
- `python3 plugins/safety/tests/run_cases.py` and `python3 plugins/safety/tests/test_guard_run.py`: every guard's cases and the wrapper.
- `claude plugin validate .` and `claude plugin validate plugins/<name>`.

## Rules
- **Nothing personal.** No real names, emails, company or client names, private paths, internal ids or real command history. Examples are invented (`~/Projects/app`, `example.net`, the "Northstar" companies).
- **Test cases are synthetic.** Never add cases taken from real transcripts.
- **Guards:** follow `plugins/safety/CONTRACT.md` (exit 2 + a `DO THIS INSTEAD:` line to block, fail open on uncertainty, stdlib Python via `python3 -I -S`, bash 3.2). Every protection gets an allow case and a block case, including disguised forms.
- **Licences:** new files are MIT. `plugins/safety/guards/command-guard.sh` is AGPL-3.0-or-later (derived from Tura); keep its header.
- **Skills:** frontmatter uses only `name`, `description`, `license` (the claude.ai upload accepts nothing else). The description is what decides whether a skill loads; change it deliberately and rerun the evals.
