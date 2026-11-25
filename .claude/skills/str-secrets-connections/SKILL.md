---
name: str-secrets-connections
description: Set up or check every connection the STR Secrets summit skills need. Trigger on "set up my connections", "check my connections", "update my connections".
---

## Your own changes (read first, every time)

Before anything else, read `~/.solnest/connections/my-instructions.md` if it exists and
follow it. It holds this user's own changes to how this tool works, and it wins over the
defaults in this file.

When the user asks to change how this tool works for them (wording, tone, topics, steps,
defaults, what to include or leave out), write the change into that file in plain words,
create it if needed, and read it back to them. **Never edit this tool's own files for
that.** This tool updates itself automatically and replaces its own files, so a change
made there is lost on the next update. Their keys (`.env`, and each server's own `.env` under `mcp-servers/`), `.cache/`, any server Claude built for them, and the servers registered in Claude Code are never touched by an update either.

Read `../../../CONNECTIONS.md` (the repo root) and follow it exactly.
