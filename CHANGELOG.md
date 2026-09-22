# Changelog

## 1.0.2 (2026-09-22)
- The four stack questions come first. `lib/env_make.py` then builds a `.env` with only the slots that apply (one PMS, one pricing tool, ranking and ops only if used, plus the required keys), answers pre-filled. Re-running with new answers keeps every existing value.
- Before asking for any key, `lib/env_discover.py` searches the computer for keys the attendee already has (other Solnest kits' `.env` files, registered MCP servers in `~/.claude.json`, the Claude Desktop config) and copies them in; names only, never values. "I already have that" now means Claude goes and looks.
- Scoreboard hints name the real connector file (they used to glue the server name into a path that did not exist).
- Every guide card has a verified link to the vendor page and step-by-step instructions.

## 1.0.1 (2026-09-22)
- Sign-in servers (Meta Ads, Hospitable, Lodgify, Uplisting, Beyond, PriceLabs, IntelliHost official MCPs) are now added in the Claude Code desktop app under + > Connectors > Manage connectors > + Add > Add custom connector, and Claude checks them live in the chat. No more /mcp step, no more claude CLI for PriceLabs.
- Guide: Max 5x plan note, paste-the-GitHub-link install path, email items first, URL-only directory table, direct help email.

## 1.0.0 (2026-09-22)
- First release for the STR Secrets AI Summit 2.0 (Sept 29-30, 2026).
