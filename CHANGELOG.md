# Changelog

## 0.1.3 (safety)
- The example settings allow no upload hosts. They used to allow `api.github.com`, `registry.npmjs.org` and `pypi.org`, and an agent can post any file to a public gist through the first of those. Add hosts deliberately.
- README: the known limits now name the publishing tools these guards don't judge (`git push`, `npm publish`, `twine upload`, and `gh` posting in attended sessions).

## 0.1.2 (safety)
- The guards now protect their own settings (`~/.config/claude-safety`) and the installed plugins (`~/.claude/plugins`), so an agent can't loosen or blank them.
- README: paste one sentence into Claude Code and it sets everything up, following step-by-step instructions written for it.

## 1.3.1 (skills)
- The fanout preflight falls back to the system `python3` when no virtual environment is active.
- The brief linter's tests run on Linux, where temporary folders live under `/tmp`.

## 1.3.0 (skills) · 0.1.1 (safety)
- Repository renamed to `claude-setup`; the skills plugin is now called `skills` (`/plugin install skills@claude-setup`).
- Both plugins now live under `plugins/`, so installing one copies only that plugin.
- New agents: `worker` (one briefed build job in its own git worktree), `researcher` (sourced answers from the web) and `reviewer` (an independent review before shipping).
- New `templates/`: a starter `CLAUDE.md` and a `settings.json` that denies reading secrets.
- Automatic checks on every push (macOS and Linux), a security policy and issue templates.

## 1.2.0
- The `safety` plugin: six guards, a guard wrapper, a test kit, a macOS managed-settings installer and a guide.

## 1.1.0
- `browser-automation` skill and `browser-worker` agent.

## 1.0.0
- Nine skills.
