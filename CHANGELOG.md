# Changelog

## 1.0.10 (2026-09-28)
Every item below came out of one attendee's Windows 11 setup (17 ✅ in the end) and was reproduced on the Windows laptop before it was fixed.
- `install-tools.sh`: Claude installs uv, Python 3.13 and Node from inside the Claude Code desktop app; nobody is sent to PowerShell and nothing touches the Microsoft Store. The desktop app is a Store (MSIX) app that redirects writes under `AppData`, and uv 0.12.19 fails there with "Missing expected target directory for Python minor version link"; Python now lives under `%USERPROFILE%\.uv\python` with `UV_PYTHON_INSTALL_DIR` pinned by `setx`. A tool installed mid-session is invisible to the app until it restarts, so the installer asks for that one restart up front instead of the board showing `uv ❌` for no visible reason. Every Python call in the kit is `uv run --no-project --python 3.13 python`; a bare `python3` on a fresh Windows box is the Store shim. The board has a `Python 3.13 (uv)` row.
- The board can tell a real restart from a promised one. `lib/mcp_register.py` stamps `.cache/needs-restart` with the time of each register; `lib/app.sh` reads the app's own start time (walking up from the session process, since a nested Git Bash cannot see past an exited MSYS stub); the checker clears a row only once the app was started after the stamp. Rows used to go green the moment Claude cleared the marker on the attendee's word. The conductor now also has Claude confirm each new server with `session_connectors_status` and use `reconnect_session_connector` on a cold-start `failed`.
- Turno no longer times out on first launch: `uv sync --compile-bytecode` cut its cold start from 13.7 to 4.6 seconds, and it is registered by uv's full path so the app finds it even with a stale PATH. `MCP_TIMEOUT` is documented as the last resort.
- Supabase's MCP server is installed once, pinned at 0.13.0, into `mcp-servers/supabase/` and registered as a direct `node .../dist/cli.js` launch. Through `npx` it re-resolved the package on every start (15 to 18 seconds even with a warm cache) and died at the app's 30 second limit whenever the other servers started with it; direct it is up in under a second.
- RankBreeze name clash: when an older cookie-based stdio `rankbreeze` (first Revenue Manager kit) sits on the name, the board says so instead of "paste it into .env", and the connector says the register line replaces it. The conductor no longer lists `rankbreeze` among servers to reuse as-is.
- Hostfully: the build brief and connector spell out Hostfully's paging (`_limit` default 20, max 100; `_paging._nextCursor` back as `_cursor`; `checkInFrom`/`checkInTo`/`updatedSince`, no `from`/`to`/`offset`), require compact list rows with `get_*` for detail, and make "pull my last 30 days of bookings" the post-restart test (20 rows and no cursor = not paging). A 30-day pull was coming back as one week and `list_properties` was 100k characters.
- Gemini: AI Studio keys made today start with `AQ.`, not `AIza`; the connector, KEYS.md and the guide say so, and the live probe is the judge, not the prefix. Google's page no longer carries a September date; it rejects unrestricted standard keys.
- `fan-out-env.sh` fills only the folders in the attendee's own stack (their PMS, pricing, ops, plus airroi and kie), so a Hostfully shop no longer gets a `hospitable/.env`; it prints what it left alone. `env_discover.py` reports "looked through N folders ... read M env file(s)" instead of "searched 0 env files", which read as a broken search.
- Auto mode blocks: the app's new default permission mode sends every command through Anthropic's safety classifier, and when that check errors out it denies everything, including the very first `git clone` (an attendee got stuck there on 2026-09-28). The guide, README and `connectors/system-claude-code.md` explain the "Blocked / no verdict" message and the switch to Manual (the mode selector next to the send button); the conductor has Claude make that switch itself (`set_session_permission_mode`) instead of retrying into a stopped turn. The zip download is now the first way to get the kit; the paste-a-link clone is second, since it is the first command the classifier sees.
- From the parallel code review: `~/.claude.json` and `.env` are read with `utf-8-sig` (a BOM no longer resets the file), `env_discover` rewrites `.env` once atomically, `supabase_project.py` prints `PENDING:` instead of `REF=` when a project is still provisioning after ten minutes, `sync-bundled-servers.sh` works without rsync, and the Kie server reads its own folder's `.env` first.

