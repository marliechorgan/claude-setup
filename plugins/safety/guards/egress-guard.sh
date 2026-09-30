#!/bin/bash
# egress-guard.sh: PreToolUse guard for Bash and WebFetch that stops an agent sending local
# data to a host the user has not approved.
#
# An agent that reads untrusted text (web pages, issues, email) can be talked into shipping
# files or secrets somewhere. Reading the web needs a GET; sending bytes needs a body, an
# upload, a raw socket or a copy to a remote machine. This guard blocks those send shapes
# when the destination is not loopback and not in the `egress_allowed_hosts` config list:
#
#   REQUEST_BODY   curl/wget/httpie carrying a body or upload (-d, --data*, --json, -F, -T,
#                  -X POST|PUT|PATCH, wget --post-*, httpie data items or piped stdin)
#   FILE_IN_ARGS   a command substitution that reads a file or the environment, spliced
#                  into a fetch (a header, a URL), which sends the data even on a GET
#   RAW_SOCKET     nc/ncat/netcat/telnet/openssl s_client fed from a pipe or a file, or
#                  with an exec flag; socat to a remote TCP/UDP address; writes to /dev/tcp
#   REMOTE_COPY    scp/rsync with a remote destination; sftp/ftp/lftp that uploads; ssh
#                  whose stdin is a pipe or a file; aws s3 / gsutil / rclone uploads
#   SCRIPT_SEND    python/node/ruby/perl/php inline code that POSTs or writes a socket
#   DNS_TUNNEL     a DNS lookup whose name is long enough to be carrying data
#   (unattended only)
#   BULK_QUERY     a query string over 128 characters: data smuggled in the URL itself
#   GH_PUBLISH     gh commands that put text on a public page (gist, issue, comment, release)
#
# Plain downloads (curl -O, wget, git fetch, package installs) are not this guard's concern.
# A destination the guard cannot resolve (a variable set elsewhere) fails open, by contract.
# Known limits: a short secret in a short query passes; a request made from inside a script
# file the agent runs is invisible here, because the guard reads the command, not the script.
#
# Contract: see ../CONTRACT.md. Exit 0 allow, exit 2 block with a message on stderr.

CFG="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/../lib/safety-config.py"
HOOK_INPUT="$(cat)"
ALLOWED=""
if [ -f "$CFG" ]; then
  ALLOWED="$(python3 -I -S "$CFG" get egress_allowed_hosts 2>/dev/null)"
fi

# The payload goes on fd 3 (a large command must not hit the argument-size limit);
# the program comes on stdin.
EGRESS_ALLOWED="$ALLOWED" python3 -I -S - 3< <(printf '%s' "$HOOK_INPUT") <<'PY'
import json, os, re, shlex, sys, time

def allow():
    sys.exit(0)

try:
    with os.fdopen(3, "rb") as fh:
        data = json.loads(fh.read().decode("utf-8", "replace") or "{}")
    if not isinstance(data, dict):
        allow()
except Exception:
    allow()

UNATTENDED = os.environ.get("CLAUDE_SAFETY_UNATTENDED") == "1"
QF_MAX = 128


def norm_host_entry(e):
    e = e.strip().lower()
    if not e or e.startswith("#"):
        return ""
    e = re.sub(r"^[a-z][a-z0-9+.-]*://", "", e)
    e = e.split("/", 1)[0]
    if e.startswith("["):
        e = e.split("]", 1)[0] + "]"
    elif e.count(":") == 1:
        e = e.split(":", 1)[0]
    return e.lstrip("*").lstrip(".")

ALLOWED = [h for h in (norm_host_entry(x) for x in os.environ.get("EGRESS_ALLOWED", "").splitlines()) if h]


def is_loopback(h):
    h = (h or "").lower().strip("[]")
    return (h in ("localhost", "::1", "0.0.0.0", "0") or h.endswith(".localhost")
            or re.match(r"^127(\.\d{1,3}){3}$", h) is not None)


def host_ok(h):
    """True when sending to this host is fine: loopback or on the allow list."""
    h = (h or "").lower().rstrip(".")
    if is_loopback(h):
        return True
    return any(h == a or h.endswith("." + a) for a in ALLOWED)


def url_parts(u):
    """(host, query+fragment length) of a URL or bare host; host '' when unresolvable."""
    try:
        from urllib.parse import urlsplit
        if "__SUBST" in u or "$" in u or "`" in u:
            # a runtime value: only trust a literal host that precedes it
            m = re.match(r"^(?:[a-z][a-z0-9+.-]*://)?([A-Za-z0-9.-]+\.[A-Za-z]{2,})(?=[:/?#]|$)", u)
            q = u.split("?", 1)[1] if "?" in u else ""
            return ((m.group(1).lower() if m else ""), len(q))
        if u.startswith(":"):                   # httpie shorthand for localhost
            return ("localhost", 0)
        if not re.match(r"^[a-z][a-z0-9+.-]*://", u, re.I):
            u = "http://" + u
        s = urlsplit(u)
        return ((s.hostname or "").lower(), len(s.query or "") + len(s.fragment or ""))
    except Exception:
        return ("", 0)


