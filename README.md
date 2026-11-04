# Claude setup

[![checks](https://github.com/marliechorgan/claude-setup/actions/workflows/checks.yml/badge.svg)](https://github.com/marliechorgan/claude-setup/actions/workflows/checks.yml)

A free add-on pack for [Claude Code](https://code.claude.com/docs/en/overview), Anthropic's coding agent. It gives Claude **skills** (step-by-step know-how for jobs like reviewing code, briefing helper agents or writing a message that sounds like you) and **agents** (helpers it can hand a job to). Everything is free and open source, and comes with tests you can run yourself.

**Looking for the safety guards?** They now have their own repository: [claude-safety-guards](https://github.com/marliechorgan/claude-safety-guards), the checks that stop Claude deleting your files, leaking your data or wrecking your git history.

## Start here (about 5 minutes)

**1. Get Claude Code.** Follow Anthropic's [quickstart](https://code.claude.com/docs/en/quickstart). If you've never used a terminal, their [terminal guide](https://code.claude.com/docs/en/terminal-guide) shows how to open one and paste a command. You need a Claude account on a paid plan (or an Anthropic API account), and Anthropic's terms require you to be **18 or over** to have one.

**2. Install this pack.** In a terminal:

```bash
claude plugin marketplace add marliechorgan/claude-setup
claude plugin install skills@claude-setup
```

Or, inside a Claude Code session, type `/plugin marketplace add marliechorgan/claude-setup` and then `/plugin install skills@claude-setup`.

**3. Restart Claude Code**, open it in a project folder (`cd my-project` then `claude`) and try one of these:

- *"Review my last change before I commit it."* (uses `review-changes`)
- *"Help me reply to this message so it sounds like me: …"* (uses `write-human`)
- *"I'm done for today, wrap this up so I can pick it up tomorrow."* (uses `close-out`)

Claude picks the right skill by itself when your request matches. You can also call one by name, for example `/skills:write-human`.

**4. Optional: add the safety guards.** Worth it once you let Claude run commands without asking you each time. They're a separate install, because they run on every command and can block things: see [claude-safety-guards](https://github.com/marliechorgan/claude-safety-guards).

### Words you'll see

| Word | What it means here |
|---|---|
| **Skill** | A folder with a `SKILL.md` file: instructions Claude loads when a task matches. Think of it as a checklist an expert would follow. |
| **Agent** (or sub-agent) | A second Claude that the main one hands a job to, with its own instructions and tools. |
| **Plugin** | A bundle of skills and agents you install in one go. This repo holds one. |
| **Marketplace** | A list of plugins Claude Code can install from. This repo is one, called `claude-setup`. |

## What's inside

```
plugins/
  skills/          the skills plugin
    skills/          12 skills, one folder each (SKILL.md plus any scripts)
    agents/          7 agents: worker, researcher, reviewer, browser-worker, ux-tester, pentester, strategist
    evals/           tests that run Claude with and without each skill
    GUIDE.md         plain-English guide to the multi-agent skills
templates/
  CLAUDE.md        a starter set of instructions for Claude
  settings.json    settings that stop Claude reading your secret files
tools/build.py     checks every skill is well formed
```

## The skills

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
| `build-fast` | Turning an idea into something working that a real person can judge, fast: the verdict first, the riskiest unknown spiked in minutes, a thin end-to-end version, helpers only for independent pieces, the test crew, a short evidence note | Claude Code |
| `test-crew` | Finding out in minutes whether a running app, tool or agent works: a simulated user, an attacker and a strategist test it in parallel on your machine, each finding with a way to reproduce it | Claude Code |
| `oss-contribute` | Going from "never opened this repo" to a reviewable pull request in one session, safely | Claude Code |

The seven agents: `worker` (one briefed build job in its own git worktree), `researcher` (sourced answers from the web), `reviewer` (an independent review before you ship or publish), `browser-worker` (reads one page in your logged-in Chrome in its own tab; it can't sign in, submit or buy), and the test crew's `ux-tester`, `pentester` and `strategist` (they test a running app on your own machine and never edit it).

If you build with Claude Code, read **[plugins/skills/GUIDE.md](plugins/skills/GUIDE.md)** next: it explains the multi-agent skills with one running example. The skills themselves are written for Claude to follow, so they're denser.

## Make it yours

- **Starter instructions.** [templates/CLAUDE.md](templates/CLAUDE.md) is a short starting point for your own `~/.claude/CLAUDE.md`: check before claiming, ask before anything outward-facing, use these skills at the right moments. If you already have one, merge the two rather than overwriting.
- **Keep secrets out.** [templates/settings.json](templates/settings.json) stops Claude reading `.env` files and your SSH, AWS and GPG keys. Merge it into your `~/.claude/settings.json`.
- **Make `code-writing` stick.** Claude often skips a skill for a task it thinks is quick; in our tests it never loaded `code-writing` on its own. The starter `CLAUDE.md` fixes that with one line: `Use the code-writing skill before changing any code.`
- **Tune the triggers.** If a skill fires too often or not enough, edit its `description:` line. That line is all Claude sees before deciding to use it.
- **Scale it to the job.** A one-line fix needs one session and a test, not a fleet of agents. The skills say so, and the eval `small-edit-no-fanout` checks they stay out of the way.

## Let Claude set it up for you

Paste this into Claude Code:

> Set up github.com/marliechorgan/claude-setup for me: install the skills and walk me through the settings.

**If you are Claude, doing this for someone:** follow these steps in order, and show the person what you're about to change before each step that edits their files.

0. Check first: list any skills they already have with the same names (`ls ~/.claude/skills`).
1. Install the plugin with the CLI:
   ```bash
   claude plugin marketplace add marliechorgan/claude-setup
   claude plugin install skills@claude-setup
   ```
2. Offer the starter [templates/CLAUDE.md](templates/CLAUDE.md). If they already have `~/.claude/CLAUDE.md`, show a merge of the two and let them choose; never overwrite.
3. Offer [templates/settings.json](templates/settings.json)'s deny rules (no reading `.env` files or SSH, AWS and GPG keys), merged into their existing `~/.claude/settings.json`, never replacing it.
4. Tell them to restart Claude Code so the plugin loads. If they let Claude run commands without asking, mention [claude-safety-guards](https://github.com/marliechorgan/claude-safety-guards), and let them decide.

## Other ways to install

- **Claude app or desktop (Pro and above).** Whole pack: *Customize → Plugins → Add → Add marketplace*, enter `marliechorgan/claude-setup`, or *Upload plugin* with `skills-plugin.zip` from the [latest release](https://github.com/marliechorgan/claude-setup/releases/latest). One skill: turn on *Settings → Capabilities → Code execution and file creation*, then *Customize → Skills → + → Upload a skill* with that skill's zip from the latest release (for example `write-human.zip`).
- **Other tools that read the Agent Skills format** (Codex, Cursor, Gemini CLI and others): copy the folders from `plugins/skills/skills/` into `~/.agents/skills/` or the tool's own skills folder. Only the `name`, `description` and `license` fields are used, so they carry over.
- **By hand:** copy folders from `plugins/skills/skills/` into `~/.claude/skills/` (all projects) or a project's `.claude/skills/` (that project only).

## Check it yourself

```bash
python3 tools/build.py      # every skill's frontmatter, links and bundled tests
claude plugin eval plugins/skills --no-publish --allow-tools Write Edit Bash --scaffold
```

The first needs only Python 3 and runs in seconds; it also runs on every push. The second runs every case in `plugins/skills/evals/` with and without the plugin and reports the difference. It uses your own Claude plan or API budget; `--scaffold` lets cases create their small fixture files (you can read each `case.yaml` first).

The scripts inside the skills are optional and use only the Python standard library: `worker-brief/scripts/brief_lint.py` (checks a brief for dead paths, missing acceptance, clashing report paths), `write-human/scripts/draft_lint.py` (flags em dashes, stock phrases and stale "tomorrow"s in drafts) and `fanout-brief/scripts/` (git preflight and ownership checks). Each has its own tests. The examples in the skills (restaurant bookings, "Northstar" companies, racing fluids) are made up for teaching.

## Contributing and licences

Bug reports and cases where a skill steers wrong are the most useful contributions: see [CONTRIBUTING.md](CONTRIBUTING.md), and [SECURITY.md](SECURITY.md) for reporting a security problem.

Everything is MIT-licensed. `code-writing`'s four habits follow the *Karpathy-Inspired Claude Code Guidelines* by Jiayuan (forrestchang), [github.com/multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills) (MIT), derived from Andrej Karpathy's observations on LLM coding pitfalls. Everything else is our own work.
