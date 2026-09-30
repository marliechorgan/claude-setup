#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Derived from the command-safety rules of Tura (https://github.com/Tura-AI/tura,
# commit a0bdd10, crates/tools/src/commands/command_safety.rs), AGPL-3.0-or-later.
# Modified 2026: POSIX-only port, effect-based containment, configurable roots.
#
# command-guard.sh: PreToolUse(Bash) guard against destructive commands.
#
# An exact-string deny list (Bash(rm -rf /)) is beaten by any reshaping: rm -fr ~,
# rm -rf $HOME, bash -c "rm -rf ~", X=rm; $X -rf ~. This guard reads the command the
# way the shell will run it instead: it splits connector chains, recurses into $(...),
# backticks and subshells, peels wrappers (sudo, env, timeout, xargs, nohup, ...),
# unwraps sh -c / eval / trap, follows variable indirection and cd, and judges each
# command by its EFFECT. Deleting, moving away, emptying or wiping a path is allowed only
# when every resolved target stays inside the allowed roots; protected paths, the agent's
# control files and system paths are refused wherever the agent stands.
#
# Always refused (no override): disk, partition and power operations, pipes from a
# download or a decoder into an interpreter, destroying backups or history, turning off
# OS security features, and anything that deletes, relocates or empties a protected path.
# A recursive or forced delete outside the allowed roots is refused too, but a person in
# an attended session may let one through with CLAUDE_GUARD_OVERRIDE='<reason>' <command>.
#
# Contract (see ../CONTRACT.md): hook JSON on stdin; exit 0 allows, exit 2 blocks with a
# message on stderr. A command the guard cannot parse is allowed (fail open); a parsed
# destructive command whose target cannot be shown to be contained is blocked.

HOOK_INPUT="$(cat)"
export HOOK_INPUT
SAFETY_CFG_LIB="$(cd "$(dirname "$0")/../lib" 2>/dev/null && pwd)/safety-config.py"
export SAFETY_CFG_LIB

# The heredoc is not inside $(...): its body holds backticks, which bash would try to pair.
python3 -I -S - <<'PY'
import os
import re
import sys

GUARD = "command-guard"
SOFT = "OUTSIDE_ROOTS"          # the only class a person may override

# Used when lib/safety-config.py cannot be loaded, so a damaged install still protects.
FALLBACK = {
    "protected_paths": ["~", "~/.ssh", "~/.gnupg", "~/.aws", "~/.config", "~/Documents",
                        "~/Desktop", "~/Library", "~/.claude"],
    "delete_allowed_roots": ["$CWD", "$TMPDIR", "/tmp", "/private/tmp"],
    "control_files": ["~/.claude/settings.json", "~/.claude/settings.local.json",
                      "~/.claude/CLAUDE.md", "~/.claude/hooks", "~/.claude/agents",
                      "~/.claude/skills", "~/.zshrc", "~/.bashrc", "~/.bash_profile",
                      "~/.profile", "~/.ssh", ".claude/settings.json",
                      ".claude/settings.local.json", ".git/hooks"],
}


def load_config(cwd):
    path = os.environ.get("SAFETY_CFG_LIB") or ""
    try:
        import importlib.util
        spec = importlib.util.spec_from_file_location("safety_config", path)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        cfg = mod.load()
        return cfg, (lambda v: mod.expand(v, cwd))
    except Exception:
        cfg = dict(FALLBACK)
        cfg["unattended"] = 1 if os.environ.get("CLAUDE_SAFETY_UNATTENDED") == "1" else 0

        def expand(v):
            v = str(v).replace("$CWD", cwd or "").replace(
                "$TMPDIR", (os.environ.get("TMPDIR") or "/tmp").rstrip("/"))
            v = os.path.expanduser(v)
            return os.path.normpath(v) if v.startswith("/") else v
        return cfg, expand


