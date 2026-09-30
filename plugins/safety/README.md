# Safety guards for Claude Code

Hooks that stop an agent doing damage on your machine, a test kit to check them, and a guide to the layers that actually hold. Built for people who let Claude Code run with few permission prompts, or unattended.

## Install

```
/plugin marketplace add marliechorgan/claude-setup
/plugin install safety@claude-setup
```

Then read the "How to set it up well" section below: the defaults are sensible, but a plugin's hooks can be switched off by a determined agent, and the managed install closes that.

## What each guard does

| Guard | Runs on | Blocks |
|---|---|---|
| `command-guard` | Bash | Recursive, forced or batch deletes, moves over, truncation and wiping outside the session folder and temp, and anything touching a protected folder, however the command is disguised (`rm -fr ~`, `X=rm; $X -rf ~`, `bash -c "…"`, `find -delete`, `rsync --delete`, Python `shutil.rmtree`); disk, partition and power commands; deleting backups; download-and-run (`curl … \| sh`) |
| `config-guard` | Bash, Write, Edit | The agent changing its own rules (Claude settings, hooks, agents, skills, `CLAUDE.md`, shell start-up files, SSH config, git hooks) or writing secret files (`.env`, keys) |
| `egress-guard` | Bash, WebFetch | Sending local data to a host you haven't allowed: uploads and posts with curl or wget, `nc`, `scp`/`rsync` to remote machines |
| `git-guard` | Bash | Git commands that destroy work: `reset --hard`, `clean -f`, `checkout .`, `restore .`, `stash drop/clear`, `push --force` (`--force-with-lease` is allowed), `branch -D` |
| `listen-bind-guard` | Bash | Dev servers and tunnels exposed beyond your machine (`0.0.0.0`, `--host 0.0.0.0`, ngrok, cloudflared) |
| `ingress-guard` | Web fetches, web search, MCP tools (add `Bash` to its matcher in `hooks/hooks.json` to also scan `curl` output) | Hidden instructions in fetched content: invisible Unicode, tag characters, bidirectional controls |
| `guard-run` | every guard | Runs each guard, keeps a log of what it blocked, and refuses to proceed if a guard file is missing, empty or half-written |

Every block tells Claude what to do instead, so the work carries on safely rather than stalling.

**Letting one command through.** A blocked command can be re-run with the prefix `CLAUDE_GUARD_OVERRIDE='why' `, and the reason is logged. Be clear about what this is: Claude writes the commands, so it can add the prefix too. It's a logged speed bump that makes the agent stop and state a reason, not a lock. It is never accepted for the agent's own settings, hooks or instructions (config-guard), or for the hard floors (protected folders, disks, backups). To refuse all overrides, set `CLAUDE_SAFETY_UNATTENDED=1`, which is also the right setting for scheduled and headless runs.

**Settings.** Copy `config.example.json` to `~/.config/claude-safety/config.json` and edit it: the folders that must never be deleted, where deletes are fine, your agent's control files, secret file patterns, and hosts data may be sent to. See [CONTRACT.md](CONTRACT.md).

## How to set it up well: the layers

No single control is enough. These are the layers, weakest first, and what each one is actually good for.

**1. Permission allow and deny lists match text, so they are easy to get round.** `Bash(rm -rf /)` in a deny list does nothing about `rm -fr ~`, `rm -rf $HOME` or `bash -c "rm -rf ~"`. Use them for convenience (fewer prompts), not as the safety boundary.

**2. Auto mode's classifier is a model.** It catches a lot, including things no pattern can, and it is a good second opinion. But it is not deterministic, so it can't be the only line.

**3. Hooks that judge the effect, not the words.** A guard should work out what a command would *do* (which file it would delete, where data would go) and decide on that. That's what these guards do: they unwrap `sh -c`, follow variables and `cd`, and treat every way of destroying a file as one thing.

