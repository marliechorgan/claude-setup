#!/usr/bin/env python3
"""brief_lint.py: deterministic checks on a worker brief before it is dispatched.

Usage: brief_lint.py [--base DIR]... BRIEF [BRIEF...]      (BRIEF '-' reads stdin)
Standard library only, python 3.9+.

One line per finding, '<brief>: <check>: <detail>', then a summary line. Checks:
  dead-path            a ~/ or absolute path (or a relative one whose first part exists under a
                       --base) that does not exist, unless the brief asks for it to be created
  drifted-line-ref     file:N quoting text not within 2 lines of N (25 for "~line N"), or N past
                       the end of the file; a ref with no adjacent quote is not judged
  path-clash           a return path that is a brief's own path or another brief's return path,
                       or an acceptance line naming another, non-existent file in the return
                       path's directory (a queue alias such as q12.md against the full-id file)
  no-acceptance        no Acceptance / Done-when section
  no-write-scope       no write scope (Write scope:, Own:, read-only, "no writes outside X")
  outside-write-scope  the acceptance says a file will be created, written or saved ("write X",
                       "X exists", "a file at X") outside every path the write scope allows; a
                       path it names to read, prune, exclude or delete is not judged
Exit: 0 clean, 1 findings, 2 not judged (usage error, unreadable brief, internal error).
Relative paths are judged only against --base directories, never the cwd. Paths under /tmp,
placeholders (<id>, $VAR, ..., YYYY) and URLs are skipped: a gate that bounces work must not guess.
An absolute path cut at a space stays whole when it is quoted ('~/Library/Mobile Documents') or
when the next word completes an entry on disk.
"""
import argparse
import glob
import os
import re
import sys

PCH = r"[^\s`'\"<>|,;:()\[\]{}#]"
ABS = re.compile(r"(?<![\w.~$/-])((?:~|/(?:Users|home|private|tmp|var|opt|etc|usr|Library|Applications|Volumes))/" + PCH + "*)")
REL = re.compile(r"(?<![\w.~$/@:-])((?:[\w@+-][\w.@+-]*/)+" + PCH + "*)")
BARE = re.compile(r"(?<![\w./~$-])([\w-][\w.-]*\.[A-Za-z]\w{0,5})(?=:\d)")
LREF = re.compile(r":(\d+)(?:\s*[-–]\s*(\d+))?((?:,\s*\d+)*)")
APPROX = re.compile(r"(?:~\s*|\baround\s+|\bnear\s+|\babout\s+)(?:line|l\.)\s*(\d+)", re.I)
QSPAN = re.compile(r"`[^`\n]+`|\"[^\"\n]+\"")
AFTER_GAP = re.compile(r"\s*(?:[:=—–-]|\b(?:reads|says|has|is|shows|prints|contains|holds)\b)?\s*")
BEFORE_GAP = re.compile(r"\s*(?:[(\[—–:,-]|\bat\b|\bin\b)?\s*")
CONT = re.compile(r"^(?:\s+\S|\s*(?:[-*+]|\d+[.)])\s)")
SYM = re.compile(r"`[^`\n]{3,}`|\b\w+\(\)")
LABEL = re.compile(r"^\s*(?:#{1,6}\s+|>\s*|[-*+]\s+|\d+[.)]\s+)?(?:\*\*|__)?([A-Za-z][^:`\n]{0,120}?)(?:\*\*|__)?\s*:")
HEAD = re.compile(r"^\s*#{1,6}\s+(.*)$")
KINDS = [("accept", re.compile(r"\b(acceptance(?!\s+owner)|done[ -]?when|definition of done|success criteria|finish[- ]line)", re.I)),
         ("write", re.compile(r"\b(write scope|write surface|writes|owns?|owned|ownership|may (write|edit|touch|change))\b", re.I)),
         ("return", re.compile(r"\b(returns?|deliverables?|results?|outputs?|reports?)\b", re.I)),
         ("scratch", re.compile(r"\bscratch\b", re.I))]