def compute(data):
    """Return (class, reason) for a command to refuse, else None. Exceptions fail open."""
    import fnmatch
    import shlex

    if data.get("tool_name") != "Bash":
        return None
    command = ((data.get("tool_input") or {}).get("command") or "")
    if not command.strip():
        return None

    home = os.path.expanduser("~")

    def normalize(path):
        # Collapse . and .. and repeated slashes as text, without touching the disk.
        text = (path or "").replace("\\", "/")
        parts = []
        for part in text.split("/"):
            if part in ("", "."):
                continue
            if part == "..":
                if parts:
                    parts.pop()
            else:
                parts.append(part)
        return ("/" if text.startswith("/") else "") + "/".join(parts)

    session_cwd = normalize(data.get("cwd") or os.getcwd())
    home_n = normalize(home)
    cfg, expand = load_config(session_cwd)
    unattended = str(cfg.get("unattended", 0)) == "1"

    # ---- a command name can be spelled at run time ------------------------------------
    # rm${IFS}-rf, $(echo rm), `echo rm` and $'\x72\x6d' all run rm, but a parser that reads
    # the first token literally sees an unknown word. Rewrite the forms that have exactly one
    # literal reading. This only ever makes the text more literal, so it can add blocks and
    # never remove one.
    def spell_out_literals(text):
        prev = None
        for _ in range(4):
            if text == prev:
                break
            prev = text
            text = re.sub(r"\$\{IFS\}|\$IFS(?![A-Za-z0-9_])", " ", text)

            def _echo(m):
                # $(echo rm), $(printf '\162\155'), $(echo -e '\x72\x6d'): one literal reading.
                body = m.group(1).strip()
                e = re.fullmatch(r"(echo|printf)((?:\s+-[neE]+)*)\s+(?:'([^'%]*)'|\"([^\"%$`]*)\""
                                 r"|([^\s|;&<>$`'\"%\\]+(?:\s+[^\s|;&<>$`'\"%\\-][^\s|;&<>$`'\"%\\]*)*))", body)
                if not e:
                    return m.group(0)
                lit = next(g for g in e.group(3, 4, 5) if g is not None)
                if e.group(5) is None and "\\" in lit and (e.group(1) == "printf" or "e" in e.group(2)):
                    try:
                        lit = lit.encode("utf-8").decode("unicode_escape")
                    except Exception:
                        return m.group(0)
                if not re.fullmatch(r"[\w./ -]+", lit):
                    return m.group(0)
                return lit.strip()
            text = re.sub(r"\$\(([^()$`]*)\)", _echo, text)
            text = re.sub(r"`([^`$]*)`", _echo, text)

            # $'...' must start a word and hold only escapes and plain word characters, so a
            # regex anchor such as grep 'x$' followed by a quote is never mistaken for one.
            def _ansi(m):
                body = m.group(1)
                if "\\" not in body or not re.fullmatch(
                        r"(?:\\(?:x[0-9a-fA-F]{1,2}|[0-7]{1,3}|u[0-9a-fA-F]{4}"
                        r"|[abefnrtv\\'\"])|[A-Za-z0-9_.=/-]){1,64}", body):
                    return m.group(0)
                try:
                    return body.encode("utf-8").decode("unicode_escape")
                except Exception:
                    return m.group(0)
            text = re.sub(r"(?<![\w!-])\$'([^']*)'", _ansi, text)
        return text

    command = spell_out_literals(command)

    WRAPPERS = {"sudo", "doas", "env", "nohup", "nice", "ionice", "time", "timeout",
                "stdbuf", "setsid", "command", "builtin", "exec", "xargs", "caffeinate"}
    WRAPPER_VALUE_OPTS = {"env": ("-u", "--unset", "-C", "--chdir"),
                          "timeout": ("-s", "--signal", "-k", "--kill-after"),
                          "stdbuf": ("-i", "-o", "-e"), "nice": ("-n", "--adjustment"),
                          "ionice": ("-c", "-n", "-p")}
    NESTED_SHELLS = {"bash", "sh", "zsh", "dash", "ksh", "ash", "fish"}
    # Words that only ever precede a command; peeled like a wrapper.
    SHELL_GRAMMAR = {"!", "{", "then", "do", "else", "elif", "if", "while", "until"}
    # Paths that must never be the target of a delete, move or recursive mode change.
    SYSTEM_PATHS = ["/", "/etc", "/usr", "/bin", "/sbin", "/lib", "/lib64", "/var", "/boot",
                    "/sys", "/proc", "/dev", "/root", "/home", "/opt", "/tmp", "/private",
                    "/private/tmp", "/private/etc", "/private/var", "/System", "/Library",
                    "/Applications", "/Users", "/Volumes", "/cores", "/usr/local"]
    # Roots that can never serve as an allowed root, even when they are the session cwd.
    NEVER_ROOTS = {"/", "/etc", "/usr", "/bin", "/sbin", "/lib", "/lib64", "/var", "/boot",
                   "/sys", "/proc", "/dev", "/root", "/home", "/opt", "/private",
                   "/private/etc", "/private/var", "/System", "/Library", "/Applications",
                   "/Users", "/Volumes", home_n}
    # Calls that run a shell command from inside another language.
    EXEC_MARKERS = [
        "os.system(", "os.popen(", "subprocess.call(", "subprocess.run(", "subprocess.popen(",
        "subprocess.check_call(", "subprocess.check_output(", "commands.getoutput(",
        "commands.getstatusoutput(", ".exec(", ".execsync(", ".spawn(", ".spawnsync(",
        ".execfile(", ".execfilesync(", "system(", "shell_exec(", "passthru(", "proc_open(",
        "popen(", "doshellscript(",
    ]
    # Calls that delete a path directly from python, node, ruby, perl or php.
    LIB_DELETE_MARKERS = [
        "shutil.rmtree(", "os.remove(", "os.unlink(", "os.removedirs(", "os.rmdir(",
        ".unlink(", "unlink(", "unlinkglob(", ".rmtree(", "fs.rmsync(", "fs.unlinksync(",
        "fs.rmdirsync(", "fs.rm(", ".rmsync(", ".unlinksync(", ".rmdirsync(",
        "fileutils.rm_rf(", "fileutils.rm_r(", "fileutils.rm_f(", "fileutils.rm(",
        "rmtree(", "remove_tree(",
        ".rm_rf(", ".rm_r(", "file.delete(", "dir.delete(",
    ]
    LIB_MOVE_MARKERS = ("os.rename(", "os.renames(", "os.replace(", "shutil.move(")
    # Trees that a package manager or tool rebuilds: deletable wherever they live.
    # Generic names such as build or dist are deliberately absent.
    REPRODUCIBLE = {"node_modules", ".venv", "venv", "__pycache__", ".pytest_cache",
                    ".mypy_cache", ".ruff_cache", ".next", ".gradle", ".tox", ".turbo",
                    ".parcel-cache", "DerivedData"}
    # Homebrew installs GNU tools with a g prefix (grm, gmv): read each as the tool it is.
    GNU_PREFIXED = set("rm rmdir unlink shred mv cp ln install dd tee truncate chmod chown "
                       "chgrp find xargs sed tar env timeout nohup nice stdbuf".split())
    REMOVE_VERBS = ("rm", "unlink", "srm", "shred", "trash")
    PACKERS = ("gzip", "pigz", "bzip2", "xz", "lzma", "compress")
    ZERO_SOURCES = ("/dev/null", "/dev/zero")

    # ---- configured paths ----------------------------------------------------------------
    def absolute(entry, base):
        e = expand(entry)
        if not e:
            return None
        if not e.startswith("/"):
            if not base:
                return None
            e = base + "/" + e
        return normalize(e)

    def with_real(paths):
        out = []
        for p in paths:
            if p and p not in out:
                out.append(p)
            try:
                rp = normalize(os.path.realpath(p))
                if rp and rp not in out:
                    out.append(rp)
            except Exception:
                pass
        return out

    protected = with_real([absolute(p, session_cwd) for p in cfg.get("protected_paths") or []])
    control_abs, control_rel = [], []
    for c in cfg.get("control_files") or []:
        e = expand(c)
        if e.startswith("/"):
            control_abs.append(normalize(e))
        elif e:
            control_rel.append(e)
    control_abs = with_real(control_abs)

    allowed = []
    for r in cfg.get("delete_allowed_roots") or []:
        a = absolute(r, session_cwd)
        if a and a not in NEVER_ROOTS and len(a) > 1:
            allowed.append(a)
    # A path mktemp created inside this command is disposable wherever its template put it.
    MKTEMP_ROOT = "/.command-guard-mktemp"
    allowed.append(MKTEMP_ROOT)
    allowed_real = []
    for a in allowed:
        try:
            allowed_real.append(normalize(os.path.realpath(a)).lower())
        except Exception:
            allowed_real.append(a.lower())

    # Relative targets resolve against CWD[0], which follows cd/pushd inside the command.
    # None means unknown, and every relative target is then unresolvable. The allowed roots
    # keep the session cwd: a cd changes where a path points, never what is allowed.
    CWD = [session_cwd]

    def control_paths():
        out = list(control_abs)
        for base in {session_cwd, CWD[0]}:
            if base:
                out += [normalize(base + "/" + rel) for rel in control_rel]
        return out

    # ---- tokens --------------------------------------------------------------------------
    def base_name(token):
        tail = token.replace("\\", "/").rsplit("/", 1)[-1].lower()
        if tail.endswith(".exe"):
            tail = tail[:-4]
        if tail[:1] == "g" and tail[1:] in GNU_PREFIXED:
            tail = tail[1:]
        return tail

    def tokenize(segment):
        # Honours single and double quotes and backslash escapes. None when unbalanced.
        tokens, current = [], []
        single = double = escaped = started = False
        for ch in segment:
            if escaped:
                current.append(ch); escaped = False; started = True; continue
            if ch == "\\" and not single:
                escaped = True; started = True
            elif ch == "'" and not double:
                single = not single; started = True
            elif ch == '"' and not single:
                double = not double; started = True
            elif ch.isspace() and not single and not double:
                if started:
                    tokens.append("".join(current)); current = []; started = False
            else:
                current.append(ch); started = True
        if single or double:
            return None
        if started:
            tokens.append("".join(current))
        return tokens

    def split_with_connectors(text):
        # Split on newline ; | & && || at the top quoting level; substitutions stay whole.
        segments, current = [], []
        single = double = escaped = backtick = False
        paren = 0
        i = 0
        while i < len(text):
            ch = text[i]
            if escaped:
                current.append(ch); escaped = False; i += 1; continue
            if ch == "\\" and not single:
                current.append(ch); escaped = True
            elif ch == "'" and not double and not backtick:
                single = not single; current.append(ch)
            elif ch == '"' and not single and not backtick:
                double = not double; current.append(ch)
            elif ch == "`" and not single and not double:
                backtick = not backtick; current.append(ch)
            elif ch == "(" and not single and not double and not backtick:
                paren += 1; current.append(ch)
            elif ch == ")" and not single and not double and not backtick:
                paren = max(0, paren - 1); current.append(ch)
            elif single or double or backtick or paren > 0:
                current.append(ch)
            elif ch in ("\n", ";"):
                segments.append(("".join(current), ch)); current = []
            elif ch == "&" and ((current and current[-1] in "<>") or
                                (i + 1 < len(text) and text[i + 1] == ">")):
                current.append(ch)          # 2>&1, >&2 and &>file are redirects
            elif ch in ("|", "&"):
                conn = ch
                if i + 1 < len(text) and text[i + 1] == ch:
                    i += 1; conn = ch * 2
                elif ch == "|" and i + 1 < len(text) and text[i + 1] == "&":
                    i += 1                  # |& is still a pipe
                segments.append(("".join(current), conn)); current = []
            else:
                current.append(ch)
            i += 1
        segments.append(("".join(current), ""))
        return segments

    def split_segments(text):
        return [seg for seg, _ in split_with_connectors(text)]

    def extract_substitutions(text):
        bodies, i = [], 0
        while i < len(text):
            if text[i] == "$" and i + 1 < len(text) and text[i + 1] == "(":
                depth, body, cur = 1, [], i + 2
                while cur < len(text) and depth > 0:
                    c = text[cur]
                    if c == "(":
                        depth += 1
                    elif c == ")":
                        depth -= 1
                    if depth > 0:
                        body.append(c)
                    cur += 1
                bodies.append("".join(body)); i = cur; continue
            if text[i] == "<" and i + 1 < len(text) and text[i + 1] == "(":
                inner = extract_paren_arg(text, i + 1)
                if inner is not None:
                    bodies.append(inner); i += len(inner) + 3; continue
            if text[i] == "`":
                body, cur = [], i + 1
                while cur < len(text) and text[cur] != "`":
                    body.append(text[cur]); cur += 1
                bodies.append("".join(body)); i = cur + 1; continue
            i += 1
        return bodies

    def extract_paren_arg(text, open_paren):
        if open_paren >= len(text) or text[open_paren] != "(":
            return None
        depth = 0
        single = double = escaped = False
        i = open_paren
        while i < len(text):
            ch = text[i]
            if escaped:
                escaped = False; i += 1; continue
            if ch == "\\" and (single or double):
                escaped = True
            elif ch == "'" and not double:
                single = not single
            elif ch == '"' and not single:
                double = not double
            elif ch == "(" and not single and not double:
                depth += 1
            elif ch == ")" and not single and not double:
                depth -= 1
                if depth == 0:
                    return text[open_paren + 1:i]
            i += 1
        return None

    def is_assignment(token):
        if "=" not in token:
            return False
        name = token.split("=", 1)[0]
        return bool(name) and all(c.isalnum() or c == "_" for c in name)

    def is_duration(token):
        trimmed = token.rstrip("smhd")
        return bool(trimmed) and all(c.isdigit() or c == "." for c in trimmed)

    def strip_wrappers(tokens):
        tokens = list(tokens)
        while tokens:
            if tokens[0] in SHELL_GRAMMAR:
                tokens.pop(0); continue
            if tokens[0] == "case":                 # case WORD in PATTERN) cmd
                cut = next((i for i, t in enumerate(tokens) if t.endswith(")")), None)
                tokens = tokens[cut + 1:] if cut is not None else []
                continue
            if tokens[0].endswith(")") and "(" not in tokens[0]:
                tokens.pop(0); continue             # a case arm
            if re.fullmatch(r"[A-Za-z_][\w.:-]*\(\)\{?", tokens[0]):
                tokens.pop(0); continue             # f() { body: judge the body
            if tokens[0] == "function" and len(tokens) > 1:
                tokens = tokens[2:]; continue
            if is_assignment(tokens[0]):            # VAR=value prefix
                tokens.pop(0); continue
            base = base_name(tokens[0])
            if base not in WRAPPERS:
                return tokens
            tokens.pop(0)
            if base in ("sudo", "doas"):
                while tokens and tokens[0].startswith("-"):
                    opt = tokens.pop(0)
                    if opt in ("-u", "-g", "-C", "-p", "-h", "-r", "-t", "--user", "--group") \
                            and tokens and not tokens[0].startswith("-"):
                        tokens.pop(0)
            elif base == "xargs":
                while tokens and tokens[0].startswith("-"):
                    opt = tokens.pop(0)
                    if opt in ("-I", "-n", "-P", "-d", "-E", "-L", "-s") and tokens:
                        tokens.pop(0)
            else:
                takes = WRAPPER_VALUE_OPTS.get(base, ())
                while tokens and (tokens[0].startswith("-") or is_assignment(tokens[0])
                                  or is_duration(tokens[0])):
                    opt = tokens.pop(0)
                    if opt in takes and tokens:
                        tokens.pop(0)
        return tokens

    def short_flag(args, flag):
        return any(a.startswith("-") and not a.startswith("--") and a[1:].isalpha()
                   and flag in a[1:] for a in args)

    def strip_redirections(args):
        # Redirect operands are not command arguments; redirect targets are judged separately.
        out, skip = [], False
        for a in args:
            if skip:
                skip = False; continue
            if re.fullmatch(r"\d*(>>?|<<?<?|&>>?|>&|<&|>\|)", a):
                skip = True; continue
            if re.match(r"\d*(>>?|<|&>>?)\S|\d*[<>]&\S", a):
                continue
            out.append(a)
        return out

    def operands(args):
        out, after = [], False
        for a in args:
            if after:
                out.append(a); continue
            if a == "--":
                after = True; continue
            if a.startswith("-") and a != "-":
                continue
            out.append(a)
        return out

    def value_stripped_keep(args, opts_with_values):
        # Drop the named options and their values; keep every other token in place.
        out, skip = [], False
        for a in args:
            if skip:
                skip = False; continue
            if a in opts_with_values:
                skip = True; continue
            out.append(a)
        return out

    def value_stripped(args, opts_with_values):
        out, skip = [], False
        for a in args:
            if skip:
                skip = False; continue
            if a.startswith("-"):
                if a in opts_with_values:
                    skip = True
                continue
            out.append(a)
        return out

    # ---- resolving a target --------------------------------------------------------------
    # $HOME and $TMPDIR are the two variables whose value the guard knows. A command that
    # assigns either keeps it unresolvable rather than judging it against a stale value.
    HOME_ASSIGNED = bool(re.search(r"(?<![\w$])HOME=", command))
    TMP_ASSIGNED = bool(re.search(r"(?<![\w$])TMPDIR=", command))
    tmp_env = "" if TMP_ASSIGNED else normalize(os.environ.get("TMPDIR") or "")
    if tmp_env in NEVER_ROOTS or len(tmp_env) <= 1:
        tmp_env = ""

    def expand_known(t):
        if not HOME_ASSIGNED:
            m = re.match(r'\$(?:HOME|\{HOME\})"?(?=/|$)', t)
            if m:
                return home_n + t[m.end():]
        if tmp_env:
            m = re.match(r'\$(?:TMPDIR|\{TMPDIR\})"?(?=/|$)', t)
            if m:
                return tmp_env + t[m.end():]
            m = re.match(r'\$\{TMPDIR\}"?(?=[^/"])', t)
            if m:
                return tmp_env + "/" + t[m.end():]
        if t == "~" or t.startswith("~/"):
            return home_n + t[1:]
        m = re.match(r"~([A-Za-z0-9._-]+)(?=/|$)", t)
        if m:
            try:
                import pwd
                return pwd.getpwnam(m.group(1)).pw_dir + t[m.end():]
            except Exception:
                return None
        return t

    def resolve(raw):
        # Absolute normalized path, or None when the shell decides it at run time.
        t = (raw or "").strip().strip("\"'")
        if not t:
            return None
        t = expand_known(t)
        if not t or t[0] in "$%~`":
            return None
        if "$(" in t or "`" in t or "<(" in t:
            return None
        if t.startswith("/"):
            return normalize(t)
        if CWD[0] is None:
            return None
        return normalize(CWD[0] + "/" + t)

    def is_pattern(p):
        return any(c in p for c in "*?[$")

    def pattern_segs(p):
        # Segments to fnmatch. A variable inside a segment can be anything, dotfiles included;
        # a shell glob does not match a leading dot unless it spells one.
        out = []
        for seg in p.strip("/").lower().split("/"):
            if "$" in seg:
                seg = re.sub(r"\$(\{[^}]*\}|[a-z_][a-z0-9_]*)", "*", seg)
                m = re.search(r"[$`]", seg)
                out.append(((seg[:m.start()] + "*") if m else seg, True))
            else:
                out.append((seg, False))
        return out

    def seg_match(name, pat):
        glob, dot_ok = pat
        if not any(c in glob for c in "*?["):
            return name == glob
        if name.startswith(".") and not glob.startswith(".") and not dot_ok:
            return False
        return fnmatch.fnmatchcase(name, glob)

    def segs(p):
        s = p.strip("/").lower()
        return s.split("/") if s else []

    def match_prefix(pat, path_segs):
        return all(seg_match(n, q) for n, q in zip(path_segs, pat))

    def literal_prefix(p):
        out = []
        for seg in p.split("/"):
            if any(c in seg for c in "*?[$"):
                break
            out.append(seg)
        return "/".join(out) or "/"

    def under_eq(p, root):
        p, root = p.rstrip("/").lower() or "/", root.rstrip("/").lower() or "/"
        return p == root or root == "/" or p.startswith(root + "/")

    def under(p, root):
        return under_eq(p, root) and p.rstrip("/").lower() != root.rstrip("/").lower()

    def real_form(r, raw):
        # The path the kernel will act on: the parent with symlinks followed, and the leaf
        # followed too when the target ends in / (rm -rf link/ removes what link points to).
        try:
            if not os.path.lexists(r):
                parent = os.path.dirname(r) or "/"
                if not os.path.exists(parent):
                    return None
                return normalize(os.path.realpath(parent) + "/" + os.path.basename(r))
            if raw.rstrip().endswith("/") or raw.rstrip().endswith("/."):
                return normalize(os.path.realpath(r))
            return normalize(os.path.realpath(os.path.dirname(r) or "/") + "/" + os.path.basename(r))
        except Exception:
            return None

    def reproducible(r, below=None):
        rel = r[len(below):] if below and under(r, below) else r
        return any(part in REPRODUCIBLE for part in rel.split("/"))

    def inside_allowed(r):
        pat = is_pattern(r)
        lp = literal_prefix(r) if pat else r
        for a in allowed:
            if not under_eq(lp, a):
                continue
            if lp.rstrip("/").lower() == a.lower() and not pat and a != session_cwd:
                continue            # deleting an allowed root itself is not working inside it
            return True
        return False

    def inside_allowed_real(r, raw):
        if not inside_allowed(r):
            return False
        if is_pattern(r):
            return True
        rf = real_form(r, raw)
        if rf is None or rf.lower() == r.lower():
            return True
        return any(under_eq(rf, a) for a in allowed_real) or inside_allowed(rf)

    def system_hit(r):
        if r.rstrip("/") in ("", "/"):
            return "/"
        if is_pattern(r):
            pat = pattern_segs(r)
            for s in SYSTEM_PATHS:
                ss = segs(s)
                if len(ss) == len(pat) and match_prefix(pat, ss):
                    return s
            return None
        low = r.rstrip("/").lower()
        return next((s for s in SYSTEM_PATHS if s.lower() == low), None)

    HOMES = {home_n.lower()}
    try:
        HOMES.add(normalize(os.path.realpath(home_n)).lower())
    except Exception:
        pass

    def all_guarded(ancestors=False):
        # Project-relative control files (.git/hooks and the like) guard against writes; a
        # delete of the whole project that holds them is judged by the containment model.
        ctl = control_abs if ancestors else control_paths()
        return [(p, False) for p in protected] + [(c, True) for c in ctl] + \
               [(h, False) for h in HOMES]

    def self_or_ancestor(r, recursive):
        # The target IS a protected path, or (for a verb that takes a directory with it) holds
        # one that exists. Being inside the tree does not change this. Project-relative control
        # files (.git/hooks and the like) count only as themselves: deleting a whole project
        # that holds them is left to the containment model.
        pat = pattern_segs(r) if is_pattern(r) else None
        whole = set(p.lower() for p, _ in all_guarded(ancestors=True))
        for p, _ in all_guarded():
            deep = recursive and p.lower() in whole
            if pat is not None:
                ps = segs(p)
                if len(pat) == len(ps) and match_prefix(pat, ps):
                    return p
                if deep and len(pat) < len(ps) and match_prefix(pat, ps) and os.path.lexists(p):
                    return p
            else:
                if r.rstrip("/").lower() == p.rstrip("/").lower():
                    return p
                if deep and under(p, r) and os.path.lexists(p):
                    return p
        return None

    def under_guarded(r):
        # The target sits below a protected path or control file. Working inside a protected
        # tree is allowed when the session started inside it (an allowed root that is itself
        # inside the tree); control files never get that exemption.
        pat = is_pattern(r)
        lp = literal_prefix(r) if pat else r
        for p, is_control in all_guarded():
            if p.rstrip("/").lower() in HOMES:
                continue            # the home directory is protected itself, not its whole tree
            if not (under(lp, p) or (pat and lp.rstrip("/").lower() == p.rstrip("/").lower())):
                continue
            if reproducible(r, p):
                continue
            if not is_control and any(under_eq(lp, a) and under_eq(a, p) for a in allowed):
                continue
            return p
        return None

    def expand_braces(target):
        # The shell expands {a,b} and {x..y} before the verb sees them; a range reads as a
        # glob. None past 64 spellings.
        target = re.sub(r"\{[^{},]*\.\.[^{},]*\}", "*", target)
        prev = None
        while prev != target:       # {d} with no comma is literal; hold it aside
            prev, target = target, re.sub(r"\{([^{},]*)\}", "\x00\\1\x01", target)
        out, todo = [], [target]
        while todo:
            t = todo.pop()
            m = re.search(r"\{([^{}]*,[^{}]*)\}", t)
            if not m:
                out.append(t.replace("\x00", "{").replace("\x01", "}"))
                continue
            todo += [t[:m.start()] + alt + t[m.end():] for alt in m.group(1).split(",")]
            if len(out) + len(todo) > 64:
                return None
        return out

    def spellings(raw):
        alts = expand_braces(raw)
        if alts is None:
            return [re.sub(r"\{[^}]*\}?", "*", raw)]
        return alts

    def judge_delete(targets, verb, recursive, contained_rule):
        """Hard reason for any target that is a system path or guarded, else None.
        With contained_rule, also report (via the second value) targets outside the roots."""
        outside = []
        for raw in targets:
            for sp in spellings(raw):
                r = resolve(sp)
                if r is None:
                    outside.append(raw)
                    continue
                forms = [r]
                rf = None if is_pattern(r) else real_form(r, sp)
                if rf and rf.lower() != r.lower():
                    forms.append(rf)
                for lk, tg in LINKS.items():
                    # A link this command made: a path through it lands on its target.
                    if under(r, lk) or (r.lower() == lk.lower() and sp.rstrip().endswith(("/", "/."))):
                        forms.append(normalize(tg + r[len(lk):]))
                for f in forms:
                    s = system_hit(f)
                    if s:
                        return ("SYSTEM_PATH", "`%s` targeting a system path (%s)" % (verb, s)), []
                    p = self_or_ancestor(f, recursive)
                    if p:
                        return ("PROTECTED", "`%s` would destroy a protected path (%s)" % (verb, p)), []
                for f in forms:
                    p = under_guarded(f)
                    if p:
                        return ("PROTECTED", "`%s` deleting inside a protected path (%s)"
                                % (verb, p)), []
                if contained_rule and not (inside_allowed_real(r, sp) or reproducible(r)):
                    outside.append(raw)
        return None, outside

    # ---- per-command rules ---------------------------------------------------------------
    def mv_sources_dest(args):
        # GNU mv/cp/ln can name the destination with -t DIR / --target-directory=DIR, and then
        # every operand is a source.
        ops, to_dir, i, dest = [], False, 0, None
        while i < len(args):
            a = args[i]
            i += 1
            if a == "--":
                ops += args[i:]
                break
            if a.startswith("--"):
                name, _, val = a[2:].partition("=")
                if name and "target-directory".startswith(name):
                    to_dir = True
                    dest = val if val else (args[i] if i < len(args) else None)
                    if not val:
                        i += 1
                elif len(name) > 1 and "suffix".startswith(name) and not val:
                    i += 1
                continue
            if a.startswith("-") and a != "-":
                for j, c in enumerate(a[1:]):
                    if c in "tS":
                        if c == "t":
                            to_dir = True
                            dest = a[j + 2:] or (args[i] if i < len(args) else None)
                        if j == len(a) - 2:
                            i += 1
                        break
                continue
            ops.append(a)
        if to_dir:
            return ops, dest
        return ops[:-1], (ops[-1] if ops else None)

    def find_start_paths(args):
        paths, i = [], 0
        while i < len(args) and args[i] in ("-L", "-H", "-P", "-E", "-d", "-s", "-x", "-X"):
            i += 1
        while i < len(args):
            if args[i].startswith("-") or args[i] in ("(", ")", "!"):
                break
            paths.append(args[i]); i += 1
        return paths

    def find_exec_commands(args):
        out, i = [], 0
        while i < len(args):
            if args[i] in ("-exec", "-execdir", "-ok", "-okdir"):
                j = i + 1
                cmd = []
                while j < len(args) and args[j] not in (";", "\\;", "+"):
                    cmd.append(args[j]); j += 1
                out.append(cmd)
                i = j
            i += 1
        return out

    def redirect_targets(segment):
        # > and >> targets at the top quoting level, dequoted. 2>&1 and >&2 name no file.
        out, i = [], 0
        single = double = escaped = False
        while i < len(segment):
            ch = segment[i]
            if escaped:
                escaped = False; i += 1; continue
            if ch == "\\":
                escaped = True
            elif ch == "'" and not double:
                single = not single
            elif ch == '"' and not single:
                double = not double
            elif ch == ">" and not single and not double:
                if re.match(r">?&\s*(\d+|-)(?![\w./])", segment[i + 1:]):
                    i += 1; continue
                rest = segment[i + 1:].lstrip(">&| \t")
                m = re.match(r"(?:\"[^\"]*\"|'[^']*'|\\.|[^\s;&|<>])+", rest)
                if m:
                    toks = tokenize(m.group(0)) or [m.group(0)]
                    out.append(toks[0] if toks else m.group(0))
                    i += 1 + (len(segment[i + 1:]) - len(rest)) + m.end()
                    continue
            i += 1
        return out

    def redirect_to_block_device(segment):
        for t in redirect_targets(segment):
            if re.match(r"/dev/(r?disk|sd|nvme|hd|vd|xvd|mmcblk)", t):
                return t
        return None

    def existing_files(targets):
        out = []
        for t in targets:
            if t.startswith("-"):
                continue
            r = resolve(t)
            if r and os.path.isfile(r):
                out.append(r)
        return out

    def opt_value(args, prefix):
        return [a.split("=", 1)[1] for a in args if a.startswith(prefix)]

    def last_operand(args):
        vals = [a for a in args if not a.startswith("-")]
        return vals[-1:] if vals else []

    def is_inplace_edit(base, args):
        # sed -i, sed -Ei, sed -I (BSD), --in-place[=SUFFIX] and its abbreviations, perl -pi.
        if base not in ("sed", "perl"):
            return False
        for a in args:
            if a.startswith("--"):
                name = a[2:].split("=", 1)[0]
                if base == "sed" and name and "in-place".startswith(name):
                    return True
                continue
            for ch in (a[1:] if a.startswith("-") else ""):
                if ch == "i" or (ch == "I" and base == "sed"):
                    return True
                if base == "sed" and ch in "ef":
                    break
                if base == "perl" and not (ch.isdigit() or ch in "acfghlnpsStTuUvwWX"):
                    break
        return False

    def inplace_files(args):
        # Only an operand that already exists can be edited in place; a glob is expanded the
        # way the shell will expand it.
        import glob as _g
        out = []
        for t in value_stripped(args, ("-e", "-f", "--expression", "--file")):
            r = resolve(t)
            if r and any(c in t for c in "*?["):
                out += [p for p in _g.glob(r) if os.path.isfile(p)]
            elif r and os.path.isfile(r):
                out.append(r)
        return out

    def control_hit(r):
        return next((c for c in control_paths() if under_eq(r, c)), None) if r else None

    def control_hit_forms(raw):
        r = resolve(raw)
        if not r:
            return None
        hit = control_hit(r)
        if hit:
            return hit
        rf = None if is_pattern(r) else real_form(r, raw)
        return control_hit(rf) if rf else None

    def zero_write_targets(segment, base, args):
        # Shapes that leave a file empty: `> f`, `: > f`, cp or install from /dev/null,
        # dd from /dev/zero or from nothing. Writing content is not emptying.
        if base in ("", ":", "true"):
            return redirect_targets(segment)
        if base == "cp" and any(a in ZERO_SOURCES for a in args):
            return last_operand(args)
        if base == "install" and any(a in ZERO_SOURCES for a in args):
            return last_operand(args)
        if base == "dd":
            src = opt_value(args, "if=")
            if not src or src[0] in ZERO_SOURCES:
                return opt_value(args, "of=")
        return []

    def check_writes(segment, base, args):
        # The control files decide which guards run: no command writes over, empties or
        # rewrites them in place. Emptying any file under a protected path is refused too.
        cands = list(redirect_targets(segment))
        if base in ("tee", "truncate"):
            cands += value_stripped(args, ("-s", "--size", "-r", "--reference"))
        if is_inplace_edit(base, args):
            cands += inplace_files(args)
        if base in ("cp", "install"):
            dest = mv_sources_dest(value_stripped_keep(args, ("-m", "-o", "-g")))[1]
            if dest:
                cands.append(dest)
        if base == "dd":
            cands += opt_value(args, "of=")
        for c in cands:
            hit = control_hit_forms(c)
            if hit:
                return ("CONTROL_FILE", "writing over or emptying a control file (%s)" % hit)
        for r in existing_files(zero_write_targets(segment, base, args)):
            if inside_allowed(r):
                continue
            p = under_guarded(r)
            if p:
                return ("PROTECTED", "emptying a file inside a protected path (%s)" % r)
        return None

    def owner_loses(mode):
        # (read lost, execute lost) for the owner under a chmod mode. Unreadable spellings
        # count as losing both.
        if re.fullmatch(r"[0-7]{1,4}", mode):
            d = int(mode.zfill(3)[-3])
            return (not d & 4, not d & 1)
        r = x = True
        for clause in mode.split(","):
            m = re.fullmatch(r"([ugoa]*)((?:[-+=][rwxXst]*)+)", clause)
            if not m:
                return (True, True)
            if m.group(1) and not set(m.group(1)) & set("ua"):
                continue
            for op, perms in re.findall(r"([-+=])([rwxXst]*)", m.group(2)):
                has_r, has_x = "r" in perms, bool(set(perms) & set("xX"))
                if op == "=":
                    r, x = has_r, has_x
                elif op == "-":
                    r, x = r and not has_r, x and not has_x
                else:
                    r, x = r or has_r, x or has_x
        return (not r, not x)

    def needs_exec(r):
        # Execute matters for a directory (it is what lets anyone enter) and for a script.
        try:
            if os.path.isdir(r):
                return True
            if os.path.exists(r):
                return bool(os.stat(r).st_mode & 0o100)
        except Exception:
            return True
        return bool(re.search(r"\.(sh|bash|zsh|py|pl|rb|js)$|/hooks(/|$)", r)) or \
            any(under(c, r) for c in control_paths())

    def check_mode_change(base, args):
        # A guard that cannot run, a settings file that cannot be read and a tree nobody can
        # enter are as lost as deleted ones.
        if base not in ("chmod", "chflags", "chown", "chgrp"):
            return None
        recursive = short_flag(args, "R") or "--recursive" in args
        flags = [a for a in args if a.startswith("-") and len(a) > 1 and not re.fullmatch(r"-[rwxXst]+", a)]
        rest = [a for a in args if a not in flags]
        if not rest:
            return None
        mode, files = rest[0], rest[1:]
        for f in files:
            for sp in spellings(f):
                r = resolve(sp)
                if not r:
                    continue
                s = system_hit(r)
                if recursive and s:
                    return ("SYSTEM_PATH", "recursive `%s` on a system path (%s)" % (base, s))
                if recursive:
                    p = self_or_ancestor(r, False) or under_guarded(r)
                    if not p and base == "chmod" and any(owner_loses(mode)):
                        p = self_or_ancestor(r, True)
                    if p:
                        return ("PROTECTED", "recursive `%s` over a protected path (%s)" % (base, p))
                if base != "chmod":
                    continue
                if mode[:2] in ("+a", "=a"):
                    if "deny" not in " ".join(files).lower():
                        continue
                    r_lost = x_lost = True
                elif mode.startswith("-a"):
                    continue        # removing an ACL entry gives access back
                else:
                    r_lost, x_lost = owner_loses(mode)
                if not (r_lost or x_lost):
                    continue
                hit = control_hit(r) or next((c for c in control_paths() if under(c, r)), None)
                if hit and not r_lost and not needs_exec(r):
                    hit = None      # dropping execute from a plain data file locks nobody out
                if hit:
                    return ("CONTROL_FILE", "`chmod %s` locking the owner out of a control file (%s)"
                            % (mode, hit))
                p = self_or_ancestor(r, False)
                is_home = bool(p) and p.rstrip("/").lower() in HOMES
                if p and not is_home and x_lost and os.path.isdir(r):
                    return ("PROTECTED", "`chmod %s` removing access to a protected directory (%s)"
                            % (mode, p))
                if is_home and (x_lost or r_lost):
                    return ("PROTECTED", "`chmod %s` removing access to the home directory" % mode)
        return None

    def check_relocate(base, args):
        # mv carries a tree away as surely as rm; mv, ln, cp and install can put something
        # else in a control file's place.
        if base not in ("mv", "ln"):
            return None
        vals = value_stripped(args, ("-S", "--suffix"))
        srcs, dest = mv_sources_dest(args)
        if base == "mv":
            for s in srcs:
                for sp in spellings(s):
                    r = resolve(sp)
                    if r is None:
                        continue
                    sh = system_hit(r)
                    if sh:
                        return ("SYSTEM_PATH", "`mv` relocating a system path (%s)" % sh)
                    p = self_or_ancestor(r, True)
                    if p:
                        return ("PROTECTED", "`mv` relocating a protected path (%s)" % p)
                    hit = control_hit_forms(sp)
                    if hit:
                        return ("CONTROL_FILE", "`mv` moving a control file away (%s)" % hit)
        if dest:
            hit = control_hit_forms(dest)
            if hit:
                return ("CONTROL_FILE", "`%s` replacing a control file (%s)" % (base, hit))
            r = resolve(dest)
            if r and (base == "mv" or short_flag(args, "f") or "--force" in args):
                if system_hit(r) and not os.path.isdir(r):
                    return ("SYSTEM_PATH", "`%s` replacing a system path (%s)" % (base, r))
                if os.path.isfile(r) and not inside_allowed(r) and under_guarded(r):
                    return ("PROTECTED", "`%s` replacing a file inside a protected path (%s)"
                            % (base, r))
        return None

    def check_removal(base, args):
        # Every verb whose effect is to delete, judged by the same containment model.
        shorts = "".join(a[1:] for a in args if a.startswith("-") and not a.startswith("--"))
        rec = "r" in shorts or "R" in shorts or "--recursive" in args
        force = "f" in shorts or "--force" in args
        vals = operands(args)
        if base in ("rm", "srm", "rmdir"):
            if not vals:
                if rec or force:
                    return (SOFT, "recursive or forced `%s` with targets fed in at run time" % base)
                return None
            hard, outside = judge_delete(vals, base, rec, True)
            if hard:
                return hard
            if outside and (rec or force or len(vals) > 1 or
                            any(any(c in v for c in "*?[") for v in vals)):
                return (SOFT, "`%s` %s outside the allowed roots (%s)"
                        % (base, "recursive or forced delete" if (rec or force) else "batch delete",
                           outside[0]))
            return None
        if base in ("unlink", "trash", "shred"):
            if base == "shred" and any(v.startswith("/dev/") for v in vals):
                return ("DISK_POWER", "`shred` on a device")
            vals = value_stripped(args, ("-n", "--iterations", "-s", "--size"))
            hard, _ = judge_delete(vals, base, base == "trash", False)
            return hard
        if base == "truncate":
            vals = value_stripped(args, ("-s", "--size", "-r", "--reference"))
            hard, _ = judge_delete(vals, base, False, False)
            return hard
        if base in PACKERS:
            if any(a in ("--keep", "--stdout", "--to-stdout", "--test", "--list") for a in args) \
                    or any(c in shorts for c in "kctld"):
                return None
            hard, _ = judge_delete(vals, base, rec, False)
            return hard
        if base in ("zstd", "lz4") and "--rm" in args:
            hard, _ = judge_delete(vals, base, rec, False)
            return hard
        if base == "zip" and ("--move" in args or "m" in shorts):
            hard, _ = judge_delete(vals[1:], "zip -m", rec or "--recurse-paths" in args, False)
            return hard
        if base in ("tar", "bsdtar") and "--remove-files" in args:
            hard, _ = judge_delete(vals, "tar --remove-files", True, False)
            return hard
        if base == "rsync":
            local = [v for v in vals if not re.match(r"^[^/]*:", v)]
            if "--remove-source-files" in args:
                srcs = [v for v in vals[:-1] if v in local]
                hard, _ = judge_delete(srcs, "rsync --remove-source-files", True, False)
                if hard:
                    return hard
            if any(a.startswith("--delete") for a in args) and vals and vals[-1] in local:
                hard, outside = judge_delete(vals[-1:], "rsync --delete", True, True)
                if hard:
                    return hard
                if outside:
                    return (SOFT, "`rsync --delete` into %s, outside the allowed roots" % outside[0])
            return None
        if base == "find":
            execs = find_exec_commands(args)
            destructive = any(a in ("-delete", "-fdelete") for a in args) or any(
                c and base_name(c[0]) in REMOVE_VERBS + PACKERS + ("rmdir", "truncate", "mv")
                for c in execs)
            starts = find_start_paths(args) or ["."]
            # A name or path test narrows what goes; without one, everything below the start
            # path is deleted, protected paths inside it included.
            filtered = any(a in ("-name", "-iname", "-path", "-ipath", "-regex", "-iregex",
                                 "-wholename", "-iwholename") for a in args)
            if destructive:
                hard, outside = judge_delete(starts, "find -delete", not filtered, True)
                if hard:
                    return hard
                if outside:
                    return (SOFT, "`find` deleting under %s, outside the allowed roots" % outside[0])
            for c in execs:
                # The command find runs, with {} standing for something under each start path.
                for s in starts:
                    sub = [s.rstrip("/") + "/_" if t == "{}" else t for t in c]
                    r = scan(" ".join(shlex.quote(t) for t in sub), 1)
                    if r:
                        return r
            return None
        return None

    def check_disk_power(base, args, segment):
        if base in ("shutdown", "reboot", "halt", "poweroff"):
            return ("DISK_POWER", "system power control (`%s`)" % base)
        if base in ("init", "telinit") and any(a in ("0", "6") for a in args):
            return ("DISK_POWER", "runlevel change to halt or reboot")
        if base == "systemctl" and args and args[0] in ("poweroff", "reboot", "halt", "kexec"):
            return ("DISK_POWER", "system power control (`systemctl %s`)" % args[0])
        if base == "dd" and any(a.lower().startswith("of=/dev/") and a.lower() not in
                                ("of=/dev/null", "of=/dev/stdout", "of=/dev/stderr") for a in args):
            return ("DISK_POWER", "`dd` writing directly to a device")
        if base in ("mkfs", "wipefs", "fdisk", "sfdisk", "parted", "sgdisk", "gdisk") and \
                any(a.startswith("/dev/") for a in args):
            return ("DISK_POWER", "destructive disk operation (`%s`)" % base)
        if base.startswith("mkfs.") or base.startswith("newfs"):
            return ("DISK_POWER", "filesystem creation (`%s`)" % base)
        if base == "diskutil" and args and args[0].lower() in (
                "erasedisk", "erasevolume", "partitiondisk", "zerodisk", "randomdisk",
                "secureerase", "reformat", "apfs") and not (
                args[0].lower() == "apfs" and not (len(args) > 1 and args[1].lower() in (
                    "deletecontainer", "deletevolume", "erasevolume", "deletesnapshot"))):
            return ("DISK_POWER", "destructive disk operation (`diskutil %s`)" % " ".join(args[:2]))
        return None

    def check_recovery(base, args):
        # The recovery copies: backups, snapshots, remote history, credential vaults. And the
        # OS protections that stand behind everything else.
        joined = " ".join(args).lower()
        if base == "tmutil" and args and args[0].lower() in (
                "deletelocalsnapshots", "deletebackup", "delete", "disable", "disablelocal",
                "removedestination", "thinlocalsnapshots"):
            return ("RECOVERY", "deleting or disabling Time Machine backups (`tmutil %s`)" % args[0])
        if base == "gh":
            if len(args) >= 2 and args[0] == "repo" and args[1] == "delete":
                return ("RECOVERY", "deleting a GitHub repository (`gh repo delete`)")
            if args and args[0] == "api" and re.search(r"(-x|--method)[ =]?delete\b", joined) and \
                    re.search(r"(^|[\s/])repos/[^/\s]+/[^/\s]+/?(\s|$)", joined):
                return ("RECOVERY", "deleting a GitHub repository via `gh api`")
        if base == "git":
            if "push" in args:
                i = args.index("push")
                rest = args[i + 1:]
                if any(a in ("-f", "--force") or (re.fullmatch(r"-[a-z]+", a) and "f" in a)
                       for a in rest) or any(a.startswith("+") for a in rest):
                    return ("RECOVERY", "force-push overwriting remote history")
            if "reflog" in args and "expire" in args:
                return ("RECOVERY", "expiring the git reflog (destroys local recovery of history)")
            if "gc" in args and any(a.startswith("--prune") and a != "--prune=never" for a in args):
                return ("RECOVERY", "`git gc --prune` (drops unreferenced recovery objects)")
        if base == "op" and len(args) >= 2 and args[1] == "delete" and args[0] in (
                "item", "document", "vault", "user", "group"):
            if args[0] in ("item", "document") and "--archive" in args:
                return None         # archived items can be restored
            return ("RECOVERY", "deleting a 1Password %s" % args[0])
        if base == "csrutil" and "disable" in joined:
            return ("SECURITY", "disabling System Integrity Protection")
        if base == "spctl" and ("master-disable" in joined or "global-disable" in joined):
            return ("SECURITY", "disabling Gatekeeper")
        if base == "fdesetup" and args and args[0].lower() == "disable":
            return ("SECURITY", "disabling FileVault")
        return None

    # ---- download-and-run cradles --------------------------------------------------------
    STDIN_INTERPRETERS = ("python", "perl", "ruby", "node", "php", "pwsh", "powershell", "osascript")
    FETCHERS = {"curl", "wget", "fetch", "aria2c", "http", "https", "xh", "invoke-webrequest", "iwr"}

    def nested_shell_script(args):
        for i, arg in enumerate(args):
            if arg in ("-c", "-lc", "-lic", "-ic", "-ec", "-xc"):
                return args[i + 1] if i + 1 < len(args) else None
            if arg.startswith("-") and not arg.startswith("--") and "c" in arg and len(arg) <= 5:
                return args[i + 1] if i + 1 < len(args) else None
        return None

    def decoder_stage(tokens):
        # A stage that turns unreadable text into a command: base64 -d, xxd -r, a tr or rev
        # that un-scrambles it, a decompressor. What it outputs cannot be judged from the text.
        ub, ua = base_name(tokens[0]), tokens[1:]
        return bool((ub in ("base64", "base32") and any(a in ("-d", "-D", "--decode") for a in ua))
                    or (ub == "openssl" and "-d" in ua) or (ub == "xxd" and "-r" in ua)
                    or ub in ("uudecode", "gunzip", "zcat", "bzcat", "xzcat", "tr", "rev", "iconv")
                    or (ub in ("gzip", "bzip2", "xz") and ("-d" in ua or "--decompress" in ua)))

    def stdin_is_program(tokens):
        # Does this pipeline stage execute what arrives on stdin? A `-c` script or a script
        # file does not; `| sh`, `| python3`, `| python3 -` and `| bash -s` do.
        if not tokens:
            return False
        base, args = base_name(tokens[0]), tokens[1:]
        if base in NESTED_SHELLS:
            if nested_shell_script(args) is not None:
                return False
            return "-s" in args or not any(not a.startswith("-") for a in args)
        if base.startswith(STDIN_INTERPRETERS):
            for i, a in enumerate(args):
                if a in ("-c", "-e", "-E", "-m", "-r"):
                    script = args[i + 1] if i + 1 < len(args) else ""
                    return bool(re.search(r"\b(exec|eval|compile|system)\b", script) and
                                re.search(r"stdin|STDIN|<>|readFileSync\(0", script))
                if a == "-":
                    return True
                if not a.startswith("-"):
                    return False
            return True
        return False

    def pipe_into_program(text, depth):
        stages = []
        for seg, conn in split_with_connectors(text):
            stages.append(seg)
            if conn == "|":
                continue
            for k in range(1, len(stages)):
                toks = tokenize(stages[k].strip())
                if toks is None or not stdin_is_program(strip_wrappers(toks)):
                    continue
                for up in stages[:k]:
                    utoks = strip_wrappers(tokenize(up.strip()) or [])
                    if not utoks:
                        continue
                    ub, ua = base_name(utoks[0]), utoks[1:]
                    if ub in FETCHERS:
                        return ("CRADLE", "a download piped into an interpreter")
                    if decoder_stage(utoks):
                        return ("CRADLE", "decoded or obfuscated text piped into an interpreter")
                    if ub in ("echo", "printf") and base_name(strip_wrappers(toks)[0]) in NESTED_SHELLS:
                        r = scan(" ".join(a for a in ua if a not in ("-n", "-e", "-E")), depth + 1)
                        if r:
                            return r
            stages = []
        return None

    def substituted_fetch_executed(tokens):
        # bash <(curl ...), source <(curl ...), sh -c "$(curl ...)", eval "$(wget ...)".
        if not tokens:
            return False
        base = base_name(tokens[0])
        if base not in NESTED_SHELLS and base not in ("source", ".", "eval") \
                and not base.startswith(STDIN_INTERPRETERS):
            return False
        for body in extract_substitutions(" ".join(tokens[1:])):
            for seg in split_segments(body):
                st = strip_wrappers(tokenize(seg.strip()) or [])
                if st and (base_name(st[0]) in FETCHERS or decoder_stage(st)):
                    return True
        return False

    # ---- variables -----------------------------------------------------------------------
    def collect_assignments(segments):
        out = {}
        for segment in segments:
            tokens = tokenize(segment.strip())
            if not tokens:
                continue
            first = base_name(tokens[0])
            toks = tokens[1:] if first in ("export", "readonly", "typeset", "local", "declare") else tokens
            toks = [t for t in toks if not (t.startswith("-") and first != tokens[0])]
            if not toks or not all(is_assignment(t) for t in toks):
                continue
            for token in toks:
                name, _, value = token.partition("=")
                if value.strip():
                    out[name] = value.strip()
        return out

    def var_ref(token):
        if not token.startswith("$"):
            return None
        rest = token[1:]
        if rest.startswith("{"):
            name = rest[1:-1] if rest.endswith("}") else ""
            return name if name and all(c.isalnum() or c == "_" for c in name) else None
        return rest if rest and all(c.isalnum() or c == "_" for c in rest) else None

    def expand_var_args(tokens, variables):
        changed, out = False, []
        for t in tokens:
            v = var_ref(t)
            if v is not None and v in variables:
                out.append(variables[v]); changed = True
            else:
                out.append(t)
        return out if changed else None

    def check_indirection(segment, variables, depth):
        # X=rm; $X -rf ~   and   eval "$X -rf ~"   and   bash -c "$X ..."
        if not variables:
            return None
        tokens = strip_wrappers(tokenize(segment) or [])
        if not tokens:
            return None
        base = base_name(tokens[0])
        if base == "eval":
            return check_indirection(" ".join(tokens[1:]), variables, depth + 1)
        if base in NESTED_SHELLS:
            script = nested_shell_script(tokens[1:])
            return check_indirection(script, variables, depth + 1) if script else None
        v = var_ref(tokens[0])
        if v is not None and v in variables:
            expanded = [variables[v]] + tokens[1:]
            expanded = expand_var_args(expanded, variables) or expanded
            return scan(" ".join(expanded), depth + 1)
        expanded = expand_var_args(tokens, variables)
        return scan(" ".join(expanded), depth + 1) if expanded else None

    def cd_destination(args, variables):
        args = [a for a in args if a not in ("-L", "-P", "-e", "-@", "--")]
        if not args:
            return home_n
        a = args[0]
        v = var_ref(a.split("/", 1)[0])
        if v is not None:
            if v in variables:
                val = variables[v]
            elif v in ("HOME", "TMPDIR"):
                val = os.environ.get(v) or ""
            else:
                return None
            a = val.rstrip("/") + ("/" + a.split("/", 1)[1] if "/" in a else "")
        a = expand_known(a.strip("\"'")) or ""
        if not a or a == "-" or a[0] in "$%~`" or "$(" in a:
            return None
        if not a.startswith("/"):
            if CWD[0] is None:
                return None
            a = CWD[0] + "/" + a
        p = normalize(a)
        # A cd into a missing directory fails and the next command runs where the shell was,
        # so an unverifiable destination makes relative paths unknown.
        return p if os.path.isdir(p) else None

    # ---- heredocs and library calls ------------------------------------------------------
    def strip_heredoc_bodies(text):
        # A heredoc body is data unless a shell or an interpreter reads it. Shell bodies are
        # scanned whole; interpreter bodies keep only lines that shell out or delete.
        interpreters = NESTED_SHELLS | {"python", "python3", "perl", "ruby", "node", "php",
                                        "osascript", "awk", "tclsh"}
        lines = text.split("\n")
        out, i = [], 0
        while i < len(lines):
            line = lines[i]
            out.append(line)
            m = re.search(r"<<-?\s*[\"']?([A-Za-z_][A-Za-z0-9_]*)[\"']?", line)
            if not m:
                i += 1; continue
            delim = m.group(1)
            toks = tokenize(line) or []
            executed = any(base_name(t) in interpreters for t in toks)
            shell_body = any(base_name(t) in NESTED_SHELLS for t in toks)
            i += 1
            body = []
            while i < len(lines) and lines[i].strip() != delim:
                body.append(lines[i]); i += 1
            terminated = i < len(lines)

            def acts(b):
                flat = "".join(b.split()).lower()
                return any(mk in flat for mk in EXEC_MARKERS + LIB_DELETE_MARKERS)

            # Without a closing delimiter this was not a heredoc (arithmetic <<, a quoted
            # string): keep every line so nothing after it is hidden.
            if not terminated or shell_body:
                out.extend(body)
            elif executed:
                out.extend([b for b in body if acts(b)])
            if terminated:
                out.append(lines[i]); i += 1
        return "\n".join(out)

    def collect_string_literals(arg):
        literals, i = [], 0
        while i < len(arg):
            ch = arg[i]
            if ch in ("'", '"'):
                quote, value, cur, esc = ch, [], i + 1, False
                while cur < len(arg):
                    inner = arg[cur]
                    if esc:
                        value.append(inner); esc = False
                    elif inner == "\\":
                        esc = True
                    elif inner == quote:
                        break
                    else:
                        value.append(inner)
                    cur += 1
                literals.append("".join(value)); i = cur + 1; continue
            i += 1
        return literals

    def library_shell_commands(text):
        stripped, index_map = [], []
        for idx, ch in enumerate(text):
            if not ch.isspace():
                stripped.append(ch.lower()); index_map.append(idx)
        stripped = "".join(stripped)
        out = []
        for marker in EXEC_MARKERS:
            frm = 0
            while True:
                found = stripped.find(marker, frm)
                if found < 0:
                    break
                frm = found + 1
                arg = extract_paren_arg(text, index_map[found + len(marker) - 1])
                if arg is None:
                    continue
                lits = collect_string_literals(arg)
                if lits:
                    out.append(" ".join(lits))
                    out.append("".join(lits))
        return out

    def library_delete_reason(text):
        # Quoting nests arbitrarily in python -c "...", so take quoted path literals straight
        # from the text. Only a literal that could be handed to the call counts.
        condensed = "".join(text.split()).lower()
        deletes = any(m in condensed for m in LIB_DELETE_MARKERS)
        moves = any(m in condensed for m in LIB_MOVE_MARKERS)
        if not (deletes or moves):
            return None
        cands = re.findall(r"""['"]((?:~|/|\$HOME/|\$\{HOME\}/)[A-Za-z0-9_./\-]*)\\?['"]""", text)
        recursive = moves or any(m in condensed for m in ("rmtree(", "rm_rf(", "rm_r(", "rmsync(", "removedirs("))
        for c in cands:
            r = resolve(c)
            if not r:
                continue
            s = system_hit(r)
            if s:
                return ("SYSTEM_PATH", "a library %s call targeting a system path (%s)"
                        % ("move" if moves and not deletes else "delete", s))
            p = self_or_ancestor(r, recursive) or (under_guarded(r) if deletes else control_hit(r))
            if p:
                return ("PROTECTED", "a library %s call on a protected path (%s)"
                        % ("move" if moves and not deletes else "delete", p))
        return None

    # ---- the scan ------------------------------------------------------------------------
    soft_hits = []
    LINKS = {}

    def note_symlink(toks):
        base, args = base_name(toks[0]), strip_redirections(toks[1:])
        if base != "ln" or not (short_flag(args, "s") or "--symbolic" in args):
            return
        srcs, dest = mv_sources_dest(args)
        rd = resolve(dest) if dest else (CWD[0] if len(srcs) == 1 else None)
        for src in srcs:
            if not rd:
                return
            link = rd + "/" + os.path.basename(src.rstrip("/")) if (os.path.isdir(rd) or not dest) else rd
            t = expand_known(src.strip("\"'")) or ""
            if not t or t[0] in "$%`":
                continue
            LINKS[normalize(link)] = normalize(t if t.startswith("/") else os.path.dirname(link) + "/" + t)

    def check_segment(segment, depth):
        dev = redirect_to_block_device(segment)
        if dev:
            return ("DISK_POWER", "redirect overwriting block device `%s`" % dev)
        # A subshell ( ... ) is a command list; its cd does not leak out.
        s = re.sub(r"^(?:(?:!|\{|then|do|else|if|while|until|time)\s+)+", "", segment.strip())
        if s.startswith("(") and not s.startswith("(("):
            inner = extract_paren_arg(s, 0)
            if inner is not None:
                saved = CWD[0]
                r = scan(inner, depth + 1)
                CWD[0] = saved
                rest = s[len(inner) + 2:]
                return r or (scan(rest, depth + 1) if rest.strip() else None)
        # A redirect with no command at all empties its target just as `: >` does.
        if re.match(r"^\s*>{1,2}[^&]", segment):
            r = check_writes(segment, "", [])
            if r:
                return r
        tokens = tokenize(segment)
        if not tokens:
            return None
        tokens = strip_wrappers(tokens)
        if not tokens:
            return None
        if substituted_fetch_executed(tokens):
            return ("CRADLE", "a download or decoded text executed through a substitution")
        if "/" in tokens[0] and any(c in tokens[0] for c in "*?["):
            # /bin/r? -rf X: the shell expands a glob in the command name before running it.
            import glob as _g
            for hit in sorted(_g.glob(expand_known(tokens[0]) or tokens[0]))[:16]:
                r = check_segment(" ".join(shlex.quote(t) for t in [hit] + tokens[1:]), depth + 1)
                if r:
                    return r
        base = base_name(tokens[0])
        if base == "eval":
            return scan(" ".join(tokens[1:]), depth + 1)
        if base == "trap" and len(tokens) > 1:
            return scan(tokens[1], depth + 1)
        if base in ("watch",) and len(tokens) > 1:
            return scan(" ".join(t for t in tokens[1:] if not t.startswith("-")), depth + 1)
        args = strip_redirections(tokens[1:])
        if base in NESTED_SHELLS:
            script = nested_shell_script(args)
            if script is not None:
                return scan(script, depth + 1)
            if "<<<" in tokens[1:]:
                i = tokens.index("<<<")
                if i + 1 < len(tokens):
                    return scan(tokens[i + 1], depth + 1)
        for check in (lambda: check_writes(segment, base, args),
                      lambda: check_mode_change(base, args),
                      lambda: check_relocate(base, args),
                      lambda: check_disk_power(base, args, segment),
                      lambda: check_recovery(base, args),
                      lambda: check_removal(base, args)):
            r = check()
            if r:
                return r
        return None

    def scan(text, depth):
        saved = CWD[0]
        try:
            return _scan(text, depth)
        finally:
            if depth > 0:
                CWD[0] = saved      # a nested script's cd does not move the outer shell

    def note(r):
        # Overridable reasons are recorded and the scan goes on, so an override can never
        # carry a hard-floor command that comes later in the same line.
        if r and r[0] == SOFT:
            soft_hits.append(r)
            return None
        return r

    def _scan(text, depth):
        if depth > 8:
            return None
        condensed = "".join(c for c in text if not c.isspace())
        if ":(){:|:&};:" in condensed or ":(){:|:&}" in condensed:
            return ("DISK_POWER", "fork bomb")
        r = note(pipe_into_program(text, depth))
        if r:
            return r
        r = note(library_delete_reason(text))
        if r:
            return r
        segments = split_segments(text)
        variables = collect_assignments(segments)
        assign_count = {}
        for seg in segments:
            for name in collect_assignments([seg.strip()]):
                assign_count[name] = assign_count.get(name, 0) + 1
        # T=$(mktemp) and D="$(mktemp -d)"/sub name a fresh path: resolve it under a synthetic
        # allowed root. Single-assigned names only, never with .. after the reference.
        mktemp_vars = {}
        for m in re.finditer(r'(?:^|[\s;&|(])([A-Za-z_]\w*)="?\$\(\s*mktemp\b[^)]*\)"?((?:/[\w.\-]+)*)', text):
            name, suffix = m.group(1), m.group(2)
            if ".." not in suffix and len(re.findall(r'(?:^|[\s;&|(])%s=' % name, text)) == 1:
                mktemp_vars[name] = MKTEMP_ROOT + "/" + name.lower() + suffix
        seen = {}
        positional = []
        for segment in segments:
            segment = segment.strip()
            if not segment:
                continue
            seg_vars = collect_assignments([segment])
            if seg_vars:
                # Values built from earlier single-assigned literals resolve too; anything that
                # still holds a $, a backtick or a quote stays unresolvable.
                for k, v in seg_vars.items():
                    if assign_count.get(k) != 1:
                        continue
                    for name, value in mktemp_vars.items():
                        v = re.sub(r"\$(?:\{%s\}|%s(?!\w))(?![^\s\"']*\.\.)" % (name, name),
                                   lambda _m, val=value: val, v)
                    for name, value in seen.items():
                        if value.startswith(("$", "`")) or "$(" in value or '"' in value or "'" in value:
                            continue
                        v = re.sub(r"\$(?:\{%s\}|%s(?!\w))" % (name, name), lambda _m, val=value: val, v)
                    seen[k] = v
                continue
            for name, value in mktemp_vars.items():
                ref = r"\$(?:\{%s\}|%s(?!\w))(?![^\s\"']*\.\.)" % (name, name)
                segment = re.sub(ref, lambda _m, v=value: v, segment)
            for name, value in seen.items():
                if value.startswith(("$", "`")) or "$(" in value or '"' in value or "'" in value:
                    continue
                segment = re.sub(r"\$(?:\{%s\}|%s(?!\w))" % (name, name), lambda _m, v=value: v, segment)
            r = note(check_indirection(segment, variables, depth))
            if r:
                return r
            raw_toks = tokenize(segment) or []
            if raw_toks[:1] == ["set"] and len(raw_toks) > 1 and \
                    (raw_toks[1] == "--" or not raw_toks[1].startswith(("-", "+"))):
                positional[:] = raw_toks[2:] if raw_toks[1] == "--" else raw_toks[1:]
            elif positional and raw_toks:
                # set -- rm -rf X; "$@": the verb and its targets live in the argument list.
                out, changed = [], False
                for t in raw_toks:
                    if t in ("$@", "$*", "${@}", "${*}"):
                        out += positional; changed = True
                    elif re.fullmatch(r"\$\{?[1-9]\}?", t):
                        n = int(t.strip("${}")) - 1
                        out.append(positional[n] if n < len(positional) else ""); changed = True
                    else:
                        out.append(t)
                if changed:
                    r = note(scan(" ".join(shlex.quote(t) for t in out), depth + 1))
                    if r:
                        return r
            r = note(check_segment(segment, depth))
            if r:
                return r
            toks = strip_wrappers(tokenize(segment) or [])
            if toks:
                note_symlink(toks)
            if toks and base_name(toks[0]) in ("cd", "pushd"):
                CWD[0] = cd_destination(toks[1:], seen)
            elif toks and base_name(toks[0]) == "popd":
                CWD[0] = None
        for body in extract_substitutions(text):
            r = note(scan(body, depth + 1))
            if r:
                return r
        for inner in library_shell_commands(text):
            r = note(scan(inner, depth + 1))
            if r:
                return (r[0], r[1] + ", run through a library exec call")
        return None

    hard = scan(strip_heredoc_bodies(command.strip()), 0)
    result = hard or (soft_hits[0] if soft_hits else None)
    return result, unattended, command


