---
server: lodgify
slot: pms
required: one-of
env: [LODGIFY_API_KEY]
official_mcp: https://mcp.lodgify.com/mcp
---

# Lodgify: your PMS, wired into the Revenue Manager

## 1. What it is
Lodgify is your property management system: the place your listings, calendar, rates and bookings live. The Revenue Manager skill reads your properties, bookings and rate calendar through it, and pushes rate changes back (only after you approve each one). Two ways in. Path A is your Public API key running a small server Claude builds on your machine (reads and writes). Path B is Lodgify's own hosted MCP (read-only, beta). Do Path A. Add Path B if you want it.

## 2. Required, cost, gate
One PMS is required for the summit, and this is the file if yours is Lodgify. Lodgify does not charge extra for the API, but it is plan-gated: their pricing table lists the API endpoint as included on Starter, Professional and Ultimate, and not included on Basic. On Basic, Path A will not work (Lodgify has not published what the Public API page shows on that plan, so it may be missing, locked, or present with a key the API rejects). Upgrade, or use Path B. The official MCP (Path B) has no plan gate, in Lodgify's words: "You can use this connection with any of our subscription plans." It does need a paid Claude subscription, which you already have for Claude Code. No email to any vendor for this one.

## 3. Path A: API key
Lodgify's own steps:

1. Go to your left-hand menu and select Settings.
2. Select Public API.
3. Your API key will be displayed there. Use the copy function.

Direct link: https://app.lodgify.com/#/reservation/settings/publicApiToken

The key is displayed on that page every time (not shown-once), so you can come back for it. One key does everything, per Lodgify: "This key has both read and write permissions." Treat it like a password.

Claude opens `.env` for you. Put the key on this line, no quotes, no spaces:
```
LODGIFY_API_KEY=
```
Save the file, then tell Claude "saved". The key never goes in the chat.

**SAFE:** `if [ -d "$BUNDLE/.git" ]; then git -C "$BUNDLE" check-ignore -q .env && echo "protected ✅" || echo "add .env to $BUNDLE/.gitignore first"; else echo "protected ✅ (not a git folder, nothing can commit it)"; fi`
**FILLED:** `grep -q '^LODGIFY_API_KEY=.\+' .env && echo "present ✅" || echo "still blank"`
**WORKS:** `bash -c '. lib/env.sh; . lib/probes.sh; env_load .env; probe_lodgify; echo rc=$?'` (0 works, 1 rejected, 2 blank, 3 unreachable)

**Build:** there is no pre-built Lodgify server. Follow `build/README.md` first, then `build/build-pms-mcp.md` (or `build-pricing-ops-mcp.md`) Steps B1 to B3 only (research, reference doc, write the server code into `$BUNDLE/mcp-servers/lodgify/`). Credentials, registering, fan-out and the restart are done from THIS file, not from the build doc. TypeScript is the default, so it lands with entry `dist/index.js` and reads `LODGIFY_API_KEY` from its own `.env`. That folder did not exist when the root `.env` was filled, so after the build finishes Claude runs `cd "$BUNDLE" && bash fan-out-env.sh` once more before registering; skip that and the server starts with a blank key. Every write tool in it asks before it touches a rate.