INLINE_ACCEPT = re.compile(r"\b(?:(?:you are )?done[ -]when|acceptance(?!\s+owner)(?: cases| criteria| tests?)?)\b[^:\n]{0,120}:(?!\d)"
                           r"|\b(?:your job ends|done means|(?:finished|complete) when)\b", re.I)
WRITE_PHRASE = re.compile(r"^\s*(?:[-*+]|\d+[.)])?\s*read[- ]only\b|\b(?:scope|effects?|mode|access)\W{0,4}read[- ]only\b"
                          r"|\b(?:you are|you're|stay|remain|strictly|(?:lane|job|task|worker|run) is)\s+read[- ]only\b"
                          r"|\bno (?:file |other )?(?:writes?|edits?|changes?)\b[^.\n]{0,40}?\b(?:outside|except|beyond|other than)\b"
                          r"|\b(?:may|can) (?:only )?(?:write|edit|touch|change|create)\b|\b(?:write|edit|touch|change) only\b"
                          r"|\b(?:write|touch|edit) nothing\b", re.I)
CREATE = re.compile(r"\b(?:creat\w*|new|write|writes|writing|written|add|adds|make|made|mkdir|save\w*|output\w*|produc\w*|generat\w*"
                    r"|emit\w*|draft\w*|stag\w*|render\w*|into|append\w*|build\w*|return\w*|deliver\w*|scratch)\b", re.I)
RETURN_BEFORE = re.compile(r"\b(?:return(?:s|ed)?(?: it| them)?(?: to| at| in)?(?: per [\w.]+)?|deliverables?(?: at| to| in)?"
                           r"|reports?(?: to| at| in)|results?(?: at| to| in| is)|write (?:your|the) (?:report|result)s?(?: to| at| in)?"
                           r"|outputs?(?: to| at| in))[\s:*`]{0,5}$", re.I)
CONDITIONAL = re.compile(r"\bif\b\W{0,3}$", re.I)  # "if `X` exists": the brief knows X may be absent
PLACEHOLDER = re.compile(r"\.\.\.|…|\$|YYYY|HHMM|XXXX|\bDATE\b")
WORD = re.compile(PCH + "+")
SPACED = re.compile(r"(?: (?!-)" + PCH + "+)+")  # the rest of a quoted path: words, none a --flag
# What the acceptance does to a path: the verb nearest before it in its clause decides.
VERB = re.compile(r"\b(?:(?P<write>creat\w*|writ(?:e|es|ing|ten)|sav(?:e|es|ed|ing)|produc\w*|generat\w*|emit\w*"
                  r"|append\w*|add(?:s|ed|ing)?|new|mkdir|render\w*|build\w*|built|draft\w*|output\w*|record\w*|into"
                  r"|stag(?:e|es|ed|ing)|put|plac(?:e|es|ed|ing)|edit\w*|modif\w*|updat\w*|patch\w*)"
                  r"|read\w*|prun\w*|exclud\w*|skip\w*|ignor\w*|delet\w*|remov\w*|rm|avoid\w*|walk\w*|scan\w*|search\w*"
                  r"|grep|find|du|bfs|rg|inspect\w*|check\w*|compar\w*|quot\w*|cit(?:e|es|ed|ing)|leav\w*|except)\b", re.I)
NEGATED = re.compile(r"(?:\b(?:not|never|no|nothing|without)|n't)\W+(?:\w+\W+){0,2}$", re.I)
CLAUSE = re.compile(r".*(?:[;:.!?—][\s*]|\()", re.S)  # a path's clause starts after the last of these
WRITTEN_AFTER = re.compile(r"[\s`'\"*)]*(?:exists|contain(?:s|ing)|holds|is (?:created|written|saved|generated|produced|added|present)"
                           r"|(?:gets|will be|has been) (?:created|written|saved|generated|produced))\b", re.I)
WRITTEN_AT = re.compile(r"\b(?:(?:is|are|lands?|goes) (?:in|at|under)|(?:file|result|report|table|doc|document|note|page|diff"
                        r"|log|script|dir|directory|folder)s? (?:at|in|under))\W{0,3}$", re.I)  # "the table is in X"


