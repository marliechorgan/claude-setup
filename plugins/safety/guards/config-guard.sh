#!/bin/bash
# config-guard.sh: PreToolUse guard for Write, Edit, MultiEdit, NotebookEdit and Bash that stops
# an agent rewriting its own rules or writing secret files.
#
# An agent that can edit its settings, hooks, skills or CLAUDE.md can switch off every other
# control, and one that can edit a shell start-up file or a git hook gets code run later, as
# the user, outside any session. Secret files (.env, private keys, token stores) hold values an
# agent should never author. So this guard refuses a write whose resolved target is:
#
#   CONTROL   a path in the `control_files` config list, or anything under one. An absolute
#             entry (~/.claude/hooks) means that path; a relative entry (.claude/settings.json,
#             .git/hooks) means that path inside any project, at any depth.
#   SECRET    a file whose name matches `secret_patterns` (.env, *.pem, id_rsa*, ...). Public
#             keys and templates (*.pub, .env.example, .env.sample, .env.template) are not secret.
#
# The Bash half judges where a write lands, not what the text mentions. It follows cd and
# pushd, simple variable assignments, ~ and $HOME, ../, symlinks already on disk and links
# made earlier in the same command, and it looks inside $(...), backticks, bash -c, eval,
# xargs, find -exec, heredocs fed to a shell, and scripts written then run in one command.
# Write shapes: redirections, tee, sed -i, perl/ruby -i, cp/mv/install/ln/rsync/ditto onto,
# mv of a control file away, dd of=, truncate, curl -o, wget -O, tar/unzip extracting into a
# control folder, and python/node/perl/ruby inline code that writes a protected path.
# Reading a control or secret file is not this guard's concern.
#
# A target the guard cannot resolve fails open, unless its visible part already names a
# protected file (for example "$DIR/.claude/settings.json"). A relative entry does not
# protect a throwaway copy under a temp folder outside the session folder.
# Known limits: a write made by a script file the agent runs is invisible unless a control
# path is passed to it as an argument; a path assembled at run time evades any text reader.
#
# Override (Bash only, secret files only): CLAUDE_GUARD_OVERRIDE='<reason>' <command>, refused when
# unattended. Never accepted for control files: the agent writes the command, so an override there
# would let it rewrite its own guards. Those changes are for the person to make by hand.
# Contract: see ../CONTRACT.md. Exit 0 allow, exit 2 block with a message on stderr.

CFG="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/../lib/safety-config.py"
HOOK_INPUT="$(cat)"
CWD_HINT="$(printf '%s' "$HOOK_INPUT" | python3 -I -S -c 'import sys,json
try:
    d=json.load(sys.stdin); c=d.get("cwd") if isinstance(d,dict) else ""
    sys.stdout.write(c if isinstance(c,str) else "")
except Exception:
    pass' 2>/dev/null)"
[ -n "$CWD_HINT" ] || CWD_HINT="$PWD"
CONTROL=""
SECRETS=""
if [ -f "$CFG" ]; then
  CONTROL="$(python3 -I -S "$CFG" get control_files "$CWD_HINT" 2>/dev/null)"
  SECRETS="$(python3 -I -S "$CFG" get secret_patterns "$CWD_HINT" 2>/dev/null)"
fi

# The payload goes on fd 3 so a large command never hits the argument-size limit;
# the program comes on stdin.
CG_CONTROL="$CONTROL" CG_SECRETS="$SECRETS" python3 -I -S - 3< <(printf '%s' "$HOOK_INPUT") <<'PY'
import ast, fnmatch, json, os, re, sys, tempfile, time

def allow():
    sys.exit(0)

try:
    data = json.loads(os.fdopen(3, encoding="utf-8", errors="replace").read())
    if not isinstance(data, dict):
        allow()
except Exception:
    allow()

UNATTENDED = os.environ.get("CLAUDE_SAFETY_UNATTENDED") == "1"
HOME = os.path.expanduser("~")
SESSION_CWD = data.get("cwd") if isinstance(data.get("cwd"), str) and data.get("cwd") else os.getcwd()
SESSION_CWD = os.path.normpath(os.path.expanduser(SESSION_CWD))
TEMP_ROOTS = []
for t in (tempfile.gettempdir(), os.environ.get("TMPDIR") or "", "/tmp", "/private/tmp", "/var/folders",
          "/private/var/folders"):
    if t:
        for v in (os.path.normpath(t), os.path.realpath(t)):
            if v not in TEMP_ROOTS and v != "/":
                TEMP_ROOTS.append(v)
MKTEMP_BASE = os.path.join(os.path.realpath(tempfile.gettempdir()), "config-guard-mktemp")


def lines(name):
    return [x.strip() for x in (os.environ.get(name) or "").splitlines() if x.strip()]


# ---------------------------------------------------------------- what is protected
CTRL_ABS, CTRL_REL = [], []
for e in lines("CG_CONTROL"):
    e = e.rstrip("/") or e
    if e.startswith("/"):
        for v in (os.path.normpath(e), os.path.realpath(e)):
            if v.lower() not in [x.lower() for x in CTRL_ABS]:
                CTRL_ABS.append(v)
    else:
        e = e[2:] if e.startswith("./") else e
        if e:
            CTRL_REL.append(e)
SECRET_PATS = lines("CG_SECRETS")
NOT_SECRET = re.compile(r"\.(pub|example|sample|template|dist)\Z", re.I)


def fold(p):
    return p.lower()


def under(p, root):
    p, root = fold(p), fold(root)
    return p == root or p.startswith(root.rstrip("/") + "/")


def in_temp(p):
    return any(under(p, t) for t in TEMP_ROOTS)


def rel_hit(p):
    s = "/" + fold(p).strip("/")
    for e in CTRL_REL:
        f = "/" + fold(e).strip("/")
        if s.endswith(f) or (f + "/") in s:
            # a throwaway repo or copy in temp, outside the session folder, protects nothing
            if in_temp(p) and not under(p, SESSION_CWD) and not under(p, os.path.realpath(SESSION_CWD)):
                return None
            return e
    return None


