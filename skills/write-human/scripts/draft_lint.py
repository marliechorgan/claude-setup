#!/usr/bin/env python3
"""draft_lint: a deterministic check on messages drafted for a person to send as themselves.

  draft_lint.py [--channel chat|email] [--max-words N] [FILE]   lint FILE (or stdin) as ONE message
  draft_lint.py --markdown [FILE]                               lint every blockquote in a markdown
                                                                reply; each blockquote is one message

Exit: 0 clean, 1 findings printed, 2 usage error. Standard library only, python 3.9+.

Why a script: rules that must hold every time belong in a check, not in prose, and a list of
phrases to avoid belongs in the checker rather than the prompt, because naming a phrase to a
model primes it. The write-human skill carries the positive instructions; the lists live here.

What counts as a draft (--markdown): a blockquote. A blockquote line wrapped in *italics*,
_italics_ or quotation marks, or led by a bold speaker label (**Sam:**), is someone else's message
being quoted and is skipped. A blockquote that opens with a greeting and runs past four lines, or
carries a sign-off, is linted as an email (no length or x checks).
"""
import re
import sys

# Calibrated on one person's year of sent 1:1 texts (~25,000 messages): median 3-7 words, p95
# 12-34. A chat message past this many words is usually a paragraph a person would send as a
# burst of shorter messages. Adjust with --max-words for someone who writes longer texts.
CHAT_MAX_WORDS = 45

# Checked on every draft: phrases that almost never appear in real people's own sent messages.
# "let me know if" is deliberately NOT here: people use it naturally all the time.
STOCK_ANY = [
    "just wanted to", "hope this helps", "happy to help", "hope this finds you",
    "hope this email finds you", "just checking in", "don't hesitate to", "do not hesitate to",
    "i hope this message", "circle back", "touch base",
]
# Checked on chat messages only: natural in an email to a client, stock in a text to a friend.
STOCK_CHAT = [
    "hope you're well", "hope you are well", "hope you're doing well", "hope you are doing well",
    "hope all is well", "been thinking about you", "been thinking of you",
]
PHRASE = {p: re.compile(r"(?<![\w'])" + re.escape(p).replace("'", "['’]") + r"(?![\w])", re.I)
          for p in STOCK_ANY + STOCK_CHAT}
EM_DASH = re.compile("—")
RELATIVE = re.compile(r"\b(tomorrow|yesterday|tonight|this (?:morning|afternoon|evening|weekend)|earlier today|later today)\b", re.I)
EN_DASH = re.compile(r"(?<!\d)\s?–\s?|–(?!\s?\d)")
HEY_NAME = re.compile(r"^\s*hey\s+[A-Z][\w'’-]*\s*!", re.I)
X_SIGNOFF = re.compile(r"(^|\s)x+\s*$", re.I)
LABEL = re.compile(r"^\s*([A-Z][a-z]+(?: [a-z]+)?):(?:\s|$)")
LABEL_OK = {"Subject", "To", "Cc", "Bcc", "From", "Re", "Ps", "Http", "Https"}
NOT_X_BUT_Y = [
    re.compile(r"\bnot (?:just|only|merely|simply) [^.!?\n]{1,60}?\bbut\b", re.I),
    re.compile(r"\b(?:it['’]?s|it is|this is|that['’]?s|that is) not [^.!?\n]{1,40}?[,;:] "
               r"(?:it['’]?s|it is|this is|that['’]?s|that is)\b", re.I),
    re.compile(r"\bisn['’]t (?:about )?[^.!?\n]{1,40}?[,;:] it['’]?s\b", re.I),
]
QUOTED = re.compile(r"^\s*(\*[^*].*\*|_[^_].*_|[\"“].*[\"”]|\*\*[^*]{1,40}:\*\*.*)\s*$")
GREETING = re.compile(r"^\s*(hi|hello|dear|morning|afternoon|evening)\b", re.I)
SIGNOFF = re.compile(r"^\s*(best|thanks|many thanks|cheers|regards|kind regards|best wishes|all the best)\b[ ,!]*$", re.I)


