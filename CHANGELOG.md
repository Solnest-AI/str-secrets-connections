# Changelog

## 1.0.6 (2026-09-22)
- Demo mode. `lib/env_discover.py --no-discover` turns the key search off for the kit folder (a marker in `.cache/no-discover`); every later run of the helper stops with "discovery is off" and copies nothing, so a walkthrough recorded on a machine that already holds the keys still shows every paste. `--discover` turns it back on. The scoreboard says "demo mode" on its first lines while it is on, and `CONNECTIONS.md` tells Claude to skip the search and the "let me find it" reflex. It only silences the search: servers already registered in `~/.claude.json` still count on the board.
- Test suite: the two "no claude binary" cases now really run without one. On a Mac the minimal PATH they build keeps Homebrew's python dir, which also holds the npm-global `claude`, so the config-reading fallback was never exercised and both cases failed. `SSC_NO_CLAUDE_BIN=1` (tests only) makes `lib/mcp.sh` act as if no binary exists.

## 1.0.5 (2026-09-22)
- Fixed a key leak in `lib/env_discover.py`: a registered server whose argument was a package name with a slash in it (`@supabase/mcp-server-supabase@latest`) was treated as a file path, so the search walked the current folder and its parents and read whatever `.env` sat there, attributing it to that server. Only absolute paths count now, the home folder and the kit's own `.env` are never read that way, and a regression test puts a sentinel `.env` in the working folder and asserts it stays out.
- A key found in `~/.env` is reported under its own path, not as some unrelated server's ("secondbrain-vault -> .env" is gone). Each `.env` file is counted once in the "searched N files" line.
- Sign-in rows (Hospitable, Lodgify, Uplisting, Beyond, PriceLabs and IntelliHost official MCPs, Meta Ads) turn ✅ once their live check has passed: Claude records it in `.cache/live-ok` with the date, the row shows it, and "recheck <server>" runs it again. The board can now go fully green; the done message lists any sign-in still waiting.
- `mcp_register.py` is silent on a successful register; the connector files' own "registered ✅" line was printing right after it, so it showed twice.
- Meta's live check searches the Ad Library with limit 3 and says up front that one hit can be unrelated (the match is loose on Meta's side).
- `connectors/ai-gemini.md` no longer says the Listing Optimizer path is filled in Phase 0; that happens on summit morning when the skill is handed out.

## 1.0.4 (2026-09-22)
- The generated `.env` lists only what the attendee pastes; the lines Claude fills (TURNO_ENV, the two Supabase lines) sit in their own block at the bottom, and the count Claude reports matches.
- No more "where do your other skills live" question: the four summit skills are handed out on summit morning and wired up together then.
- Section headers no longer say "fill ONLY the one you use" (there is only one to see).

## 1.0.3 (2026-09-22)
- Claude opens with a welcome and a short "here's what happens next" before running anything (one line on re-runs).
- Guide and README download link now point at the latest release, so kit updates no longer need a guide rebuild.

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