def secret_hit(p):
    base = os.path.basename(p.rstrip("/"))
    if not base or NOT_SECRET.search(base):
        return None
    for pat in SECRET_PATS:
        if "/" in pat:
            if fnmatch.fnmatch(fold(p), fold("*/" + pat.lstrip("/"))):
                return pat
        elif fnmatch.fnmatch(fold(base), fold(pat)):
            return pat
    return None


def classify(path):
    # ("CONTROL"|"SECRET", why) for one absolute, normalised path, or None.
    for root in CTRL_ABS:
        if under(path, root):
            return ("CONTROL", "inside the control folder " + root if fold(path) != fold(root)
                    else "a control file")
    e = rel_hit(path)
    if e:
        return ("CONTROL", "a project's " + e)
    pat = secret_hit(path)
    if pat:
        return ("SECRET", "the name matches the secret pattern " + pat)
    return None


LINKS = {}   # links made earlier in the same command: link path -> target


def variants(path, follow=True):
    path = os.path.normpath(path)
    out = [path]
    cur = path
    for _ in range(8):
        if cur in LINKS:
            cur = LINKS[cur]
            out.append(cur)
        else:
            break
    try:
        out.append(os.path.realpath(path) if follow else
                   os.path.join(os.path.realpath(os.path.dirname(path)), os.path.basename(path)))
        out.append(os.path.join(os.path.realpath(os.path.dirname(path)), os.path.basename(path)))
    except Exception:
        pass
    return out


def judge_abs(path, follow=True):
    for v in variants(path, follow):
        c = classify(v)
        if c:
            return c, v
    return None


def tail_hit(text):
    # A target with an unresolved expansion: judge the visible tail after the last one.
    m = re.split(r"\$\{[^}]*\}|\$\w+|\$\(|`", text)
    tail = m[-1] if m else text
    if not tail or tail == text:
        return None
    t = "/" + tail.strip("\"'").lstrip("/")
    t = os.path.normpath(t)
    s = fold(t)
    for e in CTRL_REL:
        f = "/" + fold(e).strip("/")
        if s.endswith(f) or (f + "/") in s:
            return ("CONTROL", "its visible part names a project's " + e), t
    for root in CTRL_ABS:
        parts = [x for x in fold(root).split("/") if x]
        last = parts[-1] if parts else ""
        two = "/" + "/".join(parts[-2:]) if len(parts) >= 2 else ""
        if last.startswith(".") and (s.endswith("/" + last) or ("/" + last + "/") in s):
            return ("CONTROL", "its visible part names " + root), t
        if two and last and not parts[-2] == fold(os.path.basename(HOME)) and (s.endswith(two) or (two + "/") in s):
            return ("CONTROL", "its visible part names " + root), t
    pat = secret_hit(t)
    if pat:
        return ("SECRET", "its name matches the secret pattern " + pat), t
    return None


# ---------------------------------------------------------------- Write / Edit / NotebookEdit
tool = data.get("tool_name") or ""
ti = data.get("tool_input") if isinstance(data.get("tool_input"), dict) else {}

HINTS = {
    "CONTROL": "leave the agent's own settings, hooks, skills, instructions, shell start-up files, "
               "SSH config and git hooks to the user: show them the exact change you want made and let "
               "them apply it themselves",
    "SECRET": "do not author secret files; write a template instead (for example .env.example with "
              "placeholder values) and tell the user which values to fill in themselves",
}


def block(findings, what, override_refused=False, override_control=False):
    codes = sorted({c for c, _, _ in findings})
    detail = "; ".join("%s (%s)" % (p, why) for _, why, p in findings[:4])
    msg = ["BLOCKED by config-guard [%s]: %s would write %s." % ("/".join(codes), what, detail)]
    if override_control:
        msg.append("CLAUDE_GUARD_OVERRIDE is never accepted for the agent's own settings, hooks or instructions: the person makes those changes by hand.")
    if override_refused:
        msg.append("The CLAUDE_GUARD_OVERRIDE prefix was refused: this is an unattended run, so nobody is present to mean it.")
    tail = "; ".join(HINTS[c] for c in codes)
    if tool == "Bash" and not UNATTENDED and "CONTROL" not in codes:
        tail += ". If the user explicitly agrees this one command is fine, rerun it as: CLAUDE_GUARD_OVERRIDE='<reason>' <the same command>"
    msg.append("DO THIS INSTEAD: " + tail + ".")
    sys.stderr.write("\n".join(msg) + "\n")
    sys.exit(2)


if tool in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
    try:
        p = ti.get("file_path") or ti.get("notebook_path") or ""
        if not isinstance(p, str) or not p:
            allow()
        p = os.path.expanduser(p)
        if not p.startswith("/"):
            p = os.path.join(SESSION_CWD, p)
        r = judge_abs(p)
    except Exception:
        allow()
    if r:
        (cls, why), v = r
        block([(cls, why, v)], "this %s call" % tool)
    allow()

if tool != "Bash":
    allow()

cmd = ti.get("command") or ""
if not isinstance(cmd, str) or not cmd.strip():
    allow()


# ---------------------------------------------------------------- a small shell reader
OPS = ("&&", "||", ";;", "|&", ";", "&", "|", "\n", "(", ")")
REDIR = re.compile(r"(\d*|&)(>>|>\||>&|>|<<<|<<-|<<|<>|<&|<)")


class Word(object):
    __slots__ = ("text", "raw", "subs", "quoted")

    def __init__(self):
        self.text, self.raw, self.subs, self.quoted = "", "", [], False


def read_subst(s, i, open_, close):
    # index just past the matching close of $( or ( starting after the opener at i
    depth, single, double = 1, False, False
    while i < len(s):
        ch = s[i]
        if ch == "\\" and not single:
            i += 2
            continue
        if ch == "'" and not double:
            single = not single
        elif ch == '"' and not single:
            double = not double
        elif not single and not double:
            if ch == open_:
                depth += 1
            elif ch == close:
                depth -= 1
                if depth == 0:
                    return i + 1
        i += 1
    return -1


