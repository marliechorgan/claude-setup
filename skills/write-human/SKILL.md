---
name: write-human
description: Draft or edit writing a person will send or publish as themselves: texts, WhatsApp and DMs, emails, replies, LinkedIn messages, introductions and first approaches, client updates, cover notes, posts and short professional documents, so it sounds like them, not like an AI. Use whenever the user asks to write, reply to, rewrite, polish, shorten or "make this sound less like AI", or asks "what should I say to X". Drafts from the sender's own past messages, leads with the reader, cuts preview lines, stock phrases and research the reader never shared, and names dates instead of "tomorrow". Drafts only; the user sends.
license: MIT
---

# Write human

Write something the user can send as themselves. Natural writing comes from having something specific to say to a specific reader, not from vocabulary bans or deliberate roughness. The user's own wording and edits outrank every default here.

## Start with the reader

Work out who will read it, what they already know, what it must achieve, and where they will read it (a phone notification, an inbox, a printed page). Ask only when a missing fact would change the draft. Pick the form the job needs: a warm reply, a first approach and a technical update are different things.

If the user supplies a draft, keep their meaning, emphasis and good phrasing, and edit at the level they asked for.

## Draft in their voice, from their words

The user's voice is in their sent messages, not in a general idea of "friendly" or "professional". For anything personal, ask for (or find, if you have access) three to five of their recent messages **to this person** and draft from those: length, capitals, punctuation, emoji, how they sign off. People write very differently to a grandparent, a colleague and a sibling. If no samples are available, write plainly and briefly, and say which parts are guesses.

When the user adds a line of their own, keep it exactly as written.

## What makes it read as a person

- **Lead with them, not with you.** Open on their news, their question or what they said last time. Your result is often the least interesting part to the reader.
- **Answer the last unanswered thing first.** If they made a joke, pick it up.
- **Say the real thing plainly.** If someone is going through something, ask about it directly and keep it light; don't circle it or get earnest.
- **Hand them the choice.** Offer a loose window and let them pick the time and place.
- **One line about them** where it fits: their news, their work, a bit of praise that is true.
- **Leave out what you found by digging.** A detail from their profile, an event page or another chat reads as surveillance. Use only what they told the sender.
- **Warmth grounded in something real.** Plain stock warmth ("thanks for your patience") is fine when it fits an actual event. Don't invent gratitude, excitement or a favour to thank them for.
- **Name days and dates in anything that may be sent later:** "Thursday 2 Oct", not "tomorrow" or "this weekend". Drafts often sit for a day or two, and relative words go stale without anyone noticing.

## What to cut

- A first line that previews the message ("A quick update and one bigger question").
- A second sentence that shrinks a gracious out ("No problem if not. It works fine without it.").
- Limitations the reader doesn't need in order to say yes.
- Flourishes that read as boasts, over-offering ("happy to do a panel, a talk, or whatever suits"), and a PS bolted onto a first approach. One ask per message.
- Presuming the reader's state of mind ("as I'm sure you've noticed"), and contrarian jabs.
- Something the reader already has from an earlier message or from the product itself.

Length is not the goal. Real edits lengthen as often as they shorten; what goes is logistics, research and devices, and what comes in is something about the person. Revise by cutting: a second pass deletes, it doesn't polish.

## By kind of writing

- **Texts and DMs:** usually two to five short messages rather than one paragraph. Show each separate message as its own blockquote so the user can paste them one by one. End on the practical line.
- **First approaches and introductions:** describe a company by what it does, not where it is; for a non-technical or senior reader, purpose and impact beat technique, and one checkable credential beats a product description. Lead with what people can picture using, not with the tool the writer is proudest of.
- **Emails:** the purpose and any ask easy to find; one topic per email; a disclosure or apology in one plain sentence, not a confession. When the reader must act on a decision, give an instruction they can relay ("Use version 2 for this batch; flag uncertain words") and say plainly if it is still pending.
- **Technical and research updates:** real system names, exact numbers with their units and comparison ("error rate fell from 30% to 16%", not only "halved"), and what remains uncertain. Respect what the reader already knows; don't explain their own project back to them.
- **Posts and shared documents:** follow the conventions already on the page or in the thread.

## Check, then hand over

In Claude Code or anywhere Python runs, check the drafts before showing them:

```bash
python3 scripts/draft_lint.py --markdown reply.md       # every blockquote is one message
python3 scripts/draft_lint.py --channel email draft.txt # one email
```

It flags em dashes, stock phrases, "not X but Y" constructions, header-style labels, relative dates and over-long texts. (The phrase lists live in the script on purpose: naming them here would prime them.) If a flag is wrong for this reader because the sender genuinely writes that way, keep it and say so.

Show the drafts ready to paste, with no commentary on the writing process. This skill drafts; the user sends. When they edit a draft and ask for another pass, carry their edits forward rather than regenerating from scratch.
