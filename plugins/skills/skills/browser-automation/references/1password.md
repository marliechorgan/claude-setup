# 1Password with Claude

Contents: agentic autofill (setup, the call sequence, failure codes) · other sign-in paths · the `op` CLI traps.

Observed on macOS with Claude desktop, Chrome and the 1Password 8.12 app and extension, July–September 2026. The integration was in beta; recheck anything that disagrees with what you see.

## Agentic autofill

**What it is.** Claude asks for a kind of credential for a site. 1Password shows its own approval prompt (which item, which site, why), the user approves with Touch ID, and the 1Password extension fills and submits the page. Claude only learns which item was used, never the value. Grants are per task and live in extension memory. It is strictly better than `op read` for anything in a browser, because `op read` puts the plaintext into the transcript.

**Setup.** Mac, Chrome, the Claude in Chrome extension and the 1Password app and extension, then *Claude desktop → Customize → Connectors → 1Password → Connect* and approve in 1Password. Pairing is per extension instance: a new or reinstalled extension on the driven profile needs pairing again. The tool list is built at session start, so after re-pairing, start a new session. The symptom of a missing pairing is that only `request_credentials` exists and the other credential tools can't be found.

**The sequence that works:**

1. `request_credentials` with `kind`, `keywords`, `goal` and a **`reason` of at most about 98 characters.** A longer `reason` returns `{"status":"invalid","reason":"schema"}`, which looks like a pairing fault and isn't. `reason` is required even where the schema doesn't say so. `website` must be a full URL (`https://www.example.co.uk`, not `example.co.uk`). These fields are shown to the user in 1Password's prompt, which is why they're short.
2. `list_granted_credentials`. Check each item's **subtitle is the user's own account:** the picker matches by domain, and a shared vault can hold a family member's login for the same site. Pass an explicit `credentialId` when there's any doubt.
3. **Bring the right Chrome to the front.** With another app in front, the fill silently does nothing. If a second, automation Chrome is running, `open -a "Google Chrome"` can bring *that* one forward instead, where the fill can't work. Check which process is frontmost before filling.
4. `autofill_credential`. It has **no tab parameter: it fills whichever tab is focused.** Never run it while parallel browser workers are active, because one of them can steal focus mid-call.
5. **Read the page, not the status,** to confirm you're signed in. Then `release_credentials` before the next site.

**What the statuses mean:**

| You see | What happened | Do |
|---|---|---|
| `invalid` / `schema` | Payload too long, usually `reason` | Shorten `reason`; don't re-pair |
| `invalid` / `website` | Bare domain | Use a full `https://` URL |
| `autosubmit_failed` | 1Password filled and submitted, waited 10 s for a navigation, then **cleared the fields again**. So the fields look empty afterwards even though the fill happened. On a site that did navigate, you may already be signed in. | Read the page for the signed-in state. For a JS/reCAPTCHA form that never navigates, arm a page script that clicks the site's real submit button once the username fills, then fill again |
| `agenticModeNotEnabled` (in the Claude app's logs) | A long-running Claude desktop process revokes the grant it just made | **Restart the Claude desktop app.** Check its age before blaming profiles, extensions or pairing |
| `noExistingCredentials` | 1Password found no fillable login for that URL | Check the item really is a password login with a matching URL |
| Refused before 1Password prompts | Claude Code's auto-mode classifier blocked it (an agent-initiated credential request for a site the user never named should be blocked) | Have the user name the site, or add a narrow `autoMode` allow rule; `claude auto-mode critique` checks a rule |

**Single sign-on items.** A login saved as "Sign in with Google" isn't a dead end: requesting it also grants the identity provider's login, and the fill drives the OAuth screen. Completing it signs that Google (or GitHub, Apple) account into the driven Chrome profile, which changes the user's browser. Ask first.

**Two page-inspection traps.** `javascript_tool` redacts any returned key whose *name* contains "password", so rename it (`secretFieldCount`). A custom script run over a page straight after a fill can be blocked as data exfiltration; confirm sign-in with a screenshot or page text instead.

**Useful habit.** A 2FA TOTP seed stored in 1Password makes an account both harder to break into and agent-completable, because autofill fills the code too. A code from a separate authenticator app always needs the user. Passkeys can never be automated, which is exactly why they suit the most important accounts.

## Other sign-in paths

| Method | Agent path |
|---|---|
| Password in 1Password | Agentic autofill, above |
| "Continue with Google/Apple" and the parent account is signed in to this profile | Just click it; OAuth reuses the session, no password involved |
| SMS or email code | `enter_verification_code` (the user types it; the model never sees it) |
| Authenticator-app TOTP not in 1Password | The user types it |
| Passkey | The user's Touch ID, always |
| Email magic link | Only with explicit per-use approval: it is exactly the shape of a phishing link |
| "Forgot password" | Don't. It invalidates the saved item and breaks every future fill |

## The `op` CLI: traps that lose data or give wrong answers

- **Pin the account on every scripted call** (`--account my.1password.com` or your sign-in address). With several accounts signed in, a non-interactive shell may resolve a different default, and you'll draw conclusions about the wrong vault.
- **The CLI can't see passkeys.** They're excluded from `op item get` output and from exports, so "0 passkeys" from the CLI measures the tool, not the vault. Check passkeys in the app.
- **Never pipe a JSON template into `op item edit`.** 1Password's own docs warn it silently overwrites passkeys, and you can't see they're gone. Edit single fields: `op item edit <id> field="value"`.
- **`op item edit` refuses items with a "sign in with" field.** The item is fine; edit it in the app. Those items also show empty username and password in the CLI. `op item list --categories Login --format json` shows them as `"additional_information": "Signs in with Google"`. Find them by field *label*, not by grepping JSON for words you guessed.
- **`op item edit` can only replace the primary URL.** To merge two logins with different URLs, pipe a JSON item with a `urls` array into `op item create` (no `--template`), check it, then `op item delete --archive` the originals.
- **Never `op read` a secret into a prompt or a tool call the model sees.** Read it into the environment of the process that needs it.