def kinds_of(label, heading=False):
    """Section kinds a field label names. Parentheticals are dropped ("Acceptance (tests first)");
    a title ("W1: the lint writes findings") or a sentence ending in a colon names none."""
    core = re.sub(r"\([^)]*\)?", " ", label).strip(" *_")
    if (heading and ":" in core) or len(core.split()) > (5 if heading else 8):
        return set()
    return {k for k, rx in KINDS if rx.search(core)}


def norm(s):  # quotes in a brief drop markdown emphasis and flatten dashes; so does the match
    return " ".join(re.sub(r"[*_`]", "", s).replace("—", "-").replace("–", "-").split())


def found(frags, text):
    t, pos = norm(text), 0
    for f in frags:
        j = t.find(norm(f), pos)
        if j < 0:
            return False
        pos = j + len(norm(f))
    return True


def adjacent_quote(ln, s, e):
    """The quote right after the ref (or right before it), paired left to right; else None."""
    spans = list(QSPAN.finditer(ln))
    own = next((m for m in spans if m.start() < s and e <= m.end()), None)
    a, z = (own.start(), own.end()) if own else (s, e)
    after = next((m for m in spans if m.start() >= z), None)
    if after and AFTER_GAP.fullmatch(ln, z, after.start()):
        return after.group()
    before = next((m for m in reversed(spans) if m.end() <= a), None)
    if before and BEFORE_GAP.fullmatch(ln, before.end(), a):
        return before.group()
    return None


def exists(p):
    return bool(glob.glob(p)) if any(c in p for c in "*?[") else os.path.exists(p)


def whole(ln, s, e):
    """The end of the absolute path at ln[s:e] when it was cut at a space: the rest of its quoted
    span, or each next word that completes an entry on disk. An existing path is never extended."""
    raw = ln[s:e]
    if exists(os.path.expanduser(raw)):
        return e
    z = ln.find(ln[s - 1], e) if s and ln[s - 1] in "'\"`" else -1
    if z > e and SPACED.fullmatch(ln, e, z) and "." not in os.path.basename(raw):
        return z
    while ln[e:e + 1] == " ":
        w = WORD.match(ln, e + 1)
        if not w:
            break
        d, base = os.path.split(os.path.expanduser(ln[s:e]))
        name = base + " " + w.group().split("/")[0].rstrip(".!?*")  # the sentence's full stop is not the name's
        try:
            if not any(x == name or x.startswith(name + " ") for x in os.listdir(d)):
                break
        except OSError:
            break
        e = w.end()
    return e


def written(ln, s, e):
    """Does the acceptance say the path at ln[s:e] will be created, written or saved?"""
    if WRITTEN_AFTER.match(ln, e) and not re.search(r"\b(?:if|whether|unless)\W{0,3}$", ln[max(0, s - 12):s]):
        return True  # "X exists", "X contains", "X is written"; not "if X exists"
    clause = ln[max(0, s - 200):s]
    c = CLAUSE.match(clause)
    clause = re.sub(r"\S*/\S*", " ", clause[c.end():] if c else clause)  # a verb, not a word inside another path
    verbs = list(VERB.finditer(clause))
    if not verbs:
        return bool(WRITTEN_AT.search(clause))
    return bool(verbs[-1].group("write") and not NEGATED.search(clause[:verbs[-1].start()]))


def under(p, root):
    root = root.rstrip("/")
    return p == root or p.startswith(root + "/")


