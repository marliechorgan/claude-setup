#!/bin/bash
# git-guard.sh: PreToolUse(Bash) guard against git commands that destroy work.
#
# Uncommitted changes, untracked files and stashes exist nowhere else, and a force push can
# erase commits other people pushed. An agent "cleaning up" a repository reaches for exactly
# these commands, and each one is a single line that cannot be undone.
#
# Blocks:
#   reset-hard           git reset --hard (and its abbreviations such as --har)
#   clean-force          git clean with -f in any spelling (-fd, -xdf, --force), or with
#                        clean.requireForce turned off; a dry run (-n) is allowed
#   discard-worktree     git checkout . / checkout -- . / checkout -f, git restore . on the
#                        working tree, git switch --discard-changes or -f
#   stash-drop           git stash drop, git stash clear
#   force-push           git push --force, -f, a +refspec or --mirror
#                        (--force-with-lease is allowed)
#   branch-force-delete  git branch -D, or --delete with --force
#   ref-delete           git update-ref -d
#   history-rewrite      git filter-branch, git filter-repo
# It sees through git -C <dir>, -c key=val (including aliases defined with -c or
# GIT_CONFIG_* variables), env prefixes, sudo/env/xargs wrappers, chains, pipes,
# subshells, sh -c and eval, and dequotes words the way the shell does, so
# git "re"set --hard is still reset --hard. Everything else is allowed: status, diff,
# commit, pull, fetch, a plain push, checkout of a branch, restore --staged.
#
# Contract (CONTRACT.md): exit 0 allows, exit 2 blocks with a message on stderr. A command
# it cannot parse is allowed. CLAUDE_GUARD_OVERRIDE='reason' lets one command through when
# a person is present; it is refused when CLAUDE_SAFETY_UNATTENDED=1.
HOOK_INPUT="$(cat)"
export HOOK_INPUT
python3 -I -S - <<'PY'
import os, re, shlex, sys

SHELLS = {"bash", "sh", "zsh", "dash", "ksh"}
KEYWORDS = {"if", "then", "else", "elif", "do", "while", "until", "!", "{", "}", "time", "coproc"}
# wrapper -> options of that wrapper that consume the next word
WRAPPERS = {
    "sudo": {"-u", "-g", "-h", "-p", "-C", "-D", "-r", "-t", "-U", "-T"}, "doas": {"-u", "-C"},
    "env": {"-u", "-C", "-P", "--unset", "--chdir"}, "command": set(), "exec": {"-a"},
    "nohup": set(), "builtin": set(), "nice": {"-n"}, "caffeinate": {"-t", "-w"},
    "stdbuf": {"-i", "-o", "-e"}, "timeout": {"-s", "-k", "--signal", "--kill-after"},
    "xargs": {"-I", "-n", "-P", "-L", "-s", "-d", "-E", "-a"}, "npx": {"-p", "--package"},
    "bunx": set(), "pnpx": set(),
}
ASSIGN = re.compile(r"[A-Za-z_][A-Za-z0-9_]*=")


def unheredoc(cmd):
    """Drop heredoc bodies (text, not commands) unless the line feeds them to a shell."""
    out, lines, i = [], cmd.split("\n"), 0
    while i < len(lines):
        line = lines[i]
        i += 1
        if line.lstrip().startswith("#"):
            continue  # a whole-line comment runs nothing
        out.append(line)
        m = re.search(r"(?<!<)<<-?\s*(['\"]?)([\w.-]+)\1", line)
        if not m:
            continue
        body = []
        while i < len(lines) and lines[i].strip() != m.group(2):
            body.append(lines[i])
            i += 1
        i += 1
        if any(os.path.basename(w) in SHELLS for w in re.split(r"[\s|;&()]+", line)):
            out.extend(body)
    return "\n".join(out)