REMEDY = {
    "OUTSIDE_ROOTS": (
        "DO THIS INSTEAD: delete only inside the allowed roots (the session's working "
        "directory, $TMPDIR, and any delete_allowed_roots in the safety config), or name the "
        "exact files without -r/-f. Tool caches such as node_modules, .venv and __pycache__ "
        "may be deleted wherever they are. If the person you are working for wants this "
        "delete, they can let it through once by re-running it as: "
        "CLAUDE_GUARD_OVERRIDE='<why this is safe>' <command>"),
    "PROTECTED": (
        "DO THIS INSTEAD: leave this path in place. Protected paths (protected_paths and "
        "control_files in the safety config) are never deleted, moved away, emptied or "
        "locked by an agent, whichever directory the command runs from. If a file inside "
        "needs new content, write the content; if it really must go, ask the person to do it."),
    "CONTROL_FILE": (
        "DO THIS INSTEAD: control files decide which guards run, so no command overwrites, "
        "empties, moves or locks them. Propose the change to the person and let them make it."),
    "SYSTEM_PATH": (
        "DO THIS INSTEAD: this is an operating-system path, not project data. If a tool seems "
        "to need this, report the packaging or install problem rather than forcing it."),
    "DISK_POWER": (
        "DO THIS INSTEAD: nothing from an agent session. Disk, filesystem and power operations "
        "belong to a person at a real terminal who can see what is attached."),
    "CRADLE": (
        "DO THIS INSTEAD: download to a file, read it, then run it explicitly, for example: "
        "curl -fsSL <url> -o \"$TMPDIR/install.sh\" && less \"$TMPDIR/install.sh\" && "
        "bash \"$TMPDIR/install.sh\""),
    "RECOVERY": (
        "DO THIS INSTEAD: this destroys a recovery path (a backup, snapshot, remote history or "
        "vault entry). Use the reversible form: archive the repository, push a revert commit or "
        "use --force-with-lease, `op item delete --archive`. Otherwise ask the person to do it."),
    "SECURITY": (
        "DO THIS INSTEAD: leave the operating system's security features on. If a task claims "
        "to need one turned off, report that claim to the person."),
}


