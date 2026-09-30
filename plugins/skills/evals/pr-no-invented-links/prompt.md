---
tags: [pr-writing]
runs: 1
max_turns: 12
allowed_tools: [Read, Write, Glob, Grep, Skill]
---
Write the pull request title and description for this change and save it to pr.md. Don't open anything, just the text.

The change: in our CSV export command, if the user passed an empty `--dest` the export used to start, log "export complete" and produce no file. I added a check in `export/cli.py` that rejects an empty destination before the job starts and prints "error: --dest is required". I added `tests/test_cli.py::test_empty_dest_rejected`, which fails on main and passes on this branch. The rest of the test suite passes. I haven't tried it against the S3 destination.