def tokenize(s):
    # -> list of ("W", Word) | ("OP", op) | ("R", redir-op, fd) ; raises ValueError when unsure
    toks, i, n = [], 0, len(s)
    while i < n:
        ch = s[i]
        if ch in " \t":
            i += 1
            continue
        if ch == "\\" and s[i:i + 2] == "\\\n":
            i += 2
            continue
        if ch == "#" and (i == 0 or s[i - 1] in " \t\n;&|()"):
            while i < n and s[i] != "\n":
                i += 1
            continue
        m = REDIR.match(s, i)
        if m and (m.group(1) == "" or i == 0 or s[i - 1] in " \t\n;&|()"):
            if not (m.group(2) == "<" and s[m.end():m.end() + 1] == "("):
                toks.append(("R", m.group(2), m.group(1)))
                i = m.end()
                continue
        if s.startswith(("<(", ">("), i):
            j = read_subst(s, i + 2, "(", ")")
            if j < 0:
                raise ValueError("open process substitution")
            w = Word()
            w.raw = s[i:j]
            w.subs.append(s[i + 2:j - 1])
            w.text = "\0procsub"
            toks.append(("W", w))
            i = j
            continue
        op = next((o for o in OPS if s.startswith(o, i)), None)
        if op:
            toks.append(("OP", op))
            i += len(op)
            continue
        w, start = Word(), i
        while i < n:
            ch = s[i]
            if ch in " \t\n;&|()<>":
                break
            if ch == "\\":
                if i + 1 < n and s[i + 1] != "\n":
                    w.text += s[i + 1]
                i += 2
                continue
            if ch == "'":
                j = s.find("'", i + 1)
                if j < 0:
                    raise ValueError("open quote")
                w.text += s[i + 1:j]
                w.quoted = True
                i = j + 1
                continue
            if ch == "$" and s[i + 1:i + 2] == "'":
                j = i + 2
                buf = ""
                while j < n and s[j] != "'":
                    if s[j] == "\\" and j + 1 < n:
                        buf += {"n": "\n", "t": "\t"}.get(s[j + 1], s[j + 1])
                        j += 2
                        continue
                    buf += s[j]
                    j += 1
                if j >= n:
                    raise ValueError("open quote")
                w.text += buf
                w.quoted = True
                i = j + 1
                continue
            if ch == '"':
                j = i + 1
                while j < n and s[j] != '"':
                    if s[j] == "\\" and j + 1 < n:
                        if s[j + 1] in '$`"\\':
                            w.text += s[j + 1]
                        elif s[j + 1] != "\n":
                            w.text += s[j:j + 2]
                        j += 2
                        continue
                    if s.startswith("$(", j):
                        k = read_subst(s, j + 2, "(", ")")
                        if k < 0:
                            raise ValueError("open substitution")
                        w.subs.append(s[j + 2:k - 1])
                        w.text += s[j:k]
                        j = k
                        continue
                    if s[j] == "`":
                        k = s.find("`", j + 1)
                        if k < 0:
                            raise ValueError("open backtick")
                        w.subs.append(s[j + 1:k])
                        w.text += s[j:k + 1]
                        j = k + 1
                        continue
                    w.text += s[j]
                    j += 1
                if j >= n:
                    raise ValueError("open quote")
                w.quoted = True
                i = j + 1
                continue
            if s.startswith("$(", i):
                k = read_subst(s, i + 2, "(", ")")
                if k < 0:
                    raise ValueError("open substitution")
                w.subs.append(s[i + 2:k - 1])
                w.text += s[i:k]
                i = k
                continue
            if ch == "`":
                k = s.find("`", i + 1)
                if k < 0:
                    raise ValueError("open backtick")
                w.subs.append(s[i + 1:k])
                w.text += s[i:k + 1]
                i = k + 1
                continue
            w.text += ch
            i += 1
        w.raw = s[start:i]
        toks.append(("W", w))
    return toks


def split_heredocs(s):
    # Pull heredoc bodies out of the text. Returns (shell text without bodies, [bodies in order]).
    out, bodies, lines_ = [], [], s.split("\n")
    k = 0
    while k < len(lines_):
        line = lines_[k]
        out.append(line)
        k += 1
        pend = []
        for m in re.finditer(r"<<(-?)[ \t]*(['\"]?)\\?([A-Za-z_][\w.-]*)\2", line):
            if line[m.start():m.start() + 3] == "<<<":
                continue
            pend.append((m.group(1) == "-", m.group(3), bool(m.group(2))))
        for strip, delim, quoted in pend:
            body = []
            while k < len(lines_):
                b = lines_[k]
                k += 1
                if (b.lstrip("\t") if strip else b) == delim:
                    break
                body.append(b)
            bodies.append(("\n".join(body), quoted))
    return "\n".join(out), bodies


# ---------------------------------------------------------------- statement model
WRAPPERS = {"sudo", "doas", "command", "builtin", "exec", "nohup", "nice", "time", "stdbuf", "caffeinate",
            "unbuffer", "timeout", "gtimeout", "chronic", "ionice", "setsid", "then", "do", "else", "elif",
            "if", "while", "until", "!", "{", "}"}
SHELLS = {"sh", "bash", "zsh", "dash", "ksh", "fish"}
PYTHONS = re.compile(r"python[\d.]*\Z|pypy[\d.]*\Z")
COPIERS = {"cp", "gcp", "install", "ginstall", "ln", "gln", "mv", "gmv", "rsync", "ditto"}


def var_value(text, env):
    # Expand $NAME, ${NAME}, ~ and $HOME in an unquoted-shaped word; None when anything stays unknown.
    t = text
    if t.startswith("~") and (len(t) == 1 or t[1] == "/"):
        t = HOME + t[1:]

    def sub(m):
        name = m.group(1) or m.group(2)
        if name in env:
            return env[name]
        if name == "HOME":
            return HOME
        if name == "PWD":
            return env.get("\0cwd", SESSION_CWD)
        if name == "TMPDIR":
            return os.environ.get("TMPDIR") or tempfile.gettempdir()
        raise KeyError(name)

    try:
        t = re.sub(r"\$\{(\w+)\}|\$(\w+)", sub, t)
        t = re.sub(r"\$\{(\w+):-[^}]*\}", sub, t)
    except KeyError:
        return None
    if "$" in t or "`" in t or "\0" in t:
        return None
    return t


