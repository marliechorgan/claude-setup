#!/usr/bin/env python3
"""safety-config.py: read the safety plugin's settings (see CONTRACT.md).

  safety-config.py get <key>     print the value: lists one item per line, paths expanded
  safety-config.py path          print which config file is in use, or "defaults"
  safety-config.py dump          print the merged config as JSON

Run as `python3 -I -S safety-config.py ...`. Standard library only.
"""
import json
import os
import sys

DEFAULTS = {
    "protected_paths": ["~", "~/.ssh", "~/.gnupg", "~/.aws", "~/.config", "~/Documents",
                        "~/Desktop", "~/Library", "~/.claude"],
    "delete_allowed_roots": ["$CWD", "$TMPDIR", "/tmp", "/private/tmp"],
    "control_files": ["~/.claude/settings.json", "~/.claude/settings.local.json",
                      "~/.claude/CLAUDE.md", "~/.claude/hooks", "~/.claude/agents",
                      "~/.claude/skills", "~/.claude/plugins", "~/.config/claude-safety", "~/.zshrc", "~/.bashrc", "~/.bash_profile",
                      "~/.profile", "~/.zshenv", "~/.zprofile", "~/.ssh", "~/.gnupg",
                      "~/.gitconfig", "~/.config/git", "~/.config/fish", "~/.config/gh/hosts.yml",
                      ".claude/settings.json", ".claude/settings.local.json", ".git/hooks",
                      ".git/config"],
    "secret_patterns": [".env", ".env.*", "*.pem", "*.key", "id_rsa*", "id_ed25519*",
                        ".netrc", ".npmrc", ".pypirc", "credentials*", "*.p12", "*.pfx",
                        "*.jks", "*.kdbx", "*.keychain-db", "*.ovpn", "secring*"],
    "egress_allowed_hosts": [],
}


def config_file():
    cands = [os.environ.get("CLAUDE_SAFETY_CONFIG")]
    if os.environ.get("CLAUDE_PLUGIN_DATA"):
        cands.append(os.path.join(os.environ["CLAUDE_PLUGIN_DATA"], "config.json"))
    cands.append(os.path.expanduser("~/.config/claude-safety/config.json"))
    for c in cands:
        if c and os.path.isfile(c):
            return c
    return None


def load():
    cfg = dict(DEFAULTS)
    f = config_file()
    if f:
        try:
            user = json.load(open(f, encoding="utf-8"))
            if isinstance(user, dict):
                cfg.update({k: v for k, v in user.items() if k in DEFAULTS})
        except (OSError, ValueError):
            pass  # a broken config falls back to defaults rather than disabling guards
    cfg["unattended"] = 1 if os.environ.get("CLAUDE_SAFETY_UNATTENDED") == "1" else 0
    return cfg


def expand(item, cwd):
    if not isinstance(item, str):
        return str(item)
    tmp = os.environ.get("TMPDIR", "/tmp")
    item = item.replace("$CWD", cwd or "").replace("$TMPDIR", tmp.rstrip("/"))
    item = os.path.expanduser(item)
    return os.path.normpath(item) if item.startswith("/") else item


def main(argv):
    if not argv:
        print(__doc__, file=sys.stderr)
        return 2
    cfg = load()
    if argv[0] == "path":
        print(config_file() or "defaults")
        return 0
    if argv[0] == "dump":
        print(json.dumps(cfg, indent=2))
        return 0
    if argv[0] == "get" and len(argv) >= 2:
        key = argv[1]
        if key not in cfg:
            print(f"unknown key {key}", file=sys.stderr)
            return 2
        val = cfg[key]
        cwd = argv[2] if len(argv) > 2 else os.getcwd()
        if isinstance(val, list):
            for v in val:
                e = expand(v, cwd)
                if e:
                    print(e)
        else:
            print(val)
        return 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
