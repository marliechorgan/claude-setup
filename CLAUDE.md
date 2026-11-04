# Working on this repo

A Claude Code marketplace holding one plugin, `plugins/skills` (skills and agents), plus starter templates. It is public: everything committed here is published. The safety guards live in their own repository, `claude-safety-guards`.

## Checks (run before every commit)
- `python3 tools/build.py`: skill frontmatter (the claude.ai upload rules), links and each skill's own tests.
- `claude plugin validate .` and `claude plugin validate plugins/skills`.

## Rules
- **Nothing personal.** No real names, emails, company or client names, private paths, internal ids or real command history. Examples are invented (`~/Projects/app`, `example.net`, the "Northstar" companies).
- **Licences:** new files are MIT.
- **Skills:** frontmatter uses only `name`, `description`, `license` (the claude.ai upload accepts nothing else). The description is what decides whether a skill loads; change it deliberately and rerun the evals.
