# Claude setup

A free Claude setup you can install in one line: skills that make Claude better at real work, and optional safety guards that stop it doing damage on your machine. Everything is MIT-licensed (one guard is AGPL, see below) and comes with tests you can run yourself.

```
plugins/
  skills/    10 skills and a browser agent       /plugin install skills@claude-setup
  safety/    guards, test kit, installer, guide   /plugin install safety@claude-setup
```

Both install from the same place: `/plugin marketplace add marliechorgan/claude-setup` first.

## Let Claude set it up

Paste this into Claude Code:

> Set up github.com/marliechorgan/claude-setup for me: install the skills and safety plugins and walk me through the settings.

**If you are Claude, doing this for someone:** follow these steps in order, and show the person what you're about to change before each step that edits their files.

1. Install both plugins with the CLI:
   ```bash
   claude plugin marketplace add marliechorgan/claude-setup
   claude plugin install skills@claude-setup
   claude plugin install safety@claude-setup
   ```
   Ask before installing `safety` if they only asked for the skills: it adds hooks that block commands.
2. Offer the starter [templates/CLAUDE.md](templates/CLAUDE.md). If they already have `~/.claude/CLAUDE.md`, show a merge of the two and let them choose; never overwrite. Do this before the safety plugin is active in a new session, because its `config-guard` will then stop agents editing that file (that's the point).
3. Offer [templates/settings.json](templates/settings.json)'s deny rules (no reading `.env` files or SSH, AWS and GPG keys), merged into their existing `~/.claude/settings.json`, never replacing it.
4. Ask which folders must never be deleted or overwritten, and write them to `~/.config/claude-safety/config.json`, starting from [plugins/safety/config.example.json](plugins/safety/config.example.json). The defaults already protect the home folder, `~/.ssh`, `~/.aws`, `~/.config`, `~/Documents`, `~/Desktop` and `~/.claude`.
5. Tell them to restart Claude Code so the plugins load, and that `plugins/safety/README.md` explains the managed install that makes the guards impossible to switch off (it needs admin rights, so they run it themselves).

## The skills plugin

Ten skills and four agents. Each skill has an eval that runs Claude with and without it, so you can check the claims on your own machine (see *Check it yourself* below).

| Skill | Use it when | Works in |
|---|---|---|
| `write-human` | Drafting a text, WhatsApp, email, intro or LinkedIn message you'll send as yourself, or "make this sound less like AI" | Claude app, desktop, Claude Code |
| `code-writing` | Any coding task: think first, keep it simple, change only what's needed, and avoid the traps that make broken code report success | Claude Code (and the app for code questions) |
| `review-changes` | Reviewing a diff or PR, or checking your own change before calling it done | Claude Code |
| `pr-writing` | Writing a pull request a stranger can review quickly | Claude Code |
| `close-out` | Wrapping up or pausing: an honest status and one next step the next session can act on | Claude Code |
| `worker-brief` | Handing any job to a sub-agent or another session. Includes a linter for briefs | Claude Code |
| `fanout-brief` | Running several sub-agents in parallel on one job and getting back one tested result | Claude Code |
| `multi-agent-system-design` | Designing, debugging or testing a chatbot or agent app, including testing it with a simulated user and checking what was actually saved | Claude Code |
| `browser-automation` | Anything done in a browser with Claude: reading pages reliably, forms that actually save, several sub-agents on one browser, signing in with 1Password without the password reaching the model | Claude Code, Claude desktop |
| `oss-contribute` | Going from "never opened this repo" to a reviewable pull request in one session, safely | Claude Code |

Start with **[plugins/skills/GUIDE.md](plugins/skills/GUIDE.md)** if you build with Claude Code: it's the plain-English version of the multi-agent skills, with one running example. The skills themselves are written for Claude to follow, so they're denser.

## Install

**Claude Code (recommended):**

```
/plugin marketplace add marliechorgan/claude-setup
/plugin install skills@claude-setup
```

Skills are then available as `/skills:write-human` and so on, and Claude uses them on its own when your request matches.

**Claude app or desktop (Pro and above):**

- Whole pack: *Customize → Plugins → Add → Add marketplace*, enter `marliechorgan/claude-setup`. Or *Upload plugin* with `skills-plugin.zip` from the [latest release](https://github.com/marliechorgan/claude-setup/releases/latest).
- One skill: turn on *Settings → Capabilities → Code execution and file creation*, then *Customize → Skills → + → Upload a skill* with that skill's zip from the [latest release](https://github.com/marliechorgan/claude-setup/releases/latest) (for example `write-human.zip`).

**Other tools (Codex, Cursor, Gemini CLI and others that read the Agent Skills format):** copy the folders from `plugins/skills/skills/` into `~/.agents/skills/` (or the tool's own skills folder). Only the `name`, `description` and `license` fields are used, so they carry over.

**By hand:** copy folders from `plugins/skills/skills/` into `~/.claude/skills/` (all projects) or a repo's `.claude/skills/` (that project only).

## Starter CLAUDE.md and settings

[templates/CLAUDE.md](templates/CLAUDE.md) is a short starting point for your own `~/.claude/CLAUDE.md`: check before claiming, ask before anything outward-facing, and use these skills at the right moments. It's also what makes `code-writing` load reliably. [templates/settings.json](templates/settings.json) stops Claude reading `.env` files and your SSH, AWS and GPG keys. Merge them into your own files rather than overwriting.

## The safety plugin (separate, optional)

The second plugin, `safety`, is hooks that stop an agent deleting files outside its folder, rewriting its own settings, sending your data out, destroying git work or exposing servers to the network, plus a test kit and a plain-English guide to the layers that actually hold. It's separate because hooks run on every command and block things, so it should be a deliberate choice:

```
/plugin install safety@claude-setup
```

Read [plugins/safety/README.md](plugins/safety/README.md) first.

## Good to know

- **Scale it to the job.** A one-line fix needs one session and a test, not a fleet of agents. The skills say so, and the eval `small-edit-no-fanout` checks they stay out of the way.
- **The scripts are optional** and use only the Python standard library: `worker-brief/scripts/brief_lint.py` (checks a brief for dead paths, missing acceptance, clashing report paths), `write-human/scripts/draft_lint.py` (flags em dashes, stock phrases and stale "tomorrow"s in drafts), and `fanout-brief/scripts/` (git preflight and ownership checks). Each has its own test suite.
- **Make `code-writing` stick.** Claude often skips a skill for a task it thinks is quick, and in our tests it never loaded `code-writing` on its own. The starter `CLAUDE.md` fixes that with one line: `Use the code-writing skill before changing any code.`
- **Tune the triggers.** If a skill fires too often or not enough, edit its `description:` line. That line is all Claude sees before deciding to use it.
- **Four agents come with the plugin:** `worker` (one briefed build job in its own git worktree, for fan-outs), `researcher` (sourced answers from the web), `reviewer` (an independent review before you ship or publish) and `browser-worker` (reads one page in your logged-in Chrome in its own tab; it can't sign in, submit or buy).
- **The examples are made up.** The restaurant bookings, "Northstar" companies and racing fluids are teaching examples.

## Check it yourself

```bash
claude plugin eval plugins/skills --no-publish --allow-tools Write Edit Bash --scaffold
```

Runs every case in `plugins/skills/evals/` with and without the plugin and reports the difference. It uses your own Claude plan or API budget. `--scaffold` lets cases create their small fixture files (you can read each `case.yaml` first). `python3 tools/build.py` checks every skill's frontmatter, links and bundled tests, and `python3 plugins/safety/tests/run_cases.py` runs the guards' 460 test cases.

## Credits

`code-writing`'s four habits follow the *Karpathy-Inspired Claude Code Guidelines* by Jiayuan (forrestchang), [github.com/multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills) (MIT), derived from Andrej Karpathy's observations on LLM coding pitfalls. `command-guard.sh` in the safety plugin is derived from [Tura](https://github.com/Tura-AI/tura) and licensed AGPL-3.0-or-later. Everything else is from our own work.