class Ctx(object):
    def __init__(self, cwds, env, written=None):
        self.cwds = list(cwds)
        self.env = dict(env)
        self.written = {} if written is None else written   # file written from a heredoc body -> body
        self.pending_cd = None

    def child(self):
        # a subshell: sees the parent's cwd and variables, and its cd does not leak back
        return Ctx(self.cwds, self.env, self.written)


FINDINGS = []


def note(r, verb):
    if r:
        (cls, why), p = r
        FINDINGS.append((cls, why, p, verb))


def judge_word(w, ctx, verb, follow=True):
    text = w.text if isinstance(w, Word) else w
    if not text or text.startswith("\0") or text in ("-", "/dev/null", "/dev/stdout", "/dev/stderr", "/dev/tty"):
        return
    v = var_value(text, ctx.env)
    if v is None:
        r = tail_hit(text)
        if not r:
            # the part before the first unknown expansion may already sit inside a control folder
            head = re.split(r"\$|`", text, 1)[0]
            if "/" in head:
                hv = var_value(head[:head.rfind("/")] or "/", ctx.env)
                if hv:
                    for d in ([hv] if hv.startswith("/") else [os.path.join(c, hv) for c in ctx.cwds or [SESSION_CWD]]):
                        for dv in variants(d):
                            c = classify(dv)
                            if c and c[0] == "CONTROL" and any(under(dv, root) for root in CTRL_ABS):
                                r = (c, os.path.join(dv, "..."))
                                break
                        if r:
                            break
        note(r, verb)
        return
    if v.startswith("/"):
        note(judge_abs(v, follow), verb)
        return
    for c in ctx.cwds or [SESSION_CWD]:
        r = judge_abs(os.path.join(c, v), follow)
        if r:
            note(r, verb)
            return


def resolve(w, ctx):
    text = w.text if isinstance(w, Word) else w
    v = var_value(text, ctx.env)
    if v is None:
        return []
    if v.startswith("/"):
        return [os.path.normpath(v)]
    return [os.path.normpath(os.path.join(c, v)) for c in (ctx.cwds or [SESSION_CWD])]


def operands(args, with_value=()):
    out, skip = [], False
    for a in args:
        if skip:
            skip = False
            continue
        if a.text in with_value:
            skip = True
            continue
        if a.text == "--":
            continue
        if a.text.startswith("-") and len(a.text) > 1 and not a.quoted:
            continue
        out.append(a)
    return out


def judge_copy(verb, args, ctx):
    base = re.sub(r"^g(?=cp|mv|ln|install)", "", verb)
    target_dir = None
    for k, a in enumerate(args):
        if a.text in ("-t", "--target-directory") and k + 1 < len(args):
            target_dir = args[k + 1]
        elif a.text.startswith("--target-directory="):
            target_dir = Word()
            target_dir.text = a.text.split("=", 1)[1]
    with_value = {"-t", "--target-directory", "-m", "--mode", "-o", "--owner", "-g", "--group", "-S",
                  "--suffix", "-e", "--rsh", "--exclude", "--include", "--filter", "-f", "--backup-dir"}
    if base == "ln" or base == "cp" or base == "mv":
        with_value = {"-t", "--target-directory", "-S", "--suffix"}
    ops = operands(args, with_value)
    if base == "mv":
        # moving a control file away switches it off as surely as rewriting it
        srcs = ops if target_dir else ops[:-1]
        for s in srcs:
            for p in resolve(s, ctx):
                r = judge_abs(p, False)
                if r and r[0][0] == "CONTROL":
                    note(r, "mv (moving it away)")
    if target_dir is not None:
        dest, srcs = target_dir, ops
    elif len(ops) >= 2:
        dest, srcs = ops[-1], ops[:-1]
    else:
        return
    if base == "rsync" and re.match(r"[^/]*:", dest.text):
        return
    follow = base not in ("ln", "mv", "install")
    judge_word(dest, ctx, verb, follow)
    for d in resolve(dest, ctx):
        if base == "ln" and len(srcs) == 1 and not os.path.isdir(d):
            for sp in resolve(srcs[0], ctx) or []:
                LINKS[d] = sp
        if target_dir is not None or dest.text.endswith("/") or os.path.isdir(d) or len(srcs) > 1:
            for s in srcs:
                name = os.path.basename(s.text.rstrip("/"))
                if base == "rsync" and s.text.endswith("/"):
                    continue
                if name and "$" not in name:
                    note(judge_abs(os.path.join(d, name), follow), verb)


def sed_files(args):
    files, script, skip = [], any(a.text in ("-e", "-f", "--expression", "--file") or
                                  a.text.startswith(("--expression=", "--file=")) for a in args), False
    for k, a in enumerate(args):
        t = a.text
        if skip:
            skip = False
        elif t in ("-e", "-f", "--expression", "--file"):
            skip = True
        elif re.match(r"-[A-Za-z]*i\Z", t) and k + 1 < len(args) and re.match(r"(\.[\w.-]*)?\Z", args[k + 1].text):
            skip = True
        elif t.startswith("-") and len(t) > 1:
            continue
        elif not script:
            script = True
        else:
            files.append(a)
    return files


# Write-capable calls in inline code. A protected path named in code with none of these is a read.
PY_WRITE = re.compile(
    r"open\s*\([^)]*,\s*(?:mode\s*=\s*)?(?:['\"][^'\"]*[waxWAX+]|[A-Za-z_])|\bmode\s*=|write_text|write_bytes|"
    r"\.write\s*\(|writelines|\bdump\s*\(|\bshutil\.|\bos\.(?:rename|replace|symlink|link|truncate|open|system|"
    r"popen|exec\w*|spawn\w*|remove|unlink)\b|\.(?:rename|replace|symlink_to|hardlink_to|touch|unlink)\s*\(|"
    r"\bsubprocess\b|\bexec\s*\(|\beval\s*\(|\bfileinput\b|\bcodecs\.open|\bio\.open|__import__|\bimportlib\b|"
    r"\bprint\s*\([^)]*\bfile\s*=")