## 1.0.9 (2026-09-26)
- Breezeway: the credentials request now says exactly what Breezeway's API team asks for. A summit attendee described the use case as automating guest communications and syncing Breezeway with Hospitable, and Breezeway came back asking which data they needed (guest messaging is not in Breezeway's API at all). The email template, the "Do these today" box in the guide and the request-form answer in the connector now all say the same thing: account holder, read-only, properties, reservations and tasks with status and costs, no people records, no guest messaging, nothing created or changed.
- `emails/breezeway-request.md` also carries a ready reply for anyone who already got Breezeway's "which data do you need" follow-up, and what to say if Breezeway quotes a monthly fee. The connector's troubleshooting section tells Claude to print that reply.
- The Breezeway card said the summit skills "draft new tasks" in Breezeway. They don't: Breezeway is read-only in the kit (write scope decided 2026-09-25). The card says read-only now, and the connector tells Claude to build read tools only, even though the build doc lists Breezeway write tools.
- The Breezeway card told Claude to print the template from `emails/breezeway.md`, a file that does not exist. It points at `emails/breezeway-request.md` now.
- For maintainers only: `scripts/release.sh` does a kit release in one command. It publishes the GitHub release with both zips, deploys the guide page, then checks that the download link and the live page both match the tag. Attendees never run it.

## 1.0.8 (2026-09-26)
- The setup guide carries the STR Secrets AI Summit 2.0 branding (STR Secrets logo and favicon, page title) that the live guide page has shown since Sept 22. It was never committed, so the guide inside the download still said Solnest AI. The downloaded guide, its PDF and the web page now match.

## 1.0.7 (2026-09-26)
- OwnerRez: the build doc and the OwnerRez connector said OwnerRez has no way to read nightly rates, so an OwnerRez server built from them could see bookings but not the attendee's own prices. It can: `GET /v2/calendar/{propertyId}` returns each night's status, rate, min nights and arrival/departure rules (measured live on 8 properties x 90 nights). Both files now say so and name the endpoint.
- Smoobu: the build doc told Claude to connect with Smoobu's old single-key login (`Api-Key`, one variable) and to test it with a curl using that header, which contradicted the Smoobu connector page. A server built from the build doc would stop working when Smoobu switches that login off. The build doc now uses the signed login only (key plus secret, four headers, exactly as the connector page specifies) and says never to use the old one.
- Smoobu's cutoff for the old login is October 31, 2026 (Smoobu's docs, re-read 2026-09-25). The connector page said September 25.

## 1.0.6 (2026-09-22)
- The setup walkthrough video is the first thing on the guide page: a Start here band above the title with the player embedded, a Play button and the plain URL under it (the PDF drops the player and keeps the link). It is also the first section of the README, above the download.
- Support contact is Ryan directly: ryan.lefebvre@strsecrets.com, FB Ryan Lefebvre, IG ryan_le5, in the done message, the README and the guide. The Skool link is gone from the attendee-facing files.
- A vendor's official sign-in row is worked the moment its API row is done, never parked for later. The conductor said both "PMS API, PMS official" and "do this whenever it's convenient, in this pass or later", and the second sentence won often enough that attendees finished setup with the official Hospitable, PriceLabs and Meta connectors never added.
- The done message names each row exactly as the scoreboard printed it ("Hospitable API", then "Hospitable MCP"), instead of rewording it.
- The test suite is hermetic again. `test_bundle.sh` asked the working folder whether a server had a `.env` or a build folder, and `test_scoreboard.sh` copied `.cache` into its fixture, so running the kit for real broke its own tests: 13 failures purely from a completed setup. Both now check what git ships and start from a clean cache.
- Guide version string matches VERSION (it was stuck at 1.0.3).

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
