# Managed install (macOS)

Root-owned copies of this plugin's guards, loaded from macOS managed settings, so that no Claude
Code session can switch them off, edit them, or steer the environment they run in.

**This needs administrator rights.** The install writes files under a system folder that only an
admin can write, and it calls `sudo` for those steps itself. Run it from your own terminal, not
from inside a Claude session — a session cannot run `sudo`, and the installer refuses to run in one.

## Why

A plugin's hooks live in a settings file, and a session can start a child `claude` that loads none
of them:

- `--settings '{"disableAllHooks":true}'` turns every hook off;
- `--setting-sources project` (or any source list without `user`) drops your user settings;
- restricted or minimal launch modes load a reduced set.

macOS **managed settings** are different: Claude Code applies them on every launch, and a session
cannot turn them off from inside. `disableAllHooks` does not reach a managed hook. Putting the
guards there means they run whatever flags the child was started with.

There is a second gap this closes. A hook inherits the environment of the session that runs it, and
a session that launches a child chooses that environment. A guard can be steered by a different
`python3` early on `PATH`, a `HOME` that moves the protected folders, `BASH_ENV`/`ENV` code that
runs first, `PYTHONPATH` or a hostile current directory that shadows the standard library, or an
exported shell function. The launcher (`managed-guard`) rebuilds the environment from nothing
(`env -i`) with only a short allowlist, pins the interpreter and `HOME`, runs from a root-owned
folder, and forces git's per-command config, so none of those tricks reach the guard.

## What gets installed

Everything below is `root:wheel` and not writable by you.

| Path | What |
|---|---|
| `/Library/Application Support/ClaudeCode/managed-settings.json` | This folder's `managed-settings.json`: the guard hooks, in exec form, with the same matchers as the plugin's own `hooks/hooks.json` |
| `/Library/Application Support/ClaudeCode/claude-safety/managed-guard` | Rendered from `managed-guard.template`: runs one guard under `env -i` with an allowlist, `PATH` pinned to the Command Line Tools Python and the system folders, `HOME` baked in, `bash -p` |
| `/Library/Application Support/ClaudeCode/claude-safety/guards/` | Copies of `guard-run.sh` and each guard the settings file names |
| `/Library/Application Support/ClaudeCode/claude-safety/lib/` | A copy of `safety-config.py` |
| `/Library/Application Support/ClaudeCode/claude-safety/config.json` | The config baked in at install time (`~/.config/claude-safety/config.json` if you have one, else the plugin's `config.example.json`) |

The plugin's own hooks keep running as well. A call needs **both** copies to allow it, so
**tightening a guard in the plugin takes effect at once, and loosening one needs a re-install.**
The managed copies log to `~/.local/state/claude-safety/managed/`, apart from the plugin's own log,
so neither set of counts doubles.

## Use

```bash
cd plugins/safety/managed
./install.sh --dry-run    # build and smoke-test everything in a temp dir; no sudo, changes nothing
./install.sh              # install; shows the plan, asks, then uses sudo
./canary.sh               # acceptance test: a few short headless runs, one per launch route
./install.sh --verify     # any time: ownership, drift from the plugin, smoke test; no sudo
./install.sh --uninstall  # asks, then uses sudo
```

`--dry-run` and `--verify` only read, so they are safe to run any time. Installing and uninstalling
need your password.

**After you edit a guard, re-run `./install.sh`.** Until then the managed copy keeps the old
version, and `--verify` names the guards that have drifted.

## What to know before installing

- **The guards must stay compatible with the system Python.** The launcher pins
  `/Library/Developer/CommandLineTools/usr/bin/python3` (3.9) because it is root-owned. A guard
  that needs a newer Python would fail in the managed copy; the install smoke test catches that
  before anything goes live.
- **If the Command Line Tools are missing** (a macOS upgrade can remove them), the managed copies
  stop running and every tool call shows a non-blocking error naming the fix
  (`xcode-select --install`). The plugin's own copies are unaffected.
- **A guard that times out fails open** — this is Claude Code's documented behaviour for hooks.
- **Managed settings can also loosen, not only tighten.** If a host that embeds Claude Code passes
  its own policy and you install a managed file, the host's policy may be dropped. If you run Code
  inside such a host, check `/status` before and after installing.
- The installer verifies ownership and mode from `/Library` down, and re-checks on `--verify`. The
  logs it writes are under your home, so they are evidence, not proof.

## Not covered

- Only Claude Code reads these settings. Other agents on the machine do not.
- The client that enforces the hooks lives in user-writable paths, so a session that can run a
  different build of the client is outside what a managed policy can reach.
- This is a macOS mechanism. The equivalent on other systems is a managed settings file in the
  platform's own system location; this installer does not write those.

## One user per Mac

The installer bakes in the home folder of the admin who runs it (for the config file and the log folder). Managed settings apply to every account on the Mac, so on a shared Mac the guards judge paths against that one home folder. Install it on single-user machines, or adjust `claude-safety/config.json` after installing.

