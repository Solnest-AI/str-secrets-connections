---
server: uplisting
slot: pms
required: one-of
env: [UPLISTING_API_KEY]
official_mcp: https://connect.uplisting.io/mcp
---

# Uplisting: your PMS, the source of truth for listings, bookings and calendar

## 1. What it is
Uplisting is a property management system (channel manager plus booking engine) for short-term rental operators. It is part of AirDNA now. The Revenue Manager skill reads your properties, bookings and calendar through it, so pricing and occupancy work is grounded in your real numbers. There are two ways in: a built connector that uses your API key (Path A), and Uplisting's own hosted MCP that you sign into in the browser (Path B). Set up Path A first. Path B is a nice bonus and takes two minutes.

## 2. Required, cost, gate
One PMS is required for the summit. If Uplisting is yours, this is your file. Skip the other seven `pms-*.md` files.

Cost: nothing extra. Uplisting's pricing page ticks both "Full REST API access" and "MCP server access (for AI agents)" on all three plans. No plan gate, no waitlist, no email to send.

One thing to know: the API key lives on a page called Connect > API. If you do not see it, check section 6.

## 3. Path A: API key
Uplisting's words: "Your API key is generated on the Connect > API page, here." That page is:

https://app.uplisting.io/connect/api

1. Log in to https://app.uplisting.io.
2. In the sidebar, click **Connect**, then the **API** tab (or use the direct link above).
3. Generate a key if there is not one yet. If one is already there, copy it.
4. Copy the whole thing. It is one long string, no spaces. Uplisting's page does not say whether it stays visible after you leave, so copy it now.

Skip the Webhook key on `/connect/webhook`. That is a different key and it will not work here.

Claude has already opened your `.env` file. Find this line and put the key after the equals sign, nothing else on the line, no quotes, no spaces:

```
UPLISTING_API_KEY=
```

Save the file. Never put the key in this chat. If it ends up in the chat by accident, go back to Connect > API, generate a new one, and update the file.

From inside `$BUNDLE`, Claude runs the three checks:

**SAFE:** `if [ -d "$BUNDLE/.git" ]; then git -C "$BUNDLE" check-ignore -q .env && echo "protected ✅" || echo "add .env to $BUNDLE/.gitignore first"; else echo "protected ✅ (not a git folder, nothing can commit it)"; fi`
**FILLED:** `grep -q '^UPLISTING_API_KEY=.\+' .env && echo "present ✅" || echo "still blank"`
**WORKS:** `bash -c '. lib/env.sh; . lib/probes.sh; env_load .env; probe_uplisting; echo rc=$?'` (0 works, 1 rejected, 2 blank, 3 unreachable)

**Build:** there is no pre-built Uplisting server in the bundle. Follow `build/README.md` first, then `build/build-pms-mcp.md` (or `build-pricing-ops-mcp.md`) Steps B1 to B3 only (research, reference doc, write the server code into `$BUNDLE/mcp-servers/uplisting/`). Credentials, registering, fan-out and the restart are done from THIS file, not from the build doc. Run `bash fan-out-env.sh` from `$BUNDLE`: it copies your key from the root `.env` into the server's own `.env` without printing it. The built server sends `Authorization: Basic <base64 of the key alone>` plus `Content-Type: application/json` on every call, which is exactly what Uplisting expects.

**Register (macOS / Linux):**
```bash
test -f "$BUNDLE/mcp-servers/uplisting/dist/index.js" && echo "built ✅" || echo "build missing ❌ (finish build/build-pms-mcp.md Path B first)"
uv run --python 3.13 python "$BUNDLE/lib/mcp_register.py" uplisting --stdio node "$BUNDLE/mcp-servers/uplisting/dist/index.js" && echo "uplisting registered ✅" || echo "register failed ❌"
echo uplisting >> "$BUNDLE/.cache/needs-restart"
```

**Register (Windows, Git Bash):** Claude Code is a native Windows process, so it must be handed a `C:\...` path even though you are typing in Git Bash. Skip the macOS block above on Windows; run this one instead, which converts the path with `cygpath -w` first:
```bash
test -f "$BUNDLE/mcp-servers/uplisting/dist/index.js" && echo "built ✅" || echo "build missing ❌ (finish build/build-pms-mcp.md Path B first)"
uv run --python 3.13 python "$BUNDLE/lib/mcp_register.py" uplisting --stdio node "$(cygpath -w "$BUNDLE/mcp-servers/uplisting/dist/index.js")" && echo "uplisting registered ✅" || echo "register failed ❌"
echo uplisting >> "$BUNDLE/.cache/needs-restart"
```
Re-running either block is safe any number of times; it overwrites the old entry.

If Claude built the server in Python instead of Node (airroi style, a flat `server.py`), the entry is the venv interpreter plus the script: on Mac `"$BUNDLE/mcp-servers/uplisting/.venv/bin/python" "$BUNDLE/mcp-servers/uplisting/server.py"`, on Windows `"$(cygpath -w "$BUNDLE/mcp-servers/uplisting/.venv/Scripts/python.exe")" "$(cygpath -w "$BUNDLE/mcp-servers/uplisting/server.py")"`. Windows venvs put the interpreter under `Scripts`, not `bin`.

Then quit and reopen the Claude Code desktop app. The scoreboard row flips from "restart" to a green check on the next run.

## 4. Path B: official MCP
Uplisting runs its own MCP server, live since August 2026, no beta label, no waitlist, included on every plan (checked 2026-09-21). Uplisting's words: "Use this MCP server URL: https://connect.uplisting.io/mcp When you add the server, you'll be asked to sign in to Uplisting and choose the permissions you want to allow."

