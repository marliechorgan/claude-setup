#!/bin/bash
# listen-bind-guard.sh: PreToolUse(Bash) guard against servers and tunnels exposed beyond this machine.
#
# A dev or preview server started without a bind address often listens on 0.0.0.0, which
# publishes whatever it serves to everyone on the same network: a cafe, an office, a shared
# flat. A tunnel goes further and publishes it to the internet. Agents start these servers
# to check their own work and then forget them, so the exposure outlives the task.
#
# Blocks:
#   static-server   python -m http.server, http-server, serve or php -S without a loopback bind
#   wildcard-bind   --host/--bind/--ip/-H and similar set to 0.0.0.0, ::, * or ':PORT';
#                   a bare vite-style --host; HOST=0.0.0.0 style variables; runserver 0:8000
#   public-tunnel   ngrok, cloudflared, localtunnel, tailscale funnel, bore, zrok, ssh -R
#                   to public tunnel services
#   docker-publish  docker/podman run -p PORT or -p HOST:CONTAINER without 127.0.0.1, and -P
# Loopback binds (127.0.0.1, localhost, ::1) are always allowed. Client flags such as
# `psql --host db.internal` are untouched: only wildcard addresses count there.
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


LOOPBACK = re.compile(r"(127(\.\d{1,3}){1,3}|localhost|::1|0:0:0:0:0:0:0:1|ip6-localhost)", re.I)
WILDCARD = {"0.0.0.0", "::", "*", "::0", "0:0:0:0:0:0:0:0"}
BIND_FLAGS = {"--host", "--hostname", "--bind", "-b", "--ip", "--listen", "--address", "--addr",
              "--bind-address", "--bind-addr", "--listen-address", "--listen-addr", "--http-address",
              "--interface", "-H"}
ADDR_ENV = re.compile(r"(?:[A-Z0-9]+_)*(?:HOST|HOSTNAME|BIND|BIND_ADDR|BIND_ADDRESS|LISTEN|LISTEN_ADDR"
                      r"|LISTEN_ADDRESS|ADDR|ADDRESS)")
# static file servers that listen on every interface unless told otherwise: name -> bind flags
STATIC = {"http-server": {"-a", "--address"}, "serve": {"-l", "--listen"}}
TUNNEL_HOSTS = ("serveo.net", "localhost.run", "pinggy.io", "pinggy.link")


def host_part(value):
    v = value.strip().strip("\"'")
    v = re.sub(r"^[a-z]+://", "", v)
    if v.startswith("["):
        return v[1:v.find("]")] if "]" in v else v[1:]
    if v.count(":") == 1:
        return v.split(":")[0]
    return v


def is_wild(value):
    """True for an address meaning every interface: 0.0.0.0, ::, *, or ':8080' / '0:8080'."""
    h = host_part(value)
    return h in WILDCARD or (h in ("", "0") and ":" in value)


def is_loopback(value):
    return LOOPBACK.fullmatch(host_part(value)) is not None


def flag_values(words, flags):
    """Yield (flag, value) for `--flag value`, `--flag=value`; value None when the flag stands alone."""
    for i, w in enumerate(words):
        name, eq, val = w.partition("=")
        if name in flags and eq:
            yield name, val
        elif w in flags:
            nxt = words[i + 1] if i + 1 < len(words) else None
            yield w, (None if nxt is None or nxt.startswith("-") else nxt)


def docker_publish(words):
    """Why a docker/podman run publishes beyond loopback, or None."""
    sub = [w for w in words[1:4] if not w.startswith("-")]
    if not (sub[:1] in (["run"], ["create"]) or sub[:2] in (["container", "run"], ["container", "create"],
                                                          ["service", "create"], ["compose", "run"])):
        return None
    for i, w in enumerate(words):
        specs = []
        if w in ("-P", "--publish-all") or re.fullmatch(r"-[a-zA-Z]*P[a-zA-Z]*", w):
            return "`%s` publishes every exposed port on all interfaces" % w
        if w in ("-p", "--publish") or re.fullmatch(r"-[a-zA-Z]+p", w):
            specs.append(words[i + 1] if i + 1 < len(words) else "")
        elif w.startswith("--publish="):
            specs.append(w.split("=", 1)[1])
        elif re.fullmatch(r"-p\d.*", w):
            specs.append(w[2:])
        for spec in specs:
            if "published=" in spec or "target=" in spec:
                return "`--publish %s` opens the port on every node interface" % spec
            s = re.sub(r"/(tcp|udp|sctp)$", "", spec)
            if s.startswith("["):
                ip, rest = s[1:s.find("]")], s[s.find("]") + 2:]
                ports = rest.split(":")
            else:
                parts = s.split(":")
                ip, ports = (parts[0], parts[1:]) if len(parts) == 3 else (None, parts)
            if not ports or not all(re.fullmatch(r"\d*(-\d+)?", p) for p in ports) or not ports[-1]:
                continue  # not a port spec; some other tool's -p
            if ip is None or not is_loopback(ip):
                return "`-p %s` publishes the port on %s" % (
                    spec, "every interface" if not ip or is_wild(ip + ":0") else ip)
    return None