**Register:**
```bash
uv run --python 3.13 python "$BUNDLE/lib/mcp_register.py" lodgify --stdio node "$BUNDLE/mcp-servers/lodgify/dist/index.js" && echo "lodgify registered ✅" || echo "register failed ❌"
echo lodgify >> "$BUNDLE/.cache/needs-restart"
```
**Windows:** run this under Git Bash (that is what Claude's Bash tool is). Claude Code is a native Windows program and needs a `C:\...` path, so convert first and register the converted one: `BUNDLE_WIN="$(cygpath -w "$BUNDLE")"`, then use `"$BUNDLE_WIN\mcp-servers\lodgify\dist\index.js"` in place of the `$BUNDLE` path above. If Claude built the server in Python instead of Node, the interpreter is `.venv/Scripts/python.exe` on Windows (`.venv/bin/python` on Mac) and the entry is `server.py`; same `cygpath -w` rule for both paths.

Then quit and reopen the Claude Code desktop app when the checker tells you to.

## 4. Path B: official MCP
Live beta as of 2026-09-21. Lodgify's article is "Connect Claude and ChatGPT to the Lodgify MCP manually (BETA)" (help.lodgify.com, article 30326689780636). Read-only, in their words: "The AI can only read your data; it cannot make changes to your account." So this one answers questions; rate pushes still go through Path A. Requirements from the article: "Have an active Lodgify account. Have a paid Claude or ChatGPT subscription". Any Lodgify plan works.

**Claude does not register this one. You add it in the app, it takes about a minute.**
1. In the Claude Code desktop app, click the **+** next to the message box, then **Connectors**, then **Manage connectors**. The Connectors settings page opens.
2. Click **+ Add** (top right), then **Add custom connector**.
3. Type a name (Lodgify is fine) and paste `https://mcp.lodgify.com/mcp` into **MCP server URL**. Click **Continue**. If the next screen asks for OAuth details, use `lodgify.mcp` as the Client ID, no secret. That matches Lodgify's own instruction: "Client ID: lodgify.mcp; OAuth client secret: Leave this field blank." If it never asks, carry on, the sign-in alone may be enough.
4. A browser tab opens. Sign in to Lodgify and approve.
5. Done, it is on automatically. Come back and tell Claude "connected".

Claude runs the live check right after: "List my Lodgify properties." An answer means it is working. If the tool is not available in the session, say: "I don't see Lodgify in my tools yet. Check it shows connected under + > Connectors, or that Connect finished in the browser."

## 5. Verify
**Path A.** The checker runs `probe_lodgify`: one `GET https://api.lodgify.com/v2/properties` with your key in the `X-ApiKey` header (the header Lodgify documents: "include it in the API request in an HTTP header named X-ApiKey"). What comes back:
- `200` with your properties: pass, rc 0. Row shows ✅.
- `403` with an empty body: Lodgify's answer to a wrong key (verified live, no error message, just nothing). rc 1. Row says re-check the line in `.env` (and, if a fresh copy still fails, your plan: section 6).
- rc 2: the line is blank. rc 3: Lodgify unreachable; try again in a minute.

Then it reads the `lodgify` server's status from Claude Code (it never prints the raw list). Connected = ✅. If you just registered, the row says restart until you do.

**Path B.** This one never shows up in `~/.claude.json`, the app delivers it straight to the chat session, so the checker cannot see it. The row always prints `🔎 Lodgify MCP (official, beta)   add it under + > Connectors; Claude checks it live`. Not added yet: run section 4. Added: Claude runs the live check ("List my Lodgify properties") in the chat.

## 6. Troubleshooting
- **No "Public API" under Settings, or the page is there but locked:** most likely your plan does not include the API. Lodgify's pricing table: API endpoint included on Starter, Professional, Ultimate; not on Basic. Check your plan under Settings > Subscription first; if you are on Starter or above and the page is still missing, ask Lodgify support. Otherwise upgrade, or use Path B for now.
- **`403` and nothing else:** wrong key, or a plan without API access. Lodgify sends an empty body either way, not a message. First open `.env`, check the `LODGIFY_API_KEY=` line: whole key, no quotes, no spaces, nothing else on the line, and copy it fresh from the Public API page. If a freshly copied key still gets `403`, it is the plan: see the first bullet above and use Path B until you upgrade.
- **`429`:** rate limit. Lodgify's absolute limits are 600 requests per minute on v1 and 750 per minute on v2. Wait a minute and retry.
- **Path B browser step never finishes:** re-check the OAuth Client ID field has exactly `lodgify.mcp`, no extra spaces, and the secret field is blank. Remove the connector under + > Connectors and add it again.
- **Path B connected but Claude says it cannot change rates:** by design. The official MCP is read-only. Rate pushes go through the built `lodgify` server from Path A.
- **docs.lodgify.com refuses you from the terminal:** the docs site blocks curl. Open it in a browser.
- **v1 vs v2:** Lodgify runs both API versions side by side on the same host, and the two return different shapes. The built server picks the right version per call; if you extend it, keep the two separate.

## 7. Sources
- help.lodgify.com article 360010182700 (API key click path) and article 30326689780636 "Connect Claude and ChatGPT to the Lodgify MCP manually (BETA)", both read 2026-09-21.
- docs.lodgify.com: getting-started, authorization (the X-ApiKey header), rate-limits (600/min v1, 750/min v2, 429 on exceed), read 2026-09-21.
- lodgify.com pricing table (API endpoint: Basic not included; Starter, Professional, Ultimate included) and lodgify.com/ai, read 2026-09-21.
- Live probes 2026-09-21: mcp.lodgify.com/ returns 404, GET /mcp returns 405 (POST only), no /.well-known/oauth-authorization-server; a wrong key on GET /v2/properties returns 403 with an empty body.