OTHER_WRITE = re.compile(
    r"writeFile|appendFile|copyFile|createWriteStream|\brename|symlink|\bcp\b|\bmv\b|File\.(?:write|open|rename)|"
    r"FileUtils|IO\.write|open\s*\(\s*\w*\s*,?\s*['\"]?[>+]|\bsystem\s*\(|\bexec|`|\bspawn|child_process|"
    r"\bunlink|writeSync|\bprint\s*\{|\bopen\s*\(", re.I)
STR_LIT = re.compile(r"'([^'\n]*)'|\"([^\"\n]*)\"")


RUNS_CODE = re.compile(r"\bexec\s*\(|\beval\s*\(|\brunpy\b|\bimportlib\b|__import__|\bcompile\s*\(")


def py_targets(code, argv):
    # (paths the python code writes, shell strings it runs, whether a write target was unresolvable)
    # or None when the code does not parse.
    try:
        tree = ast.parse(code)
    except Exception:
        return None
    argvals = ["-"] + [a.text for a in argv]
    binds, opens = {}, {"open"}

    def val(n, depth=0):
        if depth > 8 or n is None:
            return None
        if isinstance(n, ast.Constant) and isinstance(n.value, str):
            return n.value
        if isinstance(n, ast.Name):
            return binds.get(n.id)
        if isinstance(n, ast.Subscript):
            base = n.value
            idx = n.slice.value if hasattr(n.slice, "value") and not isinstance(n.slice, ast.Constant) else n.slice
            if isinstance(base, ast.Attribute) and base.attr == "argv" and isinstance(idx, ast.Constant) \
                    and isinstance(idx.value, int) and 0 <= idx.value < len(argvals):
                return argvals[idx.value]
            return None
        if isinstance(n, ast.JoinedStr):
            parts = []
            for v in n.values:
                x = str(v.value) if isinstance(v, ast.Constant) else val(getattr(v, "value", None), depth + 1)
                if x is None:
                    return None
                parts.append(x)
            return "".join(parts)
        if isinstance(n, ast.BinOp) and isinstance(n.op, (ast.Add, ast.Div)):
            a, b = val(n.left, depth + 1), val(n.right, depth + 1)
            if a is None or b is None:
                return None
            return a + b if isinstance(n.op, ast.Add) else os.path.join(a, b)
        if isinstance(n, ast.Call):
            f = n.func
            name = f.attr if isinstance(f, ast.Attribute) else f.id if isinstance(f, ast.Name) else ""
            args = [val(a, depth + 1) for a in n.args]
            if name == "join" and args and all(a is not None for a in args) and not (
                    isinstance(f, ast.Attribute) and isinstance(f.value, ast.Constant)):
                return os.path.join(*args)
            if name == "home" and not args:
                return HOME
            if name == "joinpath" and isinstance(f, ast.Attribute):
                b = val(f.value, depth + 1)
                if b is not None and args and all(a is not None for a in args):
                    return os.path.join(b, *args)
            if name in ("Path", "PurePath", "PosixPath", "expanduser", "abspath", "realpath", "normpath",
                        "str", "fspath", "resolve", "absolute", "expandvars"):
                if not args and isinstance(f, ast.Attribute):
                    return val(f.value, depth + 1)
                if len(args) == 1:
                    return args[0]
                if len(args) > 1 and all(a is not None for a in args):
                    return os.path.join(*args)
        return None

    for node in ast.walk(tree):
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
            if isinstance(node.value, ast.Name) and node.value.id in opens:
                opens.add(node.targets[0].id)
                continue
            v = val(node.value)
            if v is not None:
                binds[node.targets[0].id] = v
    targets, shells, unknown, contents = [], [], False, {}

    def add(n):
        nonlocal unknown
        v = val(n)
        if v is None:
            unknown = True
        else:
            targets.append(v)

    def write_mode(call, pos):
        m = call.args[pos] if len(call.args) > pos else next((k.value for k in call.keywords if k.arg == "mode"), None)
        if m is None:
            return False
        mv = val(m)
        return mv is None or bool(re.search(r"[waxWAX+]", mv))

    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        f = node.func
        if isinstance(f, ast.Attribute) and f.attr in ("write", "write_text") and node.args:
            body = val(node.args[0])
            inner = f.value
            if body is not None and isinstance(inner, ast.Call) and inner.args:
                path = val(inner.args[0])
                if path is not None:
                    contents[path] = body
            elif body is not None and f.attr == "write_text":
                path = val(inner)
                if path is not None:
                    contents[path] = body
        name = f.attr if isinstance(f, ast.Attribute) else f.id if isinstance(f, ast.Name) else ""
        owner = f.value.id if isinstance(f, ast.Attribute) and isinstance(f.value, ast.Name) else ""
        a = node.args
        if isinstance(f, ast.Name) and name in opens and a:
            if write_mode(node, 1):
                add(a[0])
        elif name == "open" and owner in ("io", "codecs") and a:
            if write_mode(node, 1):
                add(a[0])
        elif name == "open" and owner == "os" and a:
            if len(a) > 1 and re.search(r"O_(WRONLY|RDWR|CREAT|APPEND|TRUNC)", ast.dump(a[1])):
                add(a[0])
        elif name in ("write_text", "write_bytes", "touch", "symlink_to", "hardlink_to") and isinstance(f, ast.Attribute):
            add(f.value)
        elif name == "open" and isinstance(f, ast.Attribute) and owner not in ("os", "io", "codecs"):
            if write_mode(node, 0):
                add(f.value)
        elif name in ("rename", "replace") and isinstance(f, ast.Attribute) and owner != "os" and a:
            if not isinstance(f.value, ast.Constant):
                add(a[0])
                add(f.value)
        elif owner == "shutil" and name in ("copy", "copy2", "copyfile", "copytree", "move", "copyfileobj") and len(a) >= 2:
            if name != "copyfileobj":
                add(a[1])
            if name == "move":
                add(a[0])
        elif owner == "os" and name in ("rename", "replace", "renames", "symlink", "link") and len(a) >= 2:
            add(a[1])
            if name in ("rename", "replace", "renames"):
                add(a[0])
        elif owner == "os" and name in ("truncate",) and a:
            add(a[0])
        elif (owner == "os" and name in ("system", "popen")) or owner == "subprocess" or name in ("check_output", "check_call", "Popen"):
            if a:
                x = a[0]
                if isinstance(x, (ast.List, ast.Tuple)):
                    parts = [val(e) for e in x.elts]
                    if all(p is not None for p in parts):
                        if len(parts) >= 3 and os.path.basename(parts[0]) in SHELLS and parts[1] == "-c":
                            shells.append(parts[2])
                        else:
                            shells.append(" ".join("'" + p.replace("'", "'\\''") + "'" for p in parts))
                    else:
                        unknown = True
                else:
                    v = val(x)
                    if v is None:
                        unknown = True
                    else:
                        shells.append(v)
    return targets, shells, unknown, contents