def looks_like_target(tok):
    return bool(re.match(r"^(?:[a-z][a-z0-9+.-]*://|:\d|\[[0-9a-f:]+\]"
                         r"|[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)+(?::\d+)?(?:[/?#]|$)|localhost\b)", tok, re.I))


# ---------------------------------------------------------------- command text preparation
SHELLS = r"(?:ba|z|k|da)?sh|python[0-9.]*|node|ruby|perl|php|deno|bun|ssh|sftp|ftp|lftp|nc|ncat|netcat|telnet|curl|wget|http|https|xh"
HEREDOC_RE = re.compile(r"<<-?[ \t]*(['\"]?)([A-Za-z_]\w*)\1([^\n]*)\n(.*?)\n[ \t]*\2[ \t]*(?=\n|$)", re.S)


def split_heredocs(cmd):
    """Drop heredoc bodies that are plain text; keep the header line. A body fed to a shell,
    an interpreter or a network tool is returned separately, because there it is code or data."""
    bodies = []
    def sub(m):
        line_start = cmd.rfind("\n", 0, m.start()) + 1
        header = cmd[line_start:m.start()]
        if re.search(r"(?:^|[\s|;&(/])(?:%s)\b" % SHELLS, header):
            bodies.append((header, m.group(4)))
        return " <<HEREDOC " + m.group(3)
    return HEREDOC_RE.sub(sub, cmd), bodies


def deobfuscate(s):
    s = re.sub(r"(?<=[\w/])(?:''|\"\")|(?:''|\"\")(?=\w)", "", s)   # c''url, ""curl
    s = re.sub(r"\\(?=[A-Za-z])", "", s)                              # \curl, cu\rl
    return s


def lift_substitutions(s, store):
    """Replace every $(...) and `...` with a placeholder; keep their text in store."""
    out, i, n = [], 0, len(s)
    while i < n:
        if s.startswith("$(", i) and not s.startswith("$((", i):
            depth, j = 1, i + 2
            while j < n and depth:
                if s.startswith("$(", j):
                    depth += 1; j += 2; continue
                if s[j] == ")":
                    depth -= 1
                j += 1
            store.append(s[i + 2:j - 1])
            out.append("__SUBST%d__" % (len(store) - 1)); i = j
        elif s[i] == "`":
            j = s.find("`", i + 1)
            if j < 0:
                j = n
            store.append(s[i + 1:j])
            out.append("__SUBST%d__" % (len(store) - 1)); i = j + 1
        elif s.startswith("<(", i) or s.startswith(">(", i):
            depth, j = 1, i + 2
            while j < n and depth:
                if s[j] == "(":
                    depth += 1
                elif s[j] == ")":
                    depth -= 1
                j += 1
            store.append(s[i + 2:j - 1])
            out.append("/dev/fd/__SUBST%d__" % (len(store) - 1)); i = j
        else:
            out.append(s[i]); i += 1
    return "".join(out)


def split_commands(s):
    """Quote-aware split into pipelines (lists of simple-command strings)."""
    pipelines, stages, cur, q, i, n = [], [], [], None, 0, len(s)
    def end_stage():
        stages.append("".join(cur).strip()); del cur[:]
    def end_pipe():
        end_stage()
        st = [x for x in stages if x]
        if st:
            pipelines.append(st)
        del stages[:]
    while i < n:
        c = s[i]
        if q:
            if c == "\\" and q == '"' and i + 1 < n:
                cur.append(s[i:i + 2]); i += 2; continue
            if c == q:
                q = None
            cur.append(c); i += 1; continue
        if c in "'\"":
            q = c; cur.append(c); i += 1; continue
        if c == "\\" and i + 1 < n:
            cur.append(s[i:i + 2]); i += 2; continue
        if s.startswith("||", i) or s.startswith("&&", i):
            end_pipe(); i += 2; continue
        if c == "|" and not (i and s[i - 1] == ">"):
            end_stage(); i += 1
            if i < n and s[i] == "&":
                i += 1
            continue
        if c in ";\n" or (c == "&" and not (i and s[i - 1] in "<>") and not s.startswith("&>", i)):
            end_pipe(); i += 1; continue
        prev = s[i - 1] if i else " "
        nxt = s[i + 1] if i + 1 < n else " "
        if (c == "(" and prev in " \t;&|\n") or (c == ")" and nxt in " \t;&|\n") \
                or (c == "{" and prev in " \t;&|\n" and nxt in " \t\n") \
                or (c == "}" and prev in " \t;\n" and nxt in " \t;&|\n"):
            end_pipe(); i += 1; continue
        cur.append(c); i += 1
    end_pipe()
    return pipelines


