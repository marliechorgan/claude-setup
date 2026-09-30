# Changelog

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
