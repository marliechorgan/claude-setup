# Changelog

## 0.2.0 (safety)
- Guards brought up to date with fixes made in a production deployment since 30 Sep 2026: 161 new test cases (625 in all, up from 464). Each fix that closes a hole has a case that fails on 0.1.4.
- `command-guard`: a variable rebound in a way the guard did not track (`T+=`, `for T in`, `read T`, `printf -v T`, `declare -n`, `eval`, `${T:=}`, quoted spellings such as `declare "T=..."`) no longer lets `rm -rf "$T"` reach a protected folder. Deleting your own temp files works with `${TMPDIR:-/tmp}`, `${TMPDIR%/}`, a `cd "$(mktemp -d)" && pwd` folder, a temp path built in an earlier assignment, and the `/private` spelling macOS gives temp folders.
- `egress-guard`: blocks `curl --url-query @file`, `-G -d @file` and `--data-urlencode name@file`; `-G` no longer cancels `-T`/`-F` uploads; a backslash-newline can no longer split `curl` from its arguments; quotes inside `$(...)` no longer hide the rest of a command; `timeout -s KILL 30 curl` and shortened wget options (`--post-fi=`) are recognised.
- `config-guard`: blocks writes through sed `w`/`W`/`e`, a command word held in a variable, interpreter code piped into a shell, a module written then loaded, and programs `git -c` can name (aliases, pager, editor, sshCommand, credential.helper and similar).
- `ingress-guard`: a grep pattern or an escaped `\|` that only names `curl` or `gh pr view` is no longer treated as a web read.
- `tests/run_cases.py` now checks what a PostToolUse guard prints (`out`, `contains`, `lacks`), not only its exit code; keeps its fixture out of `/tmp`, so cases about leaving TMPDIR mean the same on Linux; and supports `platforms` for a case about one OS's paths.

## README
- README rewritten for newcomers: a five-minute start, a glossary, a map of the repository and the 18+ requirement for a Claude account.

## 0.1.4 (safety)
- `docs/how-it-works.html`: a visual walkthrough of every guard, with the real verdicts and messages, measured on 2 Oct 2026, and `docs/how-it-works.pdf`, a copy that reads on GitHub.
- README: the speed figure counts the guards running in parallel, as Claude Code runs them: about 0.15 seconds a shell command, not 0.3.

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
