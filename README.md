# Working skills

Nine Claude skills for doing real work with AI: briefing sub-agents, running several at once, building and testing agent apps, writing and reviewing code that doesn't fail silently, wrapping up a session cleanly, contributing to open source, and writing messages that sound like you rather than like a chatbot.

Free to use, change and share (MIT). Each skill ships with an eval that compares Claude with and without it, so you can check the claims below on your own machine.

## What's in it

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
| `oss-contribute` | Going from "never opened this repo" to a reviewable pull request in one session, safely | Claude Code |

Start with **[GUIDE.md](GUIDE.md)** if you build with Claude Code: it's the plain-English version of the multi-agent skills, with one running example. The skills themselves are written for Claude to follow, so they're denser.

## Install

**Claude Code (recommended):**

```
/plugin marketplace add OWNER/working-skills
/plugin install working-skills@working-skills
```

Skills are then available as `/working-skills:write-human` and so on, and Claude uses them on its own when your request matches.

**Claude app or desktop (Pro and above):**

- Whole pack: *Customize → Plugins → Add → Add marketplace*, enter `OWNER/working-skills`. Or *Upload plugin* with `working-skills-all.zip`.
- One skill: turn on *Settings → Capabilities → Code execution and file creation*, then *Customize → Skills → + → Upload a skill* with that skill's zip from the release (for example `write-human.zip`).

**Other tools (Codex, Cursor, Gemini CLI and others that read the Agent Skills format):** copy the folders from `skills/` into `~/.agents/skills/` (or the tool's own skills folder). Only the `name`, `description` and `license` fields are used, so they carry over.

**By hand:** copy folders from `skills/` into `~/.claude/skills/` (all projects) or a repo's `.claude/skills/` (that project only).

## Good to know

- **Scale it to the job.** A one-line fix needs one session and a test, not a fleet of agents. The skills say so, and the eval `small-edit-no-fanout` checks they stay out of the way.
- **The scripts are optional** and use only the Python standard library: `worker-brief/scripts/brief_lint.py` (checks a brief for dead paths, missing acceptance, clashing report paths), `write-human/scripts/draft_lint.py` (flags em dashes, stock phrases and stale "tomorrow"s in drafts), and `fanout-brief/scripts/` (git preflight and ownership checks). Each has its own test suite.
- **Tune the triggers.** If a skill fires too often or not enough, edit its `description:` line. That line is all Claude sees before deciding to use it.
- **The examples are made up.** The restaurant bookings, "Northstar" companies and racing fluids are teaching examples.

## Check it yourself

```bash
claude plugin eval . --no-publish --allow-tools Write Edit Bash --scaffold
```

Runs every case in `evals/` with and without the pack and reports the difference. It uses your own Claude plan or API budget. `--scaffold` lets cases create their small fixture files (you can read each `case.yaml` first). `python3 tools/build.py` checks every skill's frontmatter, links and bundled tests.

## Credits

`code-writing`'s four habits follow the *Karpathy-Inspired Claude Code Guidelines* by Jiayuan (forrestchang), [github.com/multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills) (MIT), derived from Andrej Karpathy's observations on LLM coding pitfalls. Everything else is from our own work.