def tokenize(stage):
    try:
        return shlex.split(stage, posix=True)
    except ValueError:
        return stage.split()


WRAPPERS = {"sudo", "env", "nohup", "time", "command", "exec", "nice", "stdbuf", "caffeinate",
            "doas", "chronic", "unbuffer", "builtin"}
TEXT_CMDS = {"echo", "printf", "grep", "egrep", "fgrep", "rg", "ag", "man", "which", "type",
             "whatis", "apropos", "tldr", "help", "#"}


def strip_prefix(toks):
    """Drop env assignments and wrapper commands to reach the real command word."""
    i = 0
    while i < len(toks):
        t = toks[i]
        if re.match(r"^[A-Za-z_]\w*=", t):
            i += 1; continue
        base = t.rsplit("/", 1)[-1]
        if base in WRAPPERS:
            i += 1
            while i < len(toks) and toks[i].startswith("-"):
                i += 1 + (1 if toks[i] in ("-u", "-g", "-n", "-C", "-o", "-i", "-e") and base in ("sudo", "nice", "stdbuf") else 0)
            continue
        if base == "timeout":
            i += 1
            while i < len(toks) and toks[i].startswith("-"):
                i += 1
            i += 1                                  # the duration
            continue
        if base == "xargs":
            i += 1
            while i < len(toks) and toks[i].startswith("-"):
                i += 2 if toks[i] in ("-I", "-n", "-P", "-L", "-s", "-d", "-E") else 1
            continue
        break
    return toks[i:]


def redirs(toks):
    """Split redirections off: returns (args, stdin_kind, write_targets).
    stdin_kind is "file" for `< file`, "text" for a heredoc or here-string, else ""."""
    args, stdin_kind, writes, i = [], "", [], 0
    while i < len(toks):
        t = toks[i]
        if t == "<<HEREDOC" or t.startswith("<<<"):
            stdin_kind = stdin_kind or "text"
            i += 1 + (1 if t in ("<<HEREDOC", "<<<") else 0); continue
        m = re.match(r"^(\d*)(<>|<|>>|>\||>|&>>|&>)(.*)$", t)
        if m:
            op, rest = m.group(2), m.group(3)
            if not rest and i + 1 < len(toks):
                rest = toks[i + 1]; i += 1
            if op in ("<", "<>") and m.group(1) in ("", "0"):
                stdin_kind = "file"
            if op != "<":
                writes.append(rest)
            i += 1; continue
        args.append(t); i += 1
    return args, stdin_kind, writes


# ---------------------------------------------------------------- per-tool readers
READS_DATA = re.compile(r"(?:^|[\s;|&(])(?:cat|head|tail|less|base64|xxd|od|hexdump|gzip|zip|tar|"
                        r"bzip2|xz|openssl\s+(?:base64|enc)|env|printenv|set|security|gpg|find|ls|"
                        r"awk|sed|cut|tr|strings|pbpaste|history|git\s+(?:show|log|diff|config))\b"
                        r"|<\s*\S|\$[A-Za-z_]*(?:KEY|TOKEN|SECRET|PASS|PASSWORD|CRED)[A-Za-z_]*", re.I)

CURL_ARG_SHORT = set("AbcCDdeEFHKmoPQrTtuUwxXYyz")    # short options that take a value
CURL_LONG_NOARG = re.compile(r"^--(?:no-.*|silent|show-error|fail|fail-with-body|location|"
                             r"insecure|compressed|verbose|include|head|get|remote-name|"
                             r"remote-name-all|remote-header-name|progress-bar|globoff|http1\.1|"
                             r"http2|ipv4|ipv6|raw|no-buffer|create-dirs|location-trusted|"
                             r"netrc|netrc-optional|anyauth|basic|digest|ntlm|negotiate|ssl|"
                             r"tlsv1\.[0-3]|path-as-is|list-only|append|disable|junk-session-cookies|"
                             r"styled-output|trace-time|fail-early|parallel|retry-all-errors|"
                             r"tcp-nodelay|http0\.9|http3|xattr|clobber|ftp-pasv|ftp-create-dirs|ssl-reqd|"
                             r"http2-prior-knowledge|tr-encoding|proxytunnel|crlf|ftp-ssl|sasl-ir|"
                             r"ignore-content-length|suppress-connect-headers|remove-on-error)$")
CURL_BODY_LONG = re.compile(r"^--(?:data|data-binary|data-raw|data-urlencode|data-ascii|json|"
                            r"form|form-string|upload-file)$")