class Brief:
    def __init__(self, label, path, text, bases):
        self.label, self.path, self.bases = label, path, bases
        self.lines = text.replace("${HOME}/", "~/").replace("$HOME/", "~/").splitlines()
        # A heading's kinds last until the next heading. A label's kinds last over its list
        # items and indented lines, or its whole paragraph when the label line has no body.
        self.kinds, head, lab, open_body = [], set(), set(), False
        for ln in self.lines:
            h, m = HEAD.match(ln), LABEL.match(ln)
            if h:  # a section heading ("## Acceptance"), not a title that happens to say "writes"
                head, lab, open_body = kinds_of(h.group(1), heading=True), set(), False
            elif m and (kinds_of(m.group(1)) or not CONT.match(ln)):  # a field label, bulleted or not
                lab, open_body = kinds_of(m.group(1)), not ln[m.end():].strip(" *_")
            elif not ln.strip():
                lab, open_body = set(), False
            elif not (open_body or CONT.match(ln)):
                lab = set()
            k = head | lab
            if INLINE_ACCEPT.search(ln):
                k = k | {"accept"}
            if WRITE_PHRASE.search(ln):
                k = k | {"write"}
            self.kinds.append(k)
        self.paths = []  # (line, start, end, raw, kind)
        for i, ln in enumerate(self.lines):
            spans = []
            for kind, rx in (("abs", ABS), ("rel", REL), ("bare", BARE)):
                for m in rx.finditer(ln):
                    if any(m.start(1) < e and s < m.end(1) for s, e in spans):
                        continue
                    end = whole(ln, m.start(1), m.end(1)) if kind == "abs" else m.end(1)
                    raw = ln[m.start(1):end]
                    nxt = ln[end:end + 1]
                    if PLACEHOLDER.search(raw) or nxt in ("<", "{", "$", "…"):
                        continue
                    if raw.endswith("**"):
                        raw = raw[:-2]
                    raw = raw.rstrip(".!?")
                    if kind == "rel" and not (raw.endswith("/") or "." in raw.rsplit("/", 1)[-1]):
                        continue  # "and/or", "ls/grep", "24/7": not paths
                    spans.append((m.start(1), end))
                    self.paths.append((i, m.start(1), m.start(1) + len(raw), raw, kind))

    def candidates(self, raw, kind):
        if kind == "abs":
            return [os.path.normpath(os.path.expanduser(raw))]
        return [os.path.normpath(os.path.join(b, raw)) for b in self.bases]

    def is_output(self, i, start):
        return bool(self.kinds[i] & {"accept", "write", "return", "scratch"}) or bool(CREATE.search(self.lines[i][max(0, start - 60):start]))

    def returns(self):
        """Paths the brief says to return to: named right after return words, or first on a return label line."""
        out, labelled = [], set()
        for i, s, e, raw, kind in self.paths:
            if kind == "bare" or "accept" in self.kinds[i]:
                continue
            m = LABEL.match(self.lines[i])
            first_on_label = m and i not in labelled and "return" in kinds_of(m.group(1))
            if RETURN_BEFORE.search(self.lines[i][max(0, s - 40):s]) or first_on_label:
                out.append((raw, kind))
                labelled.add(i)
        return out


def missing_root(p):
    """The highest missing ancestor of p (p itself when its parent exists)."""
    p = p.rstrip("/")
    while not os.path.exists(os.path.dirname(p)) and os.path.dirname(p) not in ("", "/"):
        p = os.path.dirname(p)
    return p


def archived_twin(p):
    head, rest = p, []
    while head not in ("", "/") and not os.path.exists(head):
        head, tail = os.path.split(head)
        rest.insert(0, tail)
    twin = os.path.join(head, "_archive", *rest) if rest else ""
    return twin if twin and os.path.exists(twin) else ""


