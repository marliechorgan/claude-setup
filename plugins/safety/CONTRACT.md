# Guard contract (rev 1)

Every guard in this plugin follows this contract, so the wrapper, the tests and the installer can treat them alike.

## Input and output

- A guard is an executable script run by Claude Code as a hook. It reads the hook's JSON payload on stdin (`tool_name`, `tool_input`, `cwd`, and for PostToolUse `tool_response`).
- **Allow:** exit 0, print nothing.
- **Block:** exit 2, and print to stderr one message that starts `BLOCKED by <guard-name>` followed by the class in brackets, what was refused and why, then a line starting `DO THIS INSTEAD:` with a safe alternative. Claude reads this message, so write it for Claude.
- **Uncertain about a command:** fail open (exit 0). A guard that blocks everything it cannot parse gets switched off. The wrapper, not the guard, fails closed when the guard itself is missing or damaged.
- Any other exit code is a **break**: Claude Code treats it as non-blocking, so the guard protected nothing. The wrapper records it.
- Stdlib only: bash 3.2 and python3. Call python as `python3 -I -S` so nothing in the current directory, `PYTHONPATH` or a user site can shadow a module. No network, no writes outside the log directory.

## Configuration

Read settings through `lib/safety-config.py`:

```bash
CFG="$(dirname "$0")/../lib/safety-config.py"
python3 -I -S "$CFG" get protected_paths      # one expanded absolute path per line
python3 -I -S "$CFG" get unattended           # prints 1 or 0
```

It reads the first file that exists of `$CLAUDE_SAFETY_CONFIG`, `$CLAUDE_PLUGIN_DATA/config.json`, `~/.config/claude-safety/config.json`, and falls back to built-in defaults. Keys:

| Key | Meaning | Default |
|---|---|---|
| `protected_paths` | Never deleted, moved over, truncated or overwritten by an agent | `~`, `~/.ssh`, `~/.gnupg`, `~/.aws`, `~/.config`, `~/Documents`, `~/Desktop`, `~/Library`, `~/.claude` |
| `delete_allowed_roots` | Where destructive deletes may land | the session `cwd`, `$TMPDIR`, `/tmp`, `/private/tmp` |
| `control_files` | The agent's own rules: never written by the agent | `~/.claude/settings.json`, `~/.claude/settings.local.json`, `~/.claude/CLAUDE.md`, `~/.claude/hooks`, `~/.claude/agents`, `~/.claude/skills`, `~/.claude/plugins` (so the guards themselves can't be edited), `~/.config/claude-safety` (their settings), `~/.zshrc`, `~/.bashrc`, `~/.bash_profile`, `~/.profile`, `~/.zshenv`, `~/.zprofile`, `~/.ssh`, `~/.gnupg`, `~/.gitconfig`, `~/.config/git`, `~/.config/fish`, `~/.config/gh/hosts.yml`, and in any project `.claude/settings.json`, `.claude/settings.local.json`, `.git/hooks`, `.git/config` |
| `secret_patterns` | Files the agent must not write (reading is not blocked; keep secrets out of the project) | `.env`, `.env.*`, `*.pem`, `*.key`, `id_rsa*`, `id_ed25519*`, `.netrc`, `.npmrc`, `.pypirc`, `credentials*`, `*.p12`, `*.pfx`, `*.jks`, `*.kdbx`, `*.keychain-db`, `*.ovpn`, `secring*` |
| `egress_allowed_hosts` | Hosts an agent may send data to | `[]` |
| `unattended` | Stricter mode for scheduled or headless runs | `1` when `CLAUDE_SAFETY_UNATTENDED=1`, else `0` |

## Override and unattended mode

- A person can let one blocked command through by prefixing it with `CLAUDE_GUARD_OVERRIDE='<reason>' `. The guard records the reason. **Overrides are refused in unattended mode**, because nobody is there to mean it.
- Set `CLAUDE_SAFETY_UNATTENDED=1` in the environment of scheduled or headless runs. Guards may apply stricter rules then.

## Logging

The wrapper writes `$CLAUDE_SAFETY_LOG_DIR`, else `$CLAUDE_PLUGIN_DATA`, else `~/.local/state/claude-safety`: a daily `activity-YYYY-MM-DD.tsv` for blocks and breaks, and `ledger.jsonl` with the reason and a redacted subject. Guards do not write logs themselves, except an override row.

## Tests

Each guard ships `tests/<guard-name>.cases.json`: a list of `{"name", "payload", "expect": "allow"|"block", "why"}`. `payload` is the hook JSON. Paths inside use `$HOME` and `$CWD`, which the runner expands to a throwaway directory. Nothing is ever executed: guards judge commands, they never run them. Run everything with:

```bash
python3 tests/run_cases.py            # all guards
python3 tests/run_cases.py command-guard
```
