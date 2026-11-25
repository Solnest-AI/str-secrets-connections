# STR Secrets Connections

When the user says "Set up my connections", "Check my connections", or "Update my connections" (or anything close), open `CONNECTIONS.md` in this folder and follow it exactly, one step per message. Do not improvise a different setup path. Never ask for a key in the chat.

Never commit, push, fork, open a pull request or create a GitHub repo for this folder. It is the user's own copy of the kit, not a project, and "save" means the files on disk (already saved). A `git clone` of the kit links it to Solnest-AI's GitHub: `bash lib/detach_from_github.sh` removes that link, and setup runs it first.

## Your own changes (read first, every time)

Before anything else, read `~/.solnest/connections/my-instructions.md` if it exists and
follow it. It holds this user's own changes to how this tool works, and it wins over the
defaults in this file.

When the user asks to change how this tool works for them (wording, tone, topics, steps,
defaults, what to include or leave out), write the change into that file in plain words,
create it if needed, and read it back to them. **Never edit this tool's own files for
that.** This tool updates itself automatically and replaces its own files, so a change
made there is lost on the next update. Their keys (`.env`, and each server's own `.env` under `mcp-servers/`), `.cache/`, any server Claude built for them, and the servers registered in Claude Code are never touched by an update either.
