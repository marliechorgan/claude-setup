---
tags: [browser-automation]
max_turns: 8
allowed_tools: [Read, Skill]
---
My agent used 1Password's autofill through Claude in Chrome on a login page. autofill_credential came back with autosubmit_failed, and when the agent then read the page the username and password fields were both empty. So the fill didn't work, right? Should it just retry the autofill a few times?