def main():
    import json
    try:
        data = json.loads(os.environ.get("HOOK_INPUT", "") or "{}")
        out = compute(data)
    except Exception:
        sys.exit(0)                 # fail open on anything the guard cannot parse
    if not out or not out[0]:
        sys.exit(0)
    (cls, reason), unattended, command = out

    # The override must be the very first thing in the command, so it cannot arrive from a
    # heredoc, a quoted string or file content.
    m = re.match(r"\s*CLAUDE_GUARD_OVERRIDE='([^']{8,})'\s", command)
    if m and cls == SOFT and not unattended:
        declared = m.group(1).strip()
        try:
            import time
            d = (os.environ.get("CLAUDE_SAFETY_LOG_DIR") or os.environ.get("CLAUDE_PLUGIN_DATA")
                 or os.path.expanduser("~/.local/state/claude-safety"))
            os.makedirs(d, exist_ok=True)
            subject = re.sub(r"(?i)(token|key|secret|passw(or)?d|auth)[=: ]+\S+", r"\1=[redacted]",
                             command)[:120]
            with open(os.path.join(d, "ledger.jsonl"), "a", encoding="utf-8") as fh:
                fh.write(json.dumps({
                    "ts": time.strftime("%Y-%m-%dT%H:%M:%S%z"), "guard": GUARD,
                    "verdict": "override", "class": cls, "reason": reason,
                    "declared": declared[:200], "subject": subject,
                }, ensure_ascii=False) + "\n")
        except Exception:
            pass
        sys.stderr.write("%s: override accepted for: %s. Declared reason: %s\n"
                         % (GUARD, reason, declared))
        sys.exit(0)

    msg = ["BLOCKED by %s [%s]: %s." % (GUARD, cls, reason), REMEDY.get(cls, REMEDY["PROTECTED"])]
    if cls == SOFT and unattended:
        msg.append("This session is unattended, so the override is refused: leave it for a person.")
    elif cls != SOFT:
        msg.append("This is a hard floor: no override exists.")
    sys.stderr.write("\n".join(msg) + "\n")
    sys.exit(2)


main()
PY