def check_paths(b, out):
    outputs = [c for i, s, e, raw, kind in b.paths if kind != "bare" and b.is_output(i, s) for c in b.candidates(raw, kind)]
    seen = set()
    for i, s, e, raw, kind in b.paths:
        if kind == "bare" or re.match(r"(?:/private)?/tmp/", raw):
            continue
        cands = b.candidates(raw, kind)
        if not cands or cands[0] in seen or any(exists(c) for c in cands) or b.is_output(i, s):
            continue
        seen.add(cands[0])
        if raw.endswith("/") and any(os.path.isdir(os.path.dirname(c.rstrip("/"))) for c in cands):
            continue  # a new directory under an existing one is somewhere to put output
        if CONDITIONAL.search(b.lines[i][max(0, s - 8):s]):
            continue
        # a path under a directory this brief creates ("New skill skills/x/SKILL.md" ... "skills/x/scripts/")
        if any(under(o, missing_root(c)) for c in cands for o in outputs):  # includes the path itself
            continue
        if kind == "rel" and not any(os.path.exists(os.path.join(base, raw.split("/")[0])) for base in b.bases):
            continue
        twin = archived_twin(cands[0])
        out.append(("dead-path", "%s does not exist%s" % (raw, "; archived at " + twin if twin else "")))


def check_line_refs(b, out):
    cache = {}
    for i, s, e, raw, kind in b.paths:
        ln = b.lines[i]
        f = next((c for c in (b.candidates(raw, "rel") if kind == "bare" else b.candidates(raw, kind)) if os.path.isfile(c)), None)
        if not f:
            continue
        if f not in cache:
            try:  # an unreadable or huge file leaves its refs unjudged
                if os.path.getsize(f) > 20 * 1024 * 1024:
                    raise OSError("over 20 MB")
                with open(f, encoding="utf-8", errors="replace") as fh:
                    cache[f] = fh.read().splitlines()
            except OSError:
                cache[f] = None
        flines = cache[f]
        if flines is None:
            continue
        m = LREF.match(ln, e)
        if m:
            nums = [int(m.group(1))] + [int(x) for x in re.findall(r"\d+", m.group(3) or "")]
            lo_hi = [(n, n) for n in nums]
            if m.group(2):
                lo, hs = str(nums[0]), m.group(2)
                hi = int(lo[:len(lo) - len(hs)] + hs) if int(hs) < nums[0] and len(hs) < len(lo) else int(hs)
                lo_hi[0] = (nums[0], max(hi, nums[0]))  # ":1644-45" means 1644 to 1645
            tol, ref_end = 2, m.end()
            quote = adjacent_quote(ln, s, ref_end)
            label = "%s%s" % (raw, m.group(0))
        else:
            a = APPROX.search(ln, e, e + 80)
            if not a:
                continue
            lo_hi, tol = [(int(a.group(1)), int(a.group(1)))], 25
            sm = SYM.search(ln, e, a.start())
            quote, label = (sm.group(0) if sm else None), "%s (~line %s)" % (raw, a.group(1))
        for lo, hi in lo_hi:
            if lo > len(flines) + (tol if tol > 2 else 0):
                out.append(("drifted-line-ref", "%s: line %d is past the end of the file (%d lines)" % (label, lo, len(flines))))
                break
        else:
            if not quote:
                continue
            q = quote.strip("`\"")
            frags = [x.strip() for x in re.split(r"\.\.\.|…", q) if len(x.strip()) >= 3]
            if len(q) < 4 or not frags or re.fullmatch(r"[\w./~-]*/[\w./~-]*(?::\d+)?", q):
                continue
            if any(found(frags, "\n".join(flines[max(0, lo - 1 - tol):hi + tol])) for lo, hi in lo_hi):
                continue
            at = next((n + 1 for n in range(len(flines)) if found(frags, flines[n])), None)
            if at is None:  # a quote spanning lines: the last window start that still holds it all
                at = next((n + 1 for n in range(len(flines)) if found(frags, "\n".join(flines[n:n + 5]))
                           and not found(frags, "\n".join(flines[n + 1:n + 6]))), None)
            where = "which is at line %d" % at if at else "which is not in the file"
            out.append(("drifted-line-ref", "%s quotes %s, %s" % (label, quote, where)))


