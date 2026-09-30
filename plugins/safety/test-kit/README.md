# Test kit

Guard-agnostic tools for checking any Claude Code PreToolUse guard: point them at this plugin's
guards, at an old-versus-new copy while you change one, or at a guard of your own. Everything here
judges command strings and never runs them, so no case can touch a real file.

## `probe.py` — find holes and over-blocks

```
python3 probe.py --guard ../guards/command-guard.sh
python3 probe.py --guard ../guards/command-guard.sh --guard ../guards/git-guard.sh
python3 probe.py --guard ../guards/command-guard.sh --class destroy -v
```

Loads `evasion-classes.json`, expands each template against a throwaway home and working dir, and
sends it to the guard(s) you name. A command counts as blocked when **any** named guard blocks it,
so you can point it at one guard or at the whole set at once. It reports:

- **HOLE** — a case that must block, which every named guard allowed. A real gap.
- **OVER-BLOCK** — a benign case a guard refused. A guard is judged on this too: over-blocking is
  what makes people switch a guard off.

With no `--class`, every case runs. A guard that owns only one family (say deletes) will then show
HOLEs for the families it was never meant to cover (egress, git, network binds) — that is expected.
Either filter with `--class`, or name every guard that together should cover the library. Exit is 0
only when there is no HOLE and no OVER-BLOCK.

## `evasion-classes.json` — the case library

A templated library of reshaped commands (80+ cases) across quoting and dequoting, variable
indirection, wrapper commands, nested shells, command substitution, heredocs, interpreter
one-liners, encoded payloads, path tricks (`../`, symlinks, `~` forms), environment steering, plus
zero-writes, self-defence against the agent's own control files, device writes, download-and-run,
egress, destructive git, network binds — and ordinary commands that must stay allowed. Each case
carries its `class`, the `expect`ed verdict, the `unattended` level to judge it in, and a `why`.
Placeholders (`{PROT}`, `{SECRET}`, `{CTRL}`, `{OK}`, `{HOST}`, ...) are filled in by `probe.py`;
the top of the file lists them. Add your own cases here — no code change needed.

## `replay.py` — replay your real commands through two guards

```
python3 replay.py --old OLD-guard.sh --new NEW-guard.sh --days 7
python3 replay.py --old OLD-guard.sh --new NEW-guard.sh --unattended
```

Before you change a guard, this shows what the change does to the commands you have **actually
run**, not just to hand-written cases. It reads your own session transcripts under
`~/.claude/projects`, pulls the distinct Bash commands from the last N days, and runs each through
both guards.

**It prints counts only.** No command, path, or transcript text is ever shown or written anywhere:
your real commands can contain secrets and private paths, and this tool is built so none of that
leaves your machine. The counts that matter are *old-allow → new-block* (the new guard got
stricter — make sure you meant to) and *old-block → new-allow* (the new guard got looser — make
sure you did not open a hole).

## `corpus-check.py` — check a guard against a cases file

```
python3 corpus-check.py --guard ../guards/command-guard.sh a-cases-file.json
python3 corpus-check.py --guard live.sh --candidate new.sh a-cases-file.json
```

Runs a JSON cases file through a guard, and with `--candidate` against a second copy, printing every
missed case and every disagreement, then the fail counts. It accepts both the plugin's own case
shape (`{"name", "payload", "expect"}`, as in `../tests/*.cases.json`) and a compact shape
(`{"name", "cmd", "cwd", "want", "unattended"}`), mixed freely. `$HOME` and `$CWD` in a case expand
to a throwaway directory. Exit 1 if the candidate (or the guard, with no candidate) fails a case.

## Safety

Nothing here executes a case. Guards receive the command as a hook payload on stdin and return a
verdict; the string is never run. Probe and corpus-check build a throwaway home and working dir so
even the expanded paths point at nothing real. `replay.py` only reads transcripts and only reports
numbers.