def find(cmd, cwd=""):
    for env, words in commands(cmd):
        if words and words[0] == "export":
            env = dict(env, **{w.split("=", 1)[0]: w.split("=", 1)[1] for w in words[1:] if ASSIGN.match(w)})
        for k, v in env.items():
            if ADDR_ENV.fullmatch(k) and is_wild(v):
                return ("wildcard-bind", "`%s=%s` makes the server listen on every network interface, "
                        "so anyone on the same network can reach it." % (k, v),
                        "set %s=127.0.0.1 (or localhost)." % k)
        if not words:
            continue
        name = os.path.basename(words[0])

        # Static file servers: they expose a whole directory and default to every interface.
        if ("-m" in words and "http.server" in words) or "-mhttp.server" in words or "SimpleHTTPServer" in words:
            binds = [v for _, v in flag_values(words, {"--bind", "-b"}) if v]
            if not binds or not all(is_loopback(b) for b in binds):
                return ("static-server", "`python -m http.server` %s, publishing the directory to the "
                        "whole network." % ("is bound to %s" % binds[0] if binds else
                                            "with no --bind listens on every interface"),
                        "add a loopback bind: `python3 -m http.server 8000 --bind 127.0.0.1`.")
        if name in STATIC:
            binds = [v for _, v in flag_values(words, STATIC[name]) if v]
            if not binds or not all(is_loopback(b) for b in binds):
                return ("static-server", "`%s` listens on every interface unless given a loopback "
                        "address, publishing the directory to the whole network." % name,
                        "`http-server -a 127.0.0.1` or `serve -l tcp://127.0.0.1:3000`.")
        if name == "php" and "-S" in words:
            i = words.index("-S")
            if i + 1 < len(words) and not is_loopback(words[i + 1]):
                return ("static-server", "`php -S %s` serves beyond this machine." % words[i + 1],
                        "`php -S 127.0.0.1:8000`.")
        if "runserver" in words:
            pos = [w for w in words[words.index("runserver") + 1:] if not w.startswith("-")]
            if pos and (":" in pos[0] or "." in pos[0]) and not re.fullmatch(r"\d+", pos[0]) and not is_loopback(pos[0]):
                return ("wildcard-bind", "`runserver %s` listens beyond this machine." % pos[0],
                        "`runserver 127.0.0.1:8000` (or just the port).")

        # Explicit bind flags set to a wildcard address, or vite-style bare --host.
        for flag, val in flag_values(words, BIND_FLAGS):
            if val is None and flag == "--host":
                return ("wildcard-bind", "a bare `--host` makes the dev server listen on every "
                        "interface, so anyone on the same network can reach it.",
                        "drop it, or use `--host 127.0.0.1`.")
            if val is not None and is_wild(val):
                return ("wildcard-bind", "`%s %s` makes the server listen on every network interface, "
                        "so anyone on the same network can reach it." % (flag, val),
                        "use `%s 127.0.0.1` (or localhost)." % flag)

        # Public tunnels: a URL anyone on the internet can open.
        args = words[1:]
        tunnel = None
        if name == "ngrok" and args[:1] and args[0] in ("http", "tcp", "tls", "start", "tunnel"):
            tunnel = "ngrok"
        elif name == "cloudflared" and ("run" in args or any(a == "--url" or a.startswith("--url=") for a in args)):
            tunnel = "cloudflared"
        elif name in ("lt", "localtunnel") and any(a in ("-p", "--port") or a.startswith("--port=") for a in args):
            tunnel = "localtunnel"
        elif name == "tailscale" and "funnel" in args and not ({"status", "reset", "off"} & set(args)):
            tunnel = "tailscale funnel"
        elif name == "bore" and args[:1] == ["local"]:
            tunnel = "bore"
        elif name == "zrok" and args[:2] == ["share", "public"]:
            tunnel = "zrok"
        elif name in ("ssh", "autossh") and any(a.startswith("-R") for a in args) and \
                any(h in a for a in args for h in TUNNEL_HOSTS):
            tunnel = "ssh reverse tunnel"
        if tunnel:
            return ("public-tunnel", "`%s` opens a public URL to a local port, reachable by anyone on "
                    "the internet." % tunnel,
                    "keep the server on 127.0.0.1. If the user wants a public tunnel, they can start "
                    "it themselves in their own terminal.")

        if name in ("docker", "podman", "nerdctl"):
            why = docker_publish(words)
            if why:
                return ("docker-publish", why + ", so anyone on the same network can reach the container.",
                        "bind it to loopback: `-p 127.0.0.1:8080:80`.")
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


sys.exit(run("listen-bind-guard", find))
PY