def check_sections(b, out, all_returns):
    rets = b.returns()
    for raw, kind in rets:
        full = b.candidates(raw, kind)[0] if kind == "abs" else raw
        if kind == "abs" and b.path and os.path.realpath(full) == b.path:
            out.append(("path-clash", "return path %s is this brief's own path" % raw))
        elif all_returns.get(full, b.label) != b.label:
            out.append(("path-clash", "return path %s is also %s's return path" % (raw, all_returns[full])))
    accept = [(i, s, e, raw, kind) for i, s, e, raw, kind in b.paths if "accept" in b.kinds[i] and kind != "bare"]
    for i, s, e, raw, kind in accept:
        if any(exists(c) for c in b.candidates(raw, kind)):
            continue  # an existing file the acceptance reads or keeps is not a second result
        for r, rk in rets:
            pd, rd = os.path.basename(os.path.dirname(raw.rstrip("/"))), os.path.basename(os.path.dirname(r.rstrip("/")))
            if (pd and pd == rd and os.path.basename(raw) != os.path.basename(r)
                    and os.path.splitext(raw)[1] == os.path.splitext(r)[1] and raw not in [x for x, _ in rets]):
                out.append(("path-clash", "the acceptance names %s but the return path is %s" % (raw, r)))
                break
    if not any("accept" in k for k in b.kinds):
        out.append(("no-acceptance", "no Acceptance or Done-when section: say what finished looks like before the task"))
    if not any("write" in k for k in b.kinds):
        out.append(("no-write-scope", "no write scope: name the files, repos or dirs this worker may change (or say read-only)"))
        return
    roots, unresolved = [], False
    for i, s, e, raw, kind in b.paths:
        if kind == "bare" or not (b.kinds[i] & {"write", "return", "scratch"}):
            continue
        if kind == "rel" and not b.bases:
            unresolved = unresolved or "write" in b.kinds[i]
        roots.extend(c.split("*", 1)[0] for c in b.candidates(raw, kind))  # "skills/x/**" covers skills/x/
    if unresolved:
        return
    for i, s, e, raw, kind in accept:
        if kind != "abs" or re.match(r"(?:/private)?/tmp/", raw) or not written(b.lines[i], s, e):
            continue
        p = b.candidates(raw, kind)[0]
        if not exists(p) and not any(under(p, r) for r in roots):
            out.append(("outside-write-scope", "the acceptance needs %s, which no write-scope path covers" % raw))


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--base", action="append", default=[], help="directory that relative paths resolve against (repeatable)")
    ap.add_argument("briefs", nargs="+", help="brief file(s), or - for stdin")
    a = ap.parse_args(argv)
    bases = [os.path.abspath(os.path.expanduser(x)) for x in a.base]
    briefs = []
    for arg in a.briefs:
        try:
            if arg == "-":
                briefs.append(Brief("-", None, sys.stdin.read(), bases))
            else:
                p = os.path.realpath(os.path.expanduser(arg))
                with open(p, encoding="utf-8", errors="replace") as fh:
                    briefs.append(Brief(arg, p, fh.read(), bases))
        except OSError as exc:
            print("brief_lint: cannot read %s: %s" % (arg, exc), file=sys.stderr)
            return 2
    try:  # a lint bug must exit 2 (not judged), never 1: a caller bounces work on findings
        return lint(briefs)
    except Exception as exc:
        print("brief_lint: internal error, briefs not judged: %r" % (exc,), file=sys.stderr)
        return 2


def lint(briefs):
    all_returns, total = {}, 0
    for b in briefs:
        for raw, kind in b.returns():
            all_returns.setdefault(b.candidates(raw, kind)[0] if kind == "abs" else raw, b.label)
    brief_paths = {b.path: b.label for b in briefs if b.path}
    for b in briefs:
        out = []
        check_paths(b, out)
        check_line_refs(b, out)
        check_sections(b, out, all_returns)
        for raw, kind in b.returns():
            other = brief_paths.get(os.path.realpath(b.candidates(raw, kind)[0])) if kind == "abs" else None
            if other and other != b.label:
                out.append(("path-clash", "return path %s is brief %s" % (raw, other)))
        for check, detail in out:
            print("%s: %s: %s" % (b.label, check, detail))
        total += len(out)
    print("brief_lint: %d finding(s) in %d brief(s)" % (total, len(briefs)))
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