def read_curl(args):
    """-> (targets, body_flags, is_get, get_data_len, header_files)"""
    targets, body, is_get, get_len, i = [], [], False, 0, 0
    while i < len(args):
        t = args[i]
        if t == "--":
            targets += args[i + 1:]; break
        if t.startswith("--"):
            name, eq, val = t.partition("=")
            takes = not CURL_LONG_NOARG.match(name)
            if not eq and takes and i + 1 < len(args):
                val = args[i + 1]; i += 1
            if CURL_BODY_LONG.match(name):
                if name == "--data-urlencode" or name.startswith("--data"):
                    get_len += len(val)
                body.append(name)
            elif name == "--request" and val.upper() in ("POST", "PUT", "PATCH"):
                body.append("-X " + val.upper())
            elif name == "--get":
                is_get = True
            elif name == "--url":
                targets.append(val)
            elif name == "--header" and val.startswith("@"):
                body.append("-H @file")
            i += 1; continue
        if t.startswith("-") and len(t) > 1:
            letters = t[1:]
            for k, ch in enumerate(letters):
                if ch == "G":
                    is_get = True
                if ch in CURL_ARG_SHORT:
                    val = letters[k + 1:]
                    if not val and i + 1 < len(args):
                        val = args[i + 1]; i += 1
                    if ch in "dFT":
                        body.append("-" + ch)
                        if ch == "d":
                            get_len += len(val)
                    elif ch == "X" and val.upper() in ("POST", "PUT", "PATCH"):
                        body.append("-X " + val.upper())
                    elif ch == "H" and val.startswith("@"):
                        body.append("-H @file")
                    break
            i += 1; continue
        targets.append(t); i += 1
    return targets, body, is_get, get_len


WGET_ARG_SHORT = set("OoaPUeitTwQlADRIXYB")


def read_wget(args):
    targets, body, i = [], [], 0
    while i < len(args):
        t = args[i]
        if t.startswith("--"):
            name, eq, val = t.partition("=")
            if name in ("--post-data", "--post-file", "--body-data", "--body-file"):
                body.append(name)
                if not eq:
                    i += 1
            elif name == "--method":
                if not eq and i + 1 < len(args):
                    val = args[i + 1]; i += 1
                if val.upper() in ("POST", "PUT", "PATCH"):
                    body.append("--method " + val.upper())
            elif not eq and name in ("--output-document", "--output-file", "--directory-prefix",
                                     "--user-agent", "--header", "--input-file", "--user",
                                     "--password", "--tries", "--timeout", "--referer"):
                i += 1
            i += 1; continue
        if t.startswith("-") and len(t) > 1:
            if t[-1] in WGET_ARG_SHORT:
                i += 1
            i += 1; continue
        targets.append(t); i += 1
    return targets, body


def read_httpie(args, stdin_fed):
    targets, body, pos, i = [], [], [], 0
    while i < len(args):
        t = args[i]
        if t.startswith("-") and len(t) > 1:
            if t in ("--raw",):
                body.append("--raw"); i += 2; continue
            if t in ("-a", "--auth", "-o", "--output", "--session", "-A", "--auth-type", "--verify", "--cert"):
                i += 1
            elif t in ("-f", "--form", "-j", "--json", "--multipart"):
                pass
            i += 1; continue
        pos.append(t); i += 1
    if pos and pos[0].upper() in ("GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"):
        method = pos.pop(0).upper()
        if method in ("POST", "PUT", "PATCH"):
            body.append(method)
    if pos:
        targets.append(pos[0])
        for item in pos[1:]:
            if re.match(r"^[^=:@]*(?::=|=(?!=)|@)", item) and not re.match(r"^[^=:@]*==", item):
                body.append("data item")
                break
    if stdin_fed:
        body.append("stdin")
    return targets, body


REMOTE_SPEC = re.compile(r"^(?:(?:scp|sftp|rsync|ssh)://(?:[^@/]+@)?([^/:]+)|(?:[^@/:\s]+@)?(\[[^\]]+\]|[A-Za-z0-9._-]+):(?!//))")


def remote_host(tok):
    if tok.startswith(("/", "./", "../", "~")) or "__SUBST" in tok or tok.startswith("$"):
        return None
    m = REMOTE_SPEC.match(tok)
    if not m:
        return None
    return (m.group(1) or m.group(2) or "").strip("[]").lower()


def positional(args, takes_value):
    out, i = [], 0
    while i < len(args):
        t = args[i]
        if t.startswith("-") and len(t) > 1:
            if t[1:2] in takes_value and len(t) == 2:
                i += 1
            i += 1; continue
        out.append(t); i += 1
    return out