def blockquotes(markdown):
    """Consecutive '>' lines form one message; quoted lines (someone else's words) are dropped."""
    blocks, cur = [], None
    for line in markdown.splitlines():
        m = re.match(r"^\s{0,3}>\s?(.*)$", line)
        if m:
            cur = cur if cur is not None else []
            cur.append(m.group(1))
        elif cur is not None:
            blocks.append(cur)
            cur = None
    if cur is not None:
        blocks.append(cur)
    out = []
    for b in blocks:
        kept = [l for l in b if not QUOTED.match(l)]
        if any(l.strip() for l in kept):
            out.append("\n".join(kept).strip("\n"))
    return out


def looks_like_email(text):
    lines = [l for l in text.splitlines() if l.strip()]
    return bool(lines) and ((GREETING.match(lines[0]) and len(lines) > 4) or any(SIGNOFF.match(l) for l in lines))


def lint(text, channel="chat"):
    """[(kind, detail)] for one message."""
    found = []
    if EM_DASH.search(text):
        found.append(("dash", "em dash: people rarely type one; use a comma, full stop, brackets or a new message"))
    if EN_DASH.search(text):
        found.append(("dash", "en dash used as punctuation (a number range like 2–4 is fine)"))
    for p in STOCK_ANY + (STOCK_CHAT if channel == "chat" else []):
        if PHRASE[p].search(text):
            found.append(("stock", f'"{p}" is a stock phrase, not how the sender writes'))
    m = RELATIVE.search(text)
    if m:
        found.append(("date", f'"{m.group(0)}" goes stale if the draft is sent later: name the day and date'))
    for rx in NOT_X_BUT_Y:
        m = rx.search(text)
        if m:
            found.append(("device", f'not-X-but-Y construction ("{m.group(0)[:50]}")'))
            break
    for line in text.splitlines():
        m = LABEL.match(line)
        if m and m.group(1).split()[0].capitalize() not in LABEL_OK:
            found.append(("device", f'header label "{m.group(1)}:" (write it as a sentence)'))
    if channel == "chat":
        if HEY_NAME.match(text):
            found.append(("greeting", '"Hey <Name>!" opener: real texts usually start on the point'))
        last = [l for l in text.splitlines() if l.strip()][-1:]
        if last and X_SIGNOFF.search(last[0]):
            found.append(("x", 'ends with "x": keep it only if the sender\'s own messages to this person do'))
        n = len(text.split())
        if n > CHAT_MAX_WORDS:
            found.append(("length", f"{n} words in one message; texts are rarely over {CHAT_MAX_WORDS} "
                                    "(split into separate messages, one blockquote each, or cut)"))
    return found


def lint_markdown(markdown):
    """[(message number, kind, detail, first words)] across every draft blockquote."""
    out = []
    for i, b in enumerate(blockquotes(markdown), 1):
        for kind, detail in lint(b, "email" if looks_like_email(b) else "chat"):
            out.append((i, kind, detail, " ".join(b.split()[:6])))
    return out


def main(argv):
    if argv[:1] == ["--hook"]:
        return hook()
    global CHAT_MAX_WORDS
    channel, markdown, path = "chat", False, None
    it = iter(argv)
    for a in it:
        if a == "--channel":
            channel = next(it, "")
            if channel not in ("chat", "email"):
                print("--channel takes chat or email", file=sys.stderr)
                return 2
        elif a == "--max-words":
            try:
                CHAT_MAX_WORDS = int(next(it, ""))
            except ValueError:
                print("--max-words takes a number", file=sys.stderr)
                return 2
        elif a == "--markdown":
            markdown = True
        elif a in ("-h", "--help"):
            print(__doc__)
            return 0
        elif path is None:
            path = a
        else:
            print(__doc__.split("\n\n")[0], file=sys.stderr)
            return 2
    text = sys.stdin.read() if path in (None, "-") else open(path, encoding="utf-8").read()
    if markdown:
        found = [(f"message {i}", k, d) for i, k, d, _ in lint_markdown(text)]
    else:
        found = [("message", k, d) for k, d in lint(text.strip(), channel)]
    for where, kind, detail in found:
        print(f"{where}: {kind}: {detail}")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