**Claude does not register this one. You add it in the app, it takes about a minute.**
1. In the Claude Code desktop app, click the **+** next to the message box, then **Connectors**, then **Manage connectors**. The Connectors settings page opens.
2. Click **+ Add** (top right), then **Add custom connector**.
3. Type a name (Uplisting is fine) and paste `https://connect.uplisting.io/mcp` into **MCP server URL**. Click **Continue**.
4. A browser tab opens.
5. Done, it is on automatically. Come back and tell Claude "connected".

What to expect in the browser: an Uplisting sign-in. The login page may carry AirDNA branding (Uplisting is part of AirDNA); use your normal Uplisting login. After that comes a permissions picker. Uplisting's list: "properties:read, bookings:read, bookings:create, bookings:update, calendar:read, calendar:write, messaging:read, messaging:write, reviews:read". Uplisting's words: "You do not need to grant every permission."

Our advice for the summit: tick only the five `:read` ones (properties, bookings, calendar, messaging, reviews). That is everything the Revenue Manager skill needs.

**Heads up:** if you grant `bookings:create`, `bookings:update`, `calendar:write` or `messaging:write`, this connection can create or change bookings, block or open dates, and send real messages to guests. Claude will always ask before any of that. Grant reads only if you want zero chance of it.

Claude runs the live check right after: "List my Uplisting properties." An answer means it is working. If the tool is not available in the session, say: "I don't see Uplisting in my tools yet. Check it shows connected under + > Connectors, or that Connect finished in the browser."

Want to change your picks later? Remove the connector under + > Connectors > Manage connectors, then add it again; the permissions picker comes back on the next sign-in.

Path B does not replace Path A. The checker's Path A row still runs for real, and the Revenue Manager skill talks to the built `uplisting` server.

## 5. Verify
`bash check-connections.sh` prints two Uplisting rows.

**Uplisting API** (Path A). The checker runs `probe_uplisting`, which base64-encodes your key at run time (the key alone, no colon, trailing newline stripped) and calls `GET https://connect.uplisting.io/users/me` with `Authorization: Basic <that>` and `Content-Type: application/json`. Nothing about the key is printed.
- **HTTP 200:** rc 0. The key works. If the `uplisting` server is registered and connected, the row is green. If you just registered it, the row says restart until you do.
- **HTTP 401** with Uplisting's message `Your API key does not appear to be valid`: rc 1. The row says re-check the line in `.env`.
- **rc 2:** the line is blank. Paste the key into the file and save.
- **rc 3:** no answer from `connect.uplisting.io` in 15 seconds. Network, VPN or a firewall. Try again.
- Key works but the row says "server not registered yet": run the Register block for your OS in section 3.

**Uplisting MCP (official)** (Path B). This one never shows up in `~/.claude.json`, the app delivers it straight to the chat session, so the checker cannot see it. The row always prints `🔎 Uplisting MCP (official)   add it under + > Connectors; Claude checks it live`. Not added yet: run section 4. Added: Claude runs the live check ("List my Uplisting properties") in the chat.

## 6. Troubleshooting
- **401 `Your API key does not appear to be valid`:** three usual causes. (1) A stray space or newline came along when you copied. Open `.env`, retype the line clean, save, re-run. (2) You tested by hand and encoded it as `key:` with a colon, the usual Basic auth shape. Uplisting's words: "Encode the key on its own, not in the usual key:password format." (3) You generated a new key at Uplisting after pasting the old one. Paste the current one.
- **Testing by hand and it fails while the checker passes:** Uplisting's words: "Check for a trailing newline if you generated the encoding on the command line." `echo "$KEY" | base64` adds a newline and breaks it. The probe uses `printf '%s'` and strips newlines. Do the same, or just trust the checker.
- **No Connect > API in your sidebar:** the API page is an account-level setting. Make sure you are logged in as the account owner, not a team member. Uplisting's docs do not spell out who can see it, so if the owner cannot see it either, ask Uplisting support from inside the app.
- **Requests start failing during a big pull:** Uplisting allows about 5 requests a second per IP. The built server backs off and retries on a 429. If something else is hitting the API from the same connection at the same time, stop that, wait a few seconds, re-run.
- **MCP sign-in bounces to an AirDNA page:** expected. Uplisting is part of AirDNA and the login runs through it. Use your Uplisting credentials. If it loops, remove the connector under + > Connectors > Manage connectors and add it again.
- **The register step reports success but the row says `server status: failed` after the restart:** that is the Path A `uplisting` server, not the official MCP. The build did not finish; registering does not check that the file exists. Go back to `build/build-pms-mcp.md` Path B until `dist/index.js` (or `server.py` plus `.venv`) exists, then re-run the Register block for your OS.
- **Windows: `uplisting` shows Failed to connect after restart:** the path was registered in `/c/Users/...` form. Run the Register (Windows, Git Bash) block in section 3 again; it overwrites the old entry with the `cygpath -w` form.
- **Windows and the server is Python:** the interpreter is `.venv/Scripts/python.exe`, not `.venv/bin/python`. See the Register (Windows, Git Bash) block in section 3.

## 7. Sources
support.uplisting.io articles "Uplisting MCP server" (uplisting-mcp-server-silb1i, article updated 07/08/2026) and "API & webhooks" (api-webhooks-vzlowi); app.uplisting.io/connect/api (key page); uplisting.io pricing page (REST API and MCP on all plans); documenter.getpostman.com/view/1320372/SWTBfdW6 (API reference); connect.uplisting.io/.well-known (OAuth discovery). All read 2026-09-21.