SEND_CODE = re.compile(
    r"requests\s*\.\s*(?:post|put|patch)\b|httpx\s*\.\s*(?:post|put|patch)\b|"
    r"\.(?:post|put|patch)\s*\(|urlopen\s*\([^)]*data\s*=|Request\s*\([^)]*data\s*=|"
    r"method\s*[=:]\s*['\"](?:POST|PUT|PATCH)['\"]|\.request\s*\(\s*['\"](?:POST|PUT|PATCH)|"
    r"\bsendall?\s*\(|\bstorbinary\b|\bsmtplib\b|Net::HTTP\.post|Net::HTTP::Post|"
    r"HTTP::Request->new\s*\(\s*['\"]?POST|->post\s*\(|CURLOPT_POSTFIELDS|file_get_contents\s*\([^)]*stream_context", re.I)
CODE_URL = re.compile(r"https?://[^\s'\"`)\\>]+", re.I)
CODE_SOCK = re.compile(r"(?:connect|create_connection)\s*\(\s*\(\s*['\"]([^'\"]+)['\"]|"
                       r"(?:connect|createConnection)\s*\(\s*\d+\s*,\s*['\"]([^'\"]+)['\"]|"
                       r"TCPSocket\.(?:new|open)\s*\(\s*['\"]([^'\"]+)['\"]|"
                       r"PeerAddr\s*=>\s*['\"]([^'\"]+)['\"]|fsockopen\s*\(\s*['\"]([^'\"]+)['\"]")
INTERP = re.compile(r"^(?:python[0-9.]*|pypy[0-9]*|node|nodejs|deno|bun|ruby|perl|php)$")


def code_findings(code):
    if not SEND_CODE.search(code):
        return []
    hosts = [url_parts(u)[0] for u in CODE_URL.findall(code)]
    for m in CODE_SOCK.finditer(code):
        hosts.append(next(g for g in m.groups() if g).lower())
    bad = sorted({h for h in hosts if h and not host_ok(h)})
    return [("SCRIPT_SEND", "inline code sends data to " + ", ".join(bad))] if bad else []


DNS_CMDS = {"dig", "drill", "nslookup", "host", "ping", "ping6", "traceroute", "traceroute6",
            "mtr", "whois", "dscacheutil", "resolvectl", "getent"}


def dns_findings(args):
    out = []
    for t in args:
        if re.search(r"__SUBST\d+__\S*\.[A-Za-z]{2,}", t) or re.search(r"\$\{?[A-Za-z_]\w*\}?\S*\.[A-Za-z0-9-]+\.[A-Za-z]{2,}", t):
            out.append(("DNS_TUNNEL", "runtime data spliced into a lookup name"))
            continue
        if t.startswith(("-", "+", "@")) or "." not in t or "__SUBST" in t or "$" in t:
            continue
        name = t.rstrip(".")
        labels = name.split(".")
        longest = max(len(l) for l in labels)
        if longest > 31 or len(name) > 80:
            out.append(("DNS_TUNNEL", "%d-char DNS name (longest label %d)" % (len(name), longest)))
    return out


def subst_reads_data(tok, store):
    for k in re.findall(r"__SUBST(\d+)__", tok):
        k = int(k)
        if k < len(store) and READS_DATA.search(store[k]):
            return True
    return False


GH_PUBLISH_RE = re.compile(r"^(?:gist\s+(?:create|new|edit)|issue\s+(?:create|new|comment|edit)"
                           r"|pr\s+(?:comment|review)|release\s+(?:create|upload|edit)"
                           r"|repo\s+(?:create|new|edit|rename))\b")


def gh_findings(args):
    joined = " ".join(args)
    if GH_PUBLISH_RE.match(joined):
        return [("GH_PUBLISH", "gh " + " ".join(args[:2]))]
    if args[:1] == ["api"]:
        if "graphql" in joined and re.search(r"\bmutation\b", joined):
            return [("GH_PUBLISH", "gh api graphql mutation")]
        write = re.search(r"(?:-X|--method)[\s=]*(?:POST|PATCH|PUT)\b|(?:^|\s)(?:-[fF]|--field|--raw-field|--input)\b", joined, re.I)
        pub = re.search(r"(?:^|[\s/])gists\b|/comments\b|/issues/?(?:\s|$)|/releases\b", joined)
        if write and pub and not re.search(r"(?:-X|--method)[\s=]*GET\b", joined, re.I):
            return [("GH_PUBLISH", "gh api write to a public endpoint")]
    return []


