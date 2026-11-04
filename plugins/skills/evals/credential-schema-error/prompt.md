---
tags: [browser-automation]
max_turns: 8
allowed_tools: [Read, Skill]
---
I'm using Claude in Chrome with the 1Password integration to sign my agent into our supplier portal. Every time the agent calls request_credentials it gets back {"status":"invalid","reason":"schema"}. I've disconnected and re-paired 1Password in Claude twice and it still happens. This is the call it makes:

{"kind":"login","keywords":["supplier portal","acme"],"goal":"Sign in to the Acme supplier portal","website":"https://portal.acme-supplies.com","reason":"The agent needs to sign in to the Acme supplier portal so that it can download this month's invoices and reconcile them against our purchase orders before the finance deadline"}

What's wrong?