def judge_code(lang, code, argv, ctx, verb):
    if lang == "python":
        r = py_targets(code, argv)
        if r is not None:
            targets, shells, _unresolved, contents = r    # an unresolvable target fails open, by contract
            for t, body in contents.items():
                for p in resolve(t, ctx):
                    ctx.written[p] = body
            for t in targets:
                w = Word()
                w.text = t
                judge_word(w, ctx, verb)
            for s in shells:
                scan(s, ctx.child(), 1)
            # code that runs other code, handed a control file: judged like an unseen script
            if RUNS_CODE.search(code):
                for a in argv:
                    before = len(FINDINGS)
                    judge_word(a, ctx, verb)
                    if len(FINDINGS) > before and FINDINGS[-1][0] != "CONTROL":
                        FINDINGS.pop()
            return
        strs = {a or b for a, b in STR_LIT.findall(code)}
        writes = PY_WRITE.search(code)
        uses_argv = "argv" in code
    else:
        strs = {a or b for a, b in STR_LIT.findall(code)}
        writes = OTHER_WRITE.search(code)
        uses_argv = bool(re.search(r"argv|ARGV|\$ARGV|process\.argv|@ARGV", code))
    if not writes:
        return
    strs = {re.sub(r"^[+<>|\s]+", "", x) for x in strs}      # perl's two-argument open glues the mode on
    cands = [s for s in strs if "/" in s or s.startswith(".") or s.startswith("~")]
    if uses_argv:
        cands += [a.text for a in argv]
    for s in cands:
        if len(s) > 4096 or "\n" in s:
            continue
        before = len(FINDINGS)
        w = Word()
        w.text = s
        judge_word(w, ctx, verb)
        if len(FINDINGS) > before:
            return
    # a shell command carried inside the code (os.system, subprocess with a string)
    if re.search(r"system|subprocess|popen|exec|spawn|`", code):
        for s in strs:
            if s and re.search(r"\s", s):
                scan(s, ctx.child(), depth=1)


def interp_args(words):
    # For python/node/perl/ruby: (inline code or None, script word or None, argv after it, is -m)
    code, script, argv, k = None, None, [], 0
    while k < len(words):
        t = words[k].text
        if code is None and script is None:
            if t in ("-c", "-e", "-E", "--eval", "-p", "--print") and k + 1 < len(words):
                code = words[k + 1].text
                k += 2
                continue
            if re.match(r"-[A-Za-z]*[ceE]\Z", t) and k + 1 < len(words) and not t.startswith("--"):
                code = words[k + 1].text
                k += 2
                continue
            if t == "-m":
                return None, None, words[k + 1:], True
            if t == "-":
                script = "-"
                k += 1
                continue
            if t.startswith("-"):
                if t in ("-W", "-X", "-r", "--require", "-I") and k + 1 < len(words):
                    k += 1
                k += 1
                continue
            script = words[k]
            k += 1
            continue
        argv.append(words[k])
        k += 1
    return code, script, argv, False