def judge_stage(stage, piped, store, depth):
    out = []
    toks = strip_prefix(tokenize(stage))
    if not toks:
        return out
    args, stdin_kind, writes = redirs(toks)
    fed = piped or bool(stdin_kind)
    for w in writes:
        m = re.match(r"^/dev/(?:tcp|udp)/([^/]+)/", w)
        if m and not host_ok(m.group(1)):
            out.append(("RAW_SOCKET", "write to /dev/tcp -> " + m.group(1)))
    if not args:
        return out
    word = args[0].rsplit("/", 1)[-1].lstrip("\\")
    rest = args[1:]
    if word in TEXT_CMDS:
        return out

    def targets_bad(targets):
        hosts = [url_parts(t)[0] for t in targets if looks_like_target(t) or "://" in t]
        return sorted({h for h in hosts if h and not host_ok(h)})

    if word in ("bash", "sh", "zsh", "dash", "ksh", "eval") and depth < 4:
        code = None
        if word == "eval":
            code = " ".join(rest)
        else:
            for k, t in enumerate(rest):
                if t == "-c" or (t.startswith("-") and not t.startswith("--") and "c" in t[1:]):
                    code = rest[k + 1] if k + 1 < len(rest) else None
                    break
        if code:
            out += judge(code, depth + 1)
        return out
    if word == "find" and depth < 4:
        for k, t in enumerate(rest):
            if t in ("-exec", "-execdir", "-ok", "-okdir"):
                end = k + 1
                while end < len(rest) and rest[end] not in (";", "\\;", "+"):
                    end += 1
                out += judge(" ".join(shlex.quote(x) for x in rest[k + 1:end]), depth + 1)
        return out

    if word == "curl":
        targets, body, is_get, get_len = read_curl(rest)
        bad = targets_bad(targets)
        if body and not is_get and bad:
            out.append(("REQUEST_BODY", "%s -> %s" % ("/".join(sorted(set(body))), ", ".join(bad))))
        if bad and any(subst_reads_data(a, store) for a in rest):
            out.append(("FILE_IN_ARGS", "file or environment contents spliced into the request -> " + ", ".join(bad)))
        if UNATTENDED:
            if is_get and get_len > QF_MAX and bad:
                out.append(("BULK_QUERY", "%d chars of -G data -> %s" % (get_len, ", ".join(bad))))
            for t in targets:
                h, n = url_parts(t)
                if n > QF_MAX and h and not host_ok(h):
                    out.append(("BULK_QUERY", "%d chars of query -> %s" % (n, h)))
        return out
    if word == "wget":
        targets, body = read_wget(rest)
        bad = targets_bad(targets)
        if body and bad:
            out.append(("REQUEST_BODY", "%s -> %s" % ("/".join(body), ", ".join(bad))))
        if bad and any(subst_reads_data(a, store) for a in rest):
            out.append(("FILE_IN_ARGS", "file or environment contents spliced into the request -> " + ", ".join(bad)))
        if UNATTENDED:
            for t in targets:
                h, n = url_parts(t)
                if n > QF_MAX and h and not host_ok(h):
                    out.append(("BULK_QUERY", "%d chars of query -> %s" % (n, h)))
        return out
    if word in ("http", "https", "xh", "xhs"):
        targets, body = read_httpie(rest, fed)
        bad = targets_bad(targets)
        if body and bad:
            out.append(("REQUEST_BODY", "httpie %s -> %s" % ("/".join(body), ", ".join(bad))))
        return out
    if word in ("nc", "ncat", "netcat", "telnet"):
        flags = " ".join(t for t in rest if t.startswith("-"))
        if re.search(r"(?:^|\s)-[a-zA-Z]*[lz]", flags) or "--listen" in flags:
            return out                          # listening or a port probe: not a send
        exec_flag = re.search(r"(?:^|\s)(?:-[a-zA-Z]*[ec]\b|--(?:sh-)?exec|--lua-exec|--send-only)", flags)
        pos = positional(rest, set("psiwqxXIOPegcmT"))
        host = pos[0] if pos else ""
        if host and "__SUBST" not in host and "$" not in host and not host_ok(host.lower()) and (fed or exec_flag):
            out.append(("RAW_SOCKET", "%s %s -> %s" % (word, "with an exec flag" if exec_flag and not fed else "fed from a pipe or file", host)))
        return out
    if word == "openssl" and rest[:1] == ["s_client"] and fed:
        m = re.search(r"-connect\s+(\[[^\]]+\]|[^\s:]+)", " ".join(rest))
        if m and not host_ok(m.group(1).strip("[]")):
            out.append(("RAW_SOCKET", "openssl s_client fed from a pipe or file -> " + m.group(1)))
        return out
    if word == "socat":
        for t in rest:
            m = re.match(r"^(?:TCP[46]?|UDP[46]?|OPENSSL|SSL|SCTP|PROXY:[^:]+):(\[[^\]]+\]|[^:,]+):", t, re.I)
            if m and not host_ok(m.group(1).strip("[]")):
                out.append(("RAW_SOCKET", "socat -> " + m.group(1)))
        return out
    if word == "ssh":
        pos = positional(rest, set("bcDEeFIiJLlmOopQRSWw"))
        if pos and (piped or stdin_kind == "file"):
            h = pos[0].split("@")[-1].lower()
            if "__SUBST" not in h and "$" not in h and not host_ok(h):
                out.append(("REMOTE_COPY", "ssh with stdin from a pipe or file -> " + h))
        if pos and len(pos) > 1 and any(subst_reads_data(a, store) for a in pos[1:]):
            h = pos[0].split("@")[-1].lower()
            if not host_ok(h):
                out.append(("FILE_IN_ARGS", "file contents spliced into an ssh command -> " + h))
        return out
    if word == "scp":
        pos = positional(rest, set("cFiJloPS"))
        if len(pos) >= 2:
            h = remote_host(pos[-1])
            if h and not host_ok(h):
                out.append(("REMOTE_COPY", "scp to " + h))
        return out
    if word == "rsync":
        pos, i = [], 0
        while i < len(rest):
            t = rest[i]
            if t in ("-e", "--rsh", "-f", "--filter", "--exclude", "--include", "-B", "--port", "-T"):
                i += 2; continue
            if t.startswith("-"):
                i += 1; continue
            pos.append(t); i += 1
        if len(pos) >= 2:
            h = remote_host(pos[-1])
            if h and not host_ok(h):
                out.append(("REMOTE_COPY", "rsync to " + h))
        return out
    if word in ("sftp", "ftp", "lftp"):
        joined = " ".join(rest)
        pos = positional(rest, set("BbcDFiJloPRSsue"))
        h = ""
        if pos:
            h = (remote_host(pos[0]) or pos[0].split("@")[-1]).lower()
            h = re.sub(r"^[a-z]+://", "", h).split("/")[0].split(":")[0]
        uploads = fed or re.search(r"(?:^|\s)-b\b|\b(?:m?put|reput|mirror\s+-R)\b", joined)
        if h and "__SUBST" not in h and "$" not in h and uploads and not host_ok(h):
            out.append(("REMOTE_COPY", "%s upload -> %s" % (word, h)))
        return out
    if word in ("aws", "gsutil", "rclone", "gcloud", "az"):
        joined = " ".join(rest)
        m = (re.match(r"^s3\s+(?:cp|mv|sync)\s+(.*)$", joined) if word == "aws"
             else re.match(r"^(?:-\S+\s+)*(?:cp|mv|rsync)\s+(.*)$", joined) if word == "gsutil"
             else re.match(r"^storage\s+(?:cp|rsync|mv)\s+(.*)$", joined) if word == "gcloud"
             else re.match(r"^(?:copy|copyto|sync|move|moveto)\s+(.*)$", joined) if word == "rclone"
             else None)
        if m:
            pos = [t for t in m.group(1).split() if not t.startswith("-")]
            if len(pos) >= 2:
                src, dst = pos[-2], pos[-1]
                remote = re.compile(r"^(?:s3|gs)://|^[A-Za-z0-9_-]+:(?!//)")
                if remote.match(dst) and not remote.match(src):
                    bucket = re.sub(r"^(?:s3|gs)://", "", dst).split("/")[0].split(":")[0].lower()
                    if not host_ok(bucket):
                        out.append(("REMOTE_COPY", "%s upload -> %s" % (word, dst.split("/")[0] if "://" not in dst else "/".join(dst.split("/")[:3]))))
        return out
    if INTERP.match(word):
        code = None
        for k, t in enumerate(rest):
            if t in ("-c", "-e", "-E", "-r", "--eval", "-p", "--print") or re.match(r"^-[A-Za-z]*[ce]$", t):
                code = rest[k + 1] if k + 1 < len(rest) else None
                break
        if code:
            out += code_findings(code)
        return out
    if word in DNS_CMDS:
        return dns_findings(rest)
    if word == "gh" and UNATTENDED:
        return gh_findings(rest)
    return out