def segments(cmd):
    """Split a command line into simple commands, dequoted like the shell would."""
    text = unheredoc(cmd).replace("`", " ; ")
    try:
        return list(lex_segments(text.replace("\n", " ; ")))
    except ValueError:
        # The shell runs complete lines before it reaches a broken one, so judge line by line.
        out = []
        for line in text.split("\n"):
            try:
                out += list(lex_segments(line))
            except ValueError:
                pass
        return out


def lex_segments(text):
    lex = shlex.shlex(text, posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    lex.commenters = ""
    seg, skip = [], False
    for tok in lex:
        if skip:
            skip = False
            continue
        if tok and all(c in "();<>|&" for c in tok):
            if any(c in "();|" for c in tok) or tok in ("&", "&&"):
                if seg:
                    yield seg
                seg = []
            else:
                skip = True  # a redirection and its target
            continue
        seg.append(tok)
    if seg:
        yield seg


def unwrap(words):
    """Strip env assignments, keywords and wrapper commands. Returns (assignments, words)."""
    env, i = {}, 0
    while i < len(words):
        w = words[i]
        if ASSIGN.match(w):
            k, _, v = w.partition("=")
            env[k] = v
            i += 1
        elif w in KEYWORDS:
            i += 1
        elif os.path.basename(w) in WRAPPERS:
            takes = WRAPPERS[os.path.basename(w)]
            name = os.path.basename(w)
            i += 1
            while i < len(words) and words[i].startswith("-") and words[i] != "--":
                if words[i] in ("-S", "--split-string") and name == "env" and i + 1 < len(words):
                    words = words[:i] + shlex.split(words[i + 1]) + words[i + 2:]
                    break
                i += 2 if words[i] in takes else 1
            if i < len(words) and words[i] == "--":
                i += 1
            if name == "timeout" and i < len(words):
                i += 1  # the duration
        else:
            break
    return env, words[i:]


def commands(cmd, depth=0):
    """Yield (assignments, words) for every simple command, following sh -c and eval."""
    for seg in segments(cmd):
        env, words = unwrap(seg)
        if not words:
            if env:
                yield env, []
            continue
        name = os.path.basename(words[0])
        if depth < 4 and name in SHELLS:
            for j in range(1, len(words) - 1):
                w = words[j]
                if w == "-c" or (re.fullmatch(r"-[a-z]*c[a-z]*", w) is not None):
                    yield from commands(words[j + 1], depth + 1)
                    break
        elif depth < 4 and name == "eval":
            yield from commands(" ".join(words[1:]), depth + 1)
            continue
        yield env, words


GIT_OPTS_WITH_ARG = {"-c", "-C", "--git-dir", "--work-tree", "--namespace", "--super-prefix", "--config-env"}
WHOLE_TREE = {".", "*", "**", ":", ":/", ":/*", ":/.", ":(top)", ":(top).", ":(top)*", ":(glob)*", ":(glob)**"}

SAVE_FIRST = "commit or stash the work first (`git stash push -u -m 'before cleanup'`)"
MESSAGES = {
    "reset-hard": ("`git reset --hard` throws away every uncommitted change in the working tree and index.",
                   SAVE_FIRST + ", then reset; or use `git reset --keep`, which refuses to overwrite "
                   "uncommitted changes."),
    "clean-force": ("`git clean -f` deletes untracked files, and git has no copy to bring them back from.",
                    "run `git clean -n` to list what would go, then " + SAVE_FIRST + ", or remove the "
                    "specific files by name."),
    "discard-worktree": ("this overwrites the uncommitted changes in every file with the committed version.",
                         SAVE_FIRST + ", or restore the specific files you mean by name."),
    "stash-drop": ("this deletes stashed work, which is often the only copy of it.",
                   "leave the stash in place; inspect it with `git stash show -p`, or use it with "
                   "`git stash apply`."),
    "force-push": ("a force push replaces the remote branch and can discard commits someone else pushed.",
                   "use `git push --force-with-lease`, which refuses if the remote moved since you last "
                   "fetched; " + SAVE_FIRST + " if local work is involved."),
    "branch-force-delete": ("this deletes the branch even when its commits are merged nowhere else.",
                            "use `git branch -d`, which refuses to delete unmerged work, or merge or push the "
                            "branch first."),
    "ref-delete": ("`git update-ref -d` deletes a ref directly, skipping every safety check.",
                   "use `git branch -d` or `git tag -d` after confirming the commits are reachable elsewhere."),
    "history-rewrite": ("this rewrites commits across the history; the old commits survive only in reflogs "
                        "and backups.",
                        "ask the user first. They can run it themselves on a fresh clone, after the work is "
                        "committed and pushed."),
}


def short_has(arg, letter):
    """True when a short-option cluster such as -fdx contains the letter."""
    return re.fullmatch(r"-[A-Za-z0-9]+", arg) is not None and letter in arg[1:]


def long_is(arg, full, shortest):
    """True for a long option or git's accepted unambiguous abbreviation of it (--har for --hard)."""
    name = arg.split("=", 1)[0]
    return len(name) >= len(shortest) and full.startswith(name)


def is_whole(path, cwd):
    p = path.strip()
    while p.startswith("./") and len(p) > 2:
        p = p[2:]
    p = p.rstrip("/") or "/"
    if p in WHOLE_TREE or p == "./":
        return True
    return bool(cwd) and p.startswith("/") and os.path.normpath(p) == os.path.normpath(cwd)


def split_dashdash(args):
    if "--" in args:
        i = args.index("--")
        return args[:i], args[i + 1:]
    return args, []


def judge(sub, args, config, cwd):
    """Return the class of a destructive git subcommand, or None."""
    opts = [a for a in args if a.startswith("-")]
    before, after = split_dashdash(args)
    paths = after + [a for a in before if not a.startswith("-")]
    interactive = any(a in ("-p", "--patch") or short_has(a, "p") for a in before)

    if sub == "reset" and any(long_is(a, "--hard", "--ha") for a in opts):
        return "reset-hard"
    if sub == "clean":
        dry = any(a == "--dry-run" or short_has(a, "n") for a in opts)
        force = any(long_is(a, "--force", "--f") or short_has(a, "f") for a in opts) or \
            config.get("clean.requireforce", "").lower() in ("false", "no", "off", "0")
        if force and not dry:
            return "clean-force"
    if sub == "checkout":
        if any(a == "--force" or short_has(a, "f") for a in before):
            return "discard-worktree"
        if not interactive and any(is_whole(p, cwd) for p in paths):
            return "discard-worktree"
    if sub == "restore" and not interactive and any(is_whole(p, cwd) for p in paths):
        staged = any(a == "--staged" or short_has(a, "S") for a in before)
        worktree = any(a == "--worktree" or short_has(a, "W") for a in before)
        if worktree or not staged:
            return "discard-worktree"
    if sub == "switch" and any(a in ("--discard-changes", "--force") or short_has(a, "f") for a in before):
        return "discard-worktree"
    if sub == "stash":
        pos = [a for a in args if not a.startswith("-")]
        if pos[:1] in (["drop"], ["clear"]):
            return "stash-drop"
    if sub == "push":
        if any(a == "--force" or a == "--mirror" or short_has(a, "f") for a in before):
            return "force-push"
        if any(a.startswith("+") for a in before if not a.startswith("-")):
            return "force-push"
    if sub == "branch":
        delete = any(a == "--delete" or short_has(a, "d") for a in opts)
        force = any(a == "--force" or short_has(a, "f") for a in opts)
        if any(short_has(a, "D") for a in opts) or (delete and force):
            return "branch-force-delete"
    if sub == "update-ref" and any(a == "-d" or short_has(a, "d") for a in opts):
        return "ref-delete"
    if sub in ("filter-branch", "filter-repo"):
        return "history-rewrite"
    return None


def is_git(word):
    import fnmatch
    name = os.path.basename(word).lower()
    return name == "git" or (any(c in name for c in "*?[") and fnmatch.fnmatchcase("git", name))


def judge_git(env, words, cwd, depth=0):
    """Parse git's own options (-C, -c, env config), expand -c aliases, then judge."""
    config = {}
    try:
        for n in range(int(env.get("GIT_CONFIG_COUNT", "0") or 0)):
            config[env.get("GIT_CONFIG_KEY_%d" % n, "").lower()] = env.get("GIT_CONFIG_VALUE_%d" % n, "")
    except ValueError:
        pass
    for m in re.finditer(r"'([^'=]+)'='([^']*)'|'([^'=]+)=([^']*)'", env.get("GIT_CONFIG_PARAMETERS", "")):
        config[(m.group(1) or m.group(3)).lower()] = m.group(2) if m.group(1) else m.group(4)
    i = 1
    while i < len(words):
        w = words[i]
        if w in GIT_OPTS_WITH_ARG:
            if w == "-c" and i + 1 < len(words):
                k, _, v = words[i + 1].partition("=")
                config[k.lower()] = v
            i += 2
        elif w.startswith("-"):
            i += 1
        else:
            break
    if i >= len(words):
        return None
    sub, args = words[i].lower(), words[i + 1:]
    alias = config.get("alias." + sub)
    if alias is not None and depth < 3:
        if alias.startswith("!"):
            hit = find(alias[1:], cwd, depth + 1)
            return hit[0] if hit else None
        return judge_git(env, words[:i] + shlex.split(alias) + args, cwd, depth + 1)
    return judge(sub, args, config, cwd)


def find(cmd, cwd="", depth=0):
    for env, words in commands(cmd):
        if not words:
            continue
        name = os.path.basename(words[0]).lower()
        if name in ("git-filter-repo", "git-filter-branch"):
            cls = "history-rewrite"
        elif is_git(words[0]):
            cls = judge_git(env, words, cwd, depth)
        else:
            cls = None
        if cls:
            what, instead = MESSAGES[cls]
            return cls, what, instead
    return None


OVERRIDE = re.compile(r"""\s*CLAUDE_GUARD_OVERRIDE=(?:'([^']*)'|"([^"]*)"|([^\s;&|]+))\s+\S""")


def log_override(guard, cls, reason, data):
    import json, time
    logdir = (os.environ.get("CLAUDE_SAFETY_LOG_DIR") or os.environ.get("CLAUDE_PLUGIN_DATA")
              or os.path.expanduser("~/.local/state/claude-safety"))
    row = {"ts": time.strftime("%Y-%m-%dT%H:%M:%S%z"), "guard": guard, "verdict": "override",
           "class": cls, "reason": " ".join(reason.split())[:200], "cwd": str(data.get("cwd") or ""),
           "unattended": "0"}
    try:
        os.makedirs(logdir, exist_ok=True)
        with open(os.path.join(logdir, "ledger.jsonl"), "a", encoding="utf-8") as fh:
            fh.write(json.dumps(row, ensure_ascii=False) + "\n")
    except OSError:
        pass


def run(guard, find):
    import json
    try:
        data = json.loads(os.environ.get("HOOK_INPUT") or "{}")
        if not isinstance(data, dict) or data.get("tool_name") != "Bash":
            return 0
        cmd = (data.get("tool_input") or {}).get("command") or ""
        if not isinstance(cmd, str) or not cmd.strip():
            return 0
        hit = find(cmd, str(data.get("cwd") or ""))
    except Exception:
        return 0  # unsure what the command does: allow it
    if not hit:
        return 0
    cls, what, instead = hit
    m = OVERRIDE.match(cmd)
    reason = next((g for g in m.groups() if g), "").strip() if m else ""
    if reason:
        if os.environ.get("CLAUDE_SAFETY_UNATTENDED") != "1":
            log_override(guard, cls, reason, data)
            return 0
        what += " CLAUDE_GUARD_OVERRIDE is refused in unattended mode, because nobody is there to mean it."
    sys.stderr.write("BLOCKED by %s [%s]: %s\nDO THIS INSTEAD: %s\n" % (guard, cls, what, instead))
    return 2


sys.exit(run("git-guard", find))
PY