def run_statement(words, redirs, ctx, stdin_body, piped_text, depth):
    # judge one simple command; words is a list of Word, redirs a list of (op, fd, Word)
    for op, fd, tw in redirs:
        if op in (">", ">>", ">|", "<>") or (op == ">&" and fd == "&"):
            if op == ">&" and re.match(r"-?\d*-?\Z", tw.text):
                continue
            judge_word(tw, ctx, "a redirection")
    for w in words:
        for sub in w.subs:
            scan(sub, ctx.child(), depth + 1)
    for op, fd, tw in redirs:
        for sub in tw.subs:
            scan(sub, ctx.child(), depth + 1)
    # strip assignments, wrappers and their options
    k, assigns = 0, []
    while k < len(words):
        t = words[k].text
        if re.match(r"[A-Za-z_]\w*\+?=", t) and not words[k].raw.startswith(("'", '"')):
            assigns.append(words[k])
            k += 1
            continue
        name = os.path.basename(t)
        if name in WRAPPERS:
            k += 1
            if name in ("timeout", "gtimeout") and k < len(words) and not words[k].text.startswith("-"):
                k += 1
            while k < len(words) and words[k].text.startswith("-"):
                if words[k].text in ("-u", "-g", "-n", "-p", "-C", "-k", "-s", "-o", "-e", "-i") and name in ("sudo", "doas", "nice", "stdbuf", "ionice", "timeout", "gtimeout"):
                    k += 1
                k += 1
            continue
        if name == "env":
            k += 1
            while k < len(words) and (words[k].text.startswith("-") or re.match(r"[A-Za-z_]\w*=", words[k].text)):
                if words[k].text in ("-u", "--unset", "-C", "--chdir", "-S") and k + 1 < len(words):
                    k += 1
                k += 1
            continue
        break
    rest = words[k:]
    if not rest:
        for a in assigns:
            n, v = a.text.split("=", 1)
            if a.subs and re.match(r"\s*(command\s+)?(/usr/bin/)?mktemp\b", a.subs[0]):
                ctx.env[n] = os.path.join(MKTEMP_BASE, n)
                continue
            val = var_value(v, ctx.env) if not a.subs else None
            if val is None:
                ctx.env.pop(n, None)
            else:
                ctx.env[n] = val
        return
    head = rest[0]
    verb = os.path.basename(head.text)
    args = rest[1:]

    if verb in ("export", "declare", "typeset", "local", "readonly"):
        for a in args:
            if "=" in a.text and not a.text.startswith("-"):
                n, v = a.text.split("=", 1)
                val = var_value(v, ctx.env) if not a.subs else None
                if a.subs and re.match(r"\s*(command\s+)?(/usr/bin/)?mktemp\b", a.subs[0]):
                    ctx.env[n] = os.path.join(MKTEMP_BASE, n)
                elif val is None:
                    ctx.env.pop(n, None)
                else:
                    ctx.env[n] = val
        return
    if verb in ("cd", "pushd"):
        ops = [a for a in args if not a.text.startswith("-") or a.text == "-"]
        if not ops:
            ctx.cwds = [HOME] if verb == "cd" else ctx.cwds
            return
        d = ops[0]
        if d.subs and re.match(r"\s*(command\s+)?(/usr/bin/)?mktemp\b", d.subs[0]):
            ctx.cwds = [MKTEMP_BASE]
            return
        v = var_value(d.text, ctx.env)
        if v is None or v == "-":
            ctx.cwds = []       # unknown: relative targets fall back to their visible text
            return
        new = [os.path.normpath(v)] if v.startswith("/") else [os.path.normpath(os.path.join(c, v)) for c in ctx.cwds or [SESSION_CWD]]
        ctx.pending_cd = new
        return
    if verb == "popd":
        ctx.cwds = []
        return

    if verb == "tee":
        for a in args:
            if not a.text.startswith("-"):
                judge_word(a, ctx, "tee")
        if stdin_body is not None:
            for a in args:
                if not a.text.startswith("-"):
                    for p in resolve(a, ctx):
                        ctx.written[p] = stdin_body
        return
    if verb in ("cat",) and stdin_body is not None:
        for op, fd, tw in redirs:
            if op in (">", ">>", ">|"):
                for p in resolve(tw, ctx):
                    ctx.written[p] = stdin_body
        return
    if verb in ("sed", "gsed") and any(re.match(r"-[A-Za-z]*i|--in-place", a.text) for a in args):
        for f in sed_files(args):
            judge_word(f, ctx, "sed -i")
        return
    if verb in ("perl", "ruby") and any(re.match(r"-[a-zA-Z0-9]*i", a.text) and not a.text.startswith("--") for a in args):
        files, code_seen, skip = [], False, False
        for a in args:
            if skip:
                skip = False
            elif a.text.startswith("-"):
                if re.match(r"-[a-zA-Z0-9]*[eE]\Z", a.text):
                    skip = code_seen = True
            elif not code_seen:
                code_seen = True
            else:
                files.append(a)
        for f in files:
            judge_word(f, ctx, verb + " -i")
        return
    if verb in COPIERS:
        judge_copy(verb, args, ctx)
        return
    if verb == "dd":
        for a in args:
            if a.text.startswith("of="):
                w = Word()
                w.text = a.text[3:]
                judge_word(w, ctx, "dd of=")
        return
    if verb == "truncate":
        for a in operands(args, {"-s", "--size", "-r", "--reference"}):
            judge_word(a, ctx, "truncate")
        return
    if verb in ("curl", "wget"):
        flags = ("-o", "--output") if verb == "curl" else ("-O", "--output-document")
        for k2, a in enumerate(args):
            if a.text in flags and k2 + 1 < len(args):
                judge_word(args[k2 + 1], ctx, verb)
            elif a.text.startswith(flags[1] + "="):
                w = Word()
                w.text = a.text.split("=", 1)[1]
                judge_word(w, ctx, verb)
        return
    if verb in ("tar", "gtar", "bsdtar", "unzip", "ditto"):
        dest = None
        for k2, a in enumerate(args):
            if a.text in ("-C", "--directory", "-d") and k2 + 1 < len(args):
                dest = args[k2 + 1]
            elif a.text.startswith("--directory="):
                dest = Word()
                dest.text = a.text.split("=", 1)[1]
        extracting = verb == "unzip" or any(re.match(r"-?[A-Za-z]*x", a.text) or a.text == "--extract" for a in args[:2])
        if dest is not None and extracting:
            for p in resolve(dest, ctx):
                r = judge_abs(p)
                if r and r[0][0] == "CONTROL":
                    note(r, verb + " (extracting into it)")
        return
    if verb == "xargs":
        k2 = 0
        while k2 < len(args) and args[k2].text.startswith("-"):
            if args[k2].text in ("-I", "-n", "-P", "-L", "-s", "-d", "-E", "-a") and k2 + 1 < len(args):
                k2 += 1
            k2 += 1
        run_statement(args[k2:], [], ctx, None, None, depth + 1)
        return
    if verb == "find":
        k2 = 0
        while k2 < len(args):
            if args[k2].text in ("-exec", "-execdir", "-ok", "-okdir"):
                j = k2 + 1
                while j < len(args) and args[j].text not in (";", "+"):
                    j += 1
                run_statement(args[k2 + 1:j], [], ctx, None, None, depth + 1)
                k2 = j
            k2 += 1
        return
    if verb in SHELLS or verb in ("eval", "source", "."):
        if verb == "eval":
            scan(" ".join(a.text for a in args), ctx, depth + 1)
            return
        c = None
        for k2, a in enumerate(args):
            if re.match(r"-[A-Za-z]*c[A-Za-z]*\Z", a.text) and k2 + 1 < len(args):
                c = args[k2 + 1].text
                break
        if c is not None:
            scan(c, ctx.child(), depth + 1)
            return
        ops = [a for a in args if not a.text.startswith("-")]
        if ops and verb not in ("fish",):
            for p in resolve(ops[0], ctx):
                if p in ctx.written:
                    scan(ctx.written[p], ctx.child(), depth + 1)
            return
        if stdin_body is not None:
            scan(stdin_body, ctx.child(), depth + 1)
        if piped_text:
            for t in piped_text:
                scan(t, ctx.child(), depth + 1)
        return
    if verb.startswith("./") or head.text.startswith(("./", "/")) and not os.path.basename(head.text) in COPIERS:
        for p in resolve(head, ctx):
            if p in ctx.written:
                scan(ctx.written[p], ctx.child(), depth + 1)
    lang = ("python" if PYTHONS.match(verb) else "node" if verb in ("node", "nodejs", "deno", "bun")
            else "perl" if verb == "perl" else "ruby" if verb == "ruby" else None)
    if lang:
        code, script, argv, is_mod = interp_args(args)
        if is_mod:
            return
        if code is not None:
            judge_code(lang, code, argv, ctx, verb + " inline code")
            return
        if script == "-" or (script is None and stdin_body is not None):
            if stdin_body is not None:
                judge_code(lang, stdin_body, argv, ctx, verb + " code on stdin")
            return
        if script is not None:
            body = None
            for p in resolve(script, ctx):
                body = ctx.written.get(p, body)
            if body is not None:
                judge_code(lang, body, argv, ctx, verb + " " + script.text)
                return
            # a script we cannot see, handed a control file as an argument
            for a in argv:
                if a.text.startswith("-") and "=" not in a.text:
                    continue
                w = a
                if "=" in a.text and a.text.startswith("-"):
                    w = Word()
                    w.text = a.text.split("=", 1)[1]
                before = len(FINDINGS)
                judge_word(w, ctx, verb + " " + os.path.basename(script.text))
                if len(FINDINGS) > before and FINDINGS[-1][0] != "CONTROL":
                    FINDINGS.pop()
        return