def judge(cmd, depth=0):
    cmd, bodies = split_heredocs(cmd)
    out = []
    for header, body in bodies:
        hdr_word = re.search(r"(?:^|[\s|;&(/])(%s)\b" % SHELLS, header)
        w = hdr_word.group(1) if hdr_word else ""
        if INTERP.match(w):
            out += code_findings(body)
        elif re.match(r"^(?:ba|z|k|da)?sh$", w) and depth < 4:
            out += judge(body, depth + 1)
    cmd = deobfuscate(cmd)
    # Resolve simple NAME=value assignments so a URL parked in a variable is still seen.
    assigns = {}
    for m in re.finditer(r"(?:^|[\s;&|(])(?:export\s+)?([A-Za-z_]\w*)=('([^']*)'|\"([^\"]*)\"|([^\s;&|)]*))", cmd):
        assigns[m.group(1)] = next((g for g in (m.group(3), m.group(4), m.group(5)) if g is not None), "")
    for k, v in assigns.items():
        if "$" not in v:
            cmd = re.sub(r"\$(?:\{%s\}|%s\b)" % (k, k), lambda _m, v=v: v, cmd)
    store = []
    lifted = lift_substitutions(cmd, store)
    for inner in store:
        if depth < 4:
            out += judge(inner, depth + 1)
    for pipeline in split_commands(lifted):
        for idx, stage in enumerate(pipeline):
            out += judge_stage(stage, idx > 0, store, depth)
    return out


