#!/usr/bin/env python3
"""Check every skill and build the release zips.

  python3 tools/build.py          check only (exit 1 on any problem)
  python3 tools/build.py --zip    check, then write dist/<skill>.zip (one skill per zip, for
                                  claude.ai upload) and dist/skills-plugin.zip

Checks: frontmatter uses only the keys claude.ai upload accepts; name is lowercase-hyphen,
at most 64 characters, matches its folder and avoids reserved words; description is 1-1024
characters with no angle-bracket tags; every relative markdown link resolves; each skill's
bundled test suites pass. Standard library only.
"""
import os
import re
import subprocess
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLUGIN = os.path.join(ROOT, "plugins", "skills")
SKILLS = os.path.join(PLUGIN, "skills")
ALLOWED = {"name", "description", "license", "compatibility", "metadata", "allowed-tools"}
NAME = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
LINK = re.compile(r"\]\(([^)#\s]+)(?:#[^)]*)?\)")
SKIP_ZIP = {".DS_Store", "__pycache__"}


def frontmatter(text):
    if not text.startswith("---\n"):
        return None
    end = text.find("\n---\n", 4)
    if end < 0:
        return None
    fields, key = {}, None
    for line in text[4:end].splitlines():
        m = re.match(r"^([A-Za-z_-]+):\s?(.*)$", line)
        if m:
            key = m.group(1)
            fields[key] = m.group(2).strip()
        elif key and line.startswith((" ", "\t")):
            fields[key] = (fields[key] + " " + line.strip()).strip()
    return fields


def check_skill(name):
    problems = []
    d = os.path.join(SKILLS, name)
    path = os.path.join(d, "SKILL.md")
    if not os.path.isfile(path):
        return [f"{name}: no SKILL.md"]
    text = open(path, encoding="utf-8").read()
    fm = frontmatter(text)
    if fm is None:
        return [f"{name}: SKILL.md has no frontmatter block"]
    extra = set(fm) - ALLOWED
    if extra:
        problems.append(f"{name}: frontmatter keys {sorted(extra)} are rejected by claude.ai upload")
    n = fm.get("name", "")
    if not NAME.match(n) or len(n) > 64:
        problems.append(f"{name}: invalid name {n!r}")
    if n != name:
        problems.append(f"{name}: name {n!r} does not match folder")
    if "claude" in n or "anthropic" in n:
        problems.append(f"{name}: name uses a reserved word")
    desc = fm.get("description", "")
    if not 1 <= len(desc) <= 1024:
        problems.append(f"{name}: description is {len(desc)} characters (limit 1024)")
    if re.search(r"<[A-Za-z/][^>]*>", desc):
        problems.append(f"{name}: description contains an angle-bracket tag")
    body_lines = text.count("\n")
    if body_lines > 500:
        problems.append(f"{name}: SKILL.md is {body_lines} lines (keep under 500)")
    for dirpath, _, files in os.walk(d):
        for f in files:
            if not f.endswith(".md"):
                continue
            fp = os.path.join(dirpath, f)
            for target in LINK.findall(open(fp, encoding="utf-8").read()):
                if re.match(r"^[a-z]+:", target):
                    continue
                if not os.path.exists(os.path.normpath(os.path.join(dirpath, target))):
                    problems.append(f"{os.path.relpath(fp, ROOT)}: dead link {target}")
    for dirpath, _, files in os.walk(os.path.join(d, "scripts")):
        for f in sorted(files):
            if f.startswith("test_") and f.endswith(".py"):
                r = subprocess.run([sys.executable, f], cwd=dirpath, capture_output=True, text=True)
                if r.returncode != 0:
                    problems.append(f"{name}: {f} failed\n{r.stderr[-800:]}")
    return problems


def add_tree(z, src, arc_root):
    for dirpath, dirnames, files in os.walk(src):
        dirnames[:] = sorted(x for x in dirnames if x not in SKIP_ZIP)
        for f in sorted(files):
            if f in SKIP_ZIP:
                continue
            full = os.path.join(dirpath, f)
            z.write(full, os.path.join(arc_root, os.path.relpath(full, src)))


def main(argv):
    names = sorted(x for x in os.listdir(SKILLS) if os.path.isdir(os.path.join(SKILLS, x)))
    problems = [p for n in names for p in check_skill(n)]
    for p in problems:
        print(p)
    print(f"{len(names)} skills checked, {len(problems)} problem(s)")
    if problems:
        return 1
    if "--zip" in argv:
        dist = os.path.join(ROOT, "dist")
        os.makedirs(dist, exist_ok=True)
        for n in names:
            with zipfile.ZipFile(os.path.join(dist, f"{n}.zip"), "w", zipfile.ZIP_DEFLATED) as z:
                add_tree(z, os.path.join(SKILLS, n), n)
        with zipfile.ZipFile(os.path.join(dist, "skills-plugin.zip"), "w", zipfile.ZIP_DEFLATED) as z:
            for top in ("GUIDE.md", "LICENSE", ".claude-plugin", "agents"):
                p = os.path.join(PLUGIN, top)
                if os.path.isdir(p):
                    add_tree(z, p, os.path.join("skills", top))
                elif os.path.exists(p):
                    z.write(p, os.path.join("skills", top))
            add_tree(z, SKILLS, os.path.join("skills", "skills"))
        print(f"wrote {len(names) + 1} zips to {os.path.relpath(dist, ROOT)}/")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