def scan(text, ctx, depth=0):
    if depth > 8 or not text:
        return
    shell, bodies = split_heredocs(text)
    toks = tokenize(shell)
    body_iter = iter(bodies)
    stmt_words, redirs, stdin_body = [], [], None
    pipe_text, last_op = None, None
    prev_printed = []

    def flush(op):
        nonlocal stmt_words, redirs, stdin_body, pipe_text, prev_printed
        feed = pipe_text
        if stmt_words or redirs:
            run_statement(stmt_words, redirs, ctx, stdin_body, feed, depth)
        if getattr(ctx, "pending_cd", None) is not None:
            new = ctx.pending_cd
            ctx.pending_cd = None
            # after && the cd is certain; after ; or a newline it is certain only when the folder
            # exists and can be entered, since otherwise a failed cd leaves the old folder in place
            if op == "&&" or all(x.startswith(MKTEMP_BASE) or (os.path.isdir(x) and os.access(x, os.X_OK)) for x in new):
                ctx.cwds = new
            else:
                ctx.cwds = list(dict.fromkeys((ctx.cwds or [SESSION_CWD]) + new))
        if op in ("|", "|&"):
            printed = [w.text for w in stmt_words[1:]] if stmt_words else []
            if stdin_body is not None:
                printed.append(stdin_body)
            pipe_text = printed
        else:
            pipe_text = None
        stmt_words, redirs, stdin_body = [], [], None

    k, saved = 0, []
    while k < len(toks):
        t = toks[k]
        if t[0] == "OP":
            flush(t[1])
            if t[1] == "(":
                saved.append(list(ctx.cwds))     # a subshell's cd does not outlive it
            elif t[1] == ")" and saved:
                ctx.cwds = saved.pop()
            k += 1
            continue
        if t[0] == "R":
            op, fd = t[1], t[2]
            if op in ("<<", "<<-"):
                k += 2   # the delimiter word
                try:
                    body, quoted = next(body_iter)
                except StopIteration:
                    body = None
                stdin_body = body
                continue
            if op == "<<<":
                if k + 1 < len(toks) and toks[k + 1][0] == "W":
                    stdin_body = toks[k + 1][1].text
                    for sub in toks[k + 1][1].subs:
                        scan(sub, ctx.child(), depth + 1)
                k += 2
                continue
            if k + 1 < len(toks) and toks[k + 1][0] == "W":
                redirs.append((op, fd, toks[k + 1][1]))
                k += 2
                continue
            k += 1
            continue
        w = t[1]
        if w.text == "\0procsub":
            for sub in w.subs:
                scan(sub, ctx.child(), depth + 1)
        else:
            stmt_words.append(w)
        k += 1
    flush(None)


# ---------------------------------------------------------------- dispatch
override = None
m = re.match(r"^\s*CLAUDE_GUARD_OVERRIDE=(?:'([^']*)'|\"([^\"]*)\"|(\S+))\s+", cmd)
if m:
    override = next((g for g in m.groups() if g is not None), "").strip()
    cmd = cmd[m.end():]
try:
    ctx = Ctx([SESSION_CWD], {})
    ctx.pending_cd = None
    scan(cmd, ctx)
except RecursionError:
    allow()
except Exception:
    allow()        # a defect in the reader must never break ordinary work

if not FINDINGS:
    allow()

seen, uniq = set(), []
for cls, why, p, verb in FINDINGS:
    if (cls, p) not in seen:
        seen.add((cls, p))
        uniq.append((cls, why, p, verb))

has_control = any(c == "CONTROL" for c, _, _, _ in uniq)
if override and not UNATTENDED and not has_control:
    try:
        logdir = (os.environ.get("CLAUDE_SAFETY_LOG_DIR") or os.environ.get("CLAUDE_PLUGIN_DATA")
                  or os.path.expanduser("~/.local/state/claude-safety"))
        os.makedirs(logdir, exist_ok=True)
        subj = re.sub(r"(?i)((?:token|key|secret|pass(?:word)?|auth[a-z]*)[=: ]+)\S+", r"\1<redacted>", cmd)[:200]
        with open(os.path.join(logdir, "ledger.jsonl"), "a") as f:
            f.write(json.dumps({"ts": time.strftime("%Y-%m-%dT%H:%M:%S%z"), "guard": "config-guard",
                                "action": "override", "class": "/".join(sorted({c for c, _, _, _ in uniq})),
                                "reason": override[:300], "subject": subj}) + "\n")
    except Exception:
        pass
    allow()

verbs = sorted({v for _, _, _, v in uniq})
block([(c, w, p) for c, w, p, _ in uniq], "this command (" + ", ".join(verbs[:3]) + ")",
      override_refused=bool(override and UNATTENDED), override_control=bool(override and has_control))
PY