# ---------------------------------------------------------------- dispatch
tool = data.get("tool_name") or ""
ti = data.get("tool_input") if isinstance(data.get("tool_input"), dict) else {}
findings, override, subject = [], None, ""
try:
    if tool == "WebFetch":
        subject = str(ti.get("url") or "")
        if UNATTENDED:
            h, n = url_parts(subject)
            if n > QF_MAX and h and not host_ok(h):
                findings = [("BULK_QUERY", "%d chars of query -> %s" % (n, h))]
    elif tool == "Bash":
        cmd = ti.get("command") or ""
        if not isinstance(cmd, str):
            allow()
        m = re.match(r"^\s*CLAUDE_GUARD_OVERRIDE=(?:'([^']*)'|\"([^\"]*)\"|(\S+))\s+", cmd)
        if m:
            override = next((g for g in m.groups() if g is not None), "").strip()
            cmd = cmd[m.end():]
        subject = cmd
        findings = judge(cmd)
    else:
        allow()
except RecursionError:
    allow()
except Exception:
    allow()        # a defect in the parser must never break ordinary work

if not findings:
    allow()

# de-duplicate while keeping order
seen, uniq = set(), []
for f in findings:
    if f not in seen:
        seen.add(f); uniq.append(f)
findings = uniq
codes = sorted({c for c, _ in findings})

if override and not UNATTENDED:
    try:
        logdir = (os.environ.get("CLAUDE_SAFETY_LOG_DIR") or os.environ.get("CLAUDE_PLUGIN_DATA")
                  or os.path.expanduser("~/.local/state/claude-safety"))
        os.makedirs(logdir, exist_ok=True)
        subj = re.sub(r"(?i)((?:token|key|secret|pass(?:word)?|auth[a-z]*)[=: ]+)\S+", r"\1<redacted>", subject)[:200]
        with open(os.path.join(logdir, "ledger.jsonl"), "a") as f:
            f.write(json.dumps({"ts": time.strftime("%Y-%m-%dT%H:%M:%S%z"), "guard": "egress-guard",
                                "action": "override", "class": "/".join(codes), "reason": override[:300],
                                "subject": subj}) + "\n")
    except Exception:
        pass
    allow()

HOST_CLASSES = {"REQUEST_BODY", "FILE_IN_ARGS", "RAW_SOCKET", "REMOTE_COPY", "SCRIPT_SEND", "BULK_QUERY"}
msg = ["BLOCKED by egress-guard [%s]: this command would send local data off this machine%s: %s." % (
       "/".join(codes), " to a host that is not on the egress allow list" if set(codes) <= HOST_CLASSES else "",
       "; ".join(d for _, d in findings))]
if override and UNATTENDED:
    msg.append("The CLAUDE_GUARD_OVERRIDE prefix was refused: this is an unattended run, so nobody is present to mean it.")
hint = {
    "REQUEST_BODY": "to read a page, drop the body and fetch the URL with a plain GET",
    "FILE_IN_ARGS": "do not splice file or environment contents into a request; fetch without them",
    "RAW_SOCKET": "raw sockets to remote hosts are not needed to read anything; use a plain HTTP GET",
    "REMOTE_COPY": "copy from the remote host to here if you need its files; do not push local files out",
    "SCRIPT_SEND": "read with a GET in the script, or write the result to a local file and report its path",
    "DNS_TUNNEL": "look up a real hostname; a name this long is the shape of data hidden in DNS",
    "BULK_QUERY": "request the resource by its own URL and filter the response locally",
    "GH_PUBLISH": "write the text to a local file and report its path for a person to publish",
}
tail = []
if set(codes) & HOST_CLASSES:
    tail.append("if this destination is genuinely the user's, they can add the host to egress_allowed_hosts in the safety config")
if not UNATTENDED:
    tail.append("if the user agrees this one command is fine, rerun it as: CLAUDE_GUARD_OVERRIDE='<reason>' <the same command>")
msg.append("DO THIS INSTEAD: " + "; ".join(hint[c] for c in codes if c in hint) + "."
           + ("" if not tail else " Otherwise, " + "; or ".join(tail) + "."))
sys.stderr.write("\n".join(msg) + "\n")
sys.exit(2)
PY