**4. A guard that breaks must not fail silently.** In Claude Code a hook that crashes (any exit code other than 2) is non-blocking: the command runs and nothing tells you the guard is broken. A guard file caught half-written allows everything. `guard-run` refuses when a guard is missing or damaged, and logs every crash as a "break" so you can see it.

**5. The agent can switch hooks off, unless they're managed.** A session can start a child `claude` that doesn't load your user settings (`--setting-sources`), pass `--settings '{"disableAllHooks":true}'`, or simply edit `~/.claude/settings.json`. Claude Code's docs say **managed settings** still apply in all those cases, and a hook also inherits whatever environment it's started with (a fake `python3` on `PATH`, `BASH_ENV`, `PYTHONPATH`). On macOS, [managed/](managed/) installs these guards as managed settings with admin rights and runs them through a launcher that clears those variables. `config-guard` also stops the agent editing the settings files in the first place.

**6. Keep secrets out of files the agent reads.** A `.env` in the project is one `cat` away from the conversation. Keep keys in the macOS Keychain or a password manager and load them into the environment of the process that needs them, never into a prompt. For signing an agent into websites, 1Password's agentic autofill fills the page without the password ever reaching the model (see the `browser-automation` skill in this marketplace's `skills` plugin).

**7. Split identities in the browser.** An agent holding your logged-in cookies that reads an untrusted web page is the exact shape of prompt-injection attacks on AI browsers. Use a separate, logged-out browser for general browsing and research, and your real profile only for specific tasks on sites you know.

**8. Be stricter when nobody's watching.** Set `CLAUDE_SAFETY_UNATTENDED=1` for scheduled and headless runs. Overrides are refused there, because nobody is present to mean them.

**9. Test your guards like an attacker, and for over-blocking.** A guard that passes its own tests can still miss a reshaped command, and a guard that blocks ordinary work gets switched off by its owner. The [test kit](test-kit/) probes any guard with dozens of disguised forms (reporting HOLES and OVER-BLOCKS), and replays your own past commands through an old and a new version so you can see what a change would have blocked.

**10. Know what guards can't do.** An agent that can write and run code can in principle do anything your user account can; guards raise the cost and catch the common and the accidental. For untrusted work (a stranger's repository, a scraped page you'll act on), use a container or a separate machine account. When you clone someone else's repo, rename its `CLAUDE.md`, `AGENTS.md` and `.claude/` before working in it (the `oss-contribute` skill in the `skills` plugin does this), because they load as instructions.

## Known limits

- **Speed.** Each guard is a short Python run, so every shell command pays roughly 0.3 seconds in total across the five Bash guards (measured on an M-series Mac). Remove a guard from `hooks/hooks.json` if you don't need it.
- **Commands built at run time.** Text generated by `sed`, `awk` or a file and piped into `sh` is only partly visible to the guards; a script file the agent writes and then runs is judged by how it's run, not by what's inside it.
- **Scripting other apps.** On macOS an agent could ask Terminal or another app to run a command via AppleScript, outside Claude's own tools. These guards don't cover that; don't grant Claude automation permission over Terminal.
- **Docker ports.** `docker run -p 5432:5432` is blocked because Docker publishes to every network interface by default. Use `-p 127.0.0.1:5432:5432`.
- **A short secret in a short URL** can still leave through `egress-guard`; long query strings are only blocked in unattended mode.

## Test it

```bash
python3 tests/run_cases.py          # every guard against its test cases
python3 tests/test_guard_run.py     # the wrapper
python3 test-kit/probe.py --guard guards/command-guard.sh
```

Needs bash and python3 only. Tested on macOS; Linux should work but is less tested.

## Licences

Everything here is MIT ([LICENSE](LICENSE)) except `guards/command-guard.sh`, which is derived from the command-safety rules of [Tura](https://github.com/Tura-AI/tura) and is therefore licensed AGPL-3.0-or-later ([guards/LICENSE-AGPL-3.0.txt](guards/LICENSE-AGPL-3.0.txt)). You can use it freely; if you distribute a modified version, share your changes under the same licence.
