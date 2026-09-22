---
server: pricelabs
slot: pricing
required: one-of
env: [PRICELABS_API_KEY, PRICELABS_MCP_CLIENT_ID, PRICELABS_MCP_CLIENT_SECRET]
official_mcp: https://mcp.pricelabs.co/mcp
---

# PriceLabs: the pricing brain behind your nightly rates

## 1. What it is
PriceLabs sets your nightly prices. The Revenue Manager skill reads your listings, the prices PriceLabs recommends, your min / base / max, your overrides, neighborhood data and reservations, then talks you through what to change. Two ways in, and you can have both. Heads up: the API key is read AND write. The bundled server can set, change and delete price overrides and edit listing settings on your live account. The summit skills ask you before every write, but the key itself has no brake, so treat it like a bank password: it goes in .env and nowhere else.

- **`pricelabs`** (bundled, Path A): a small server that ships in this folder and uses your PriceLabs API key. This is the one the summit skills lean on.
- **`pricelabs-official`** (Path B): PriceLabs' own MCP. Beta, free for now, signs in through the browser. Nice to have, not needed for the summit.

`$BUNDLE` below is the absolute path of this unzipped folder. Claude set it in Phase 0.

## 2. Required, cost, gate
One pricing tool is required: PriceLabs or Beyond. If you price with PriceLabs, this is your file.

**Cost.** PriceLabs bills the API: "We charge $1 per listing per month (plus applicable taxes) for each listing that syncs prices during a billing month." That is PriceLabs charging you, not us. Ten listings that sync prices is about $10 a month. The official MCP (Path B) is in beta: "Enjoy complimentary access for a limited time" (read 2026-09-21).

**Gate.** Self serve for the account owner. Team member on someone else's account? PriceLabs says "Only the account owner can enable or revoke API access for team members," so ask the owner to turn on Customer API access for your login first. Once they have, you do section 3 yourself and get your own key on your own API Details page. Use your own key, not the owner's. If the Enable button throws an error, email support@pricelabs.co with `emails/pricelabs-enable-api.md` and mark it pending:
```bash
echo "pricelabs|$(date +%F)" >> "$BUNDLE/.cache/pending-vendor"
```
Path B's Claude Code route has a second gate: "Only the account admin (superadmin) can create, regenerate, or delete custom clients." Not the admin? Skip that part.

## 3. Path A: API key
Direct link: https://app.pricelabs.co/account_settings?tab=api_details

PriceLabs' own steps: "1. Go to Account Settings. 2. Click API Details. 3. Click Enable. 4. Select I Need API Access. 5. Enter API in the confirmation field, then click Continue." So: **Account Settings** > **API Details** > **Enable** > pick **I Need API Access** > type `API` in the box > **Continue**.

The key shows up on that same page. Hit **Copy API Key**. It is not a one-time reveal; you can come back and copy it again whenever. **Regenerate API Key** makes a new one, so assume the old one stops working if you press it.

Drop it on this line in `.env` (Claude opens the file for you; never type the key into the chat):
```
PRICELABS_API_KEY=
```
Save, tell Claude "saved", then push it out to the bundled server (it reads its own `.env` inside `mcp-servers/pricelabs/`):
```bash
cd "$BUNDLE" && bash fan-out-env.sh
```

**SAFE:** `if [ -d "$BUNDLE/.git" ]; then git -C "$BUNDLE" check-ignore -q .env && echo "protected ✅" || echo "add .env to $BUNDLE/.gitignore first"; else echo "protected ✅ (not a git folder, nothing can commit it)"; fi`
**FILLED:** `grep -q '^PRICELABS_API_KEY=.\+' "$BUNDLE/.env" && echo "present ✅" || echo "still blank"`
**WORKS:** `cd "$BUNDLE" && bash -c '. lib/env.sh; . lib/probes.sh; env_load .env; probe_pricelabs; echo rc=$?'` (0 works, 1 rejected, 2 blank, 3 unreachable)

**Register** (build first, one time):
```bash
cd "$BUNDLE/mcp-servers/pricelabs" && npm ci --silent && npm run build --silent
uv run --python 3.13 python "$BUNDLE/lib/mcp_register.py" pricelabs --stdio node "$BUNDLE/mcp-servers/pricelabs/dist/index.js" && echo "pricelabs registered ✅" || echo "pricelabs failed ❌"
echo pricelabs >> "$BUNDLE/.cache/needs-restart"
```

**Windows note.** Run all of this in Git Bash (that is what Claude's Bash tool is on Windows). Claude Code itself is a native Windows program, so the path handed to the register helper has to be the `C:\...` form. Convert it with `cygpath -w` and register that instead:
```bash
uv run --python 3.13 python "$BUNDLE/lib/mcp_register.py" pricelabs --stdio node "$(cygpath -w "$BUNDLE/mcp-servers/pricelabs/dist/index.js")" && echo "pricelabs registered ✅" || echo "pricelabs failed ❌"
```
This server runs on Node, so there is no venv here. For the Python servers in this kit the Windows interpreter is `.venv/Scripts/python.exe`, never `.venv/bin/python`.

Then quit and reopen the Claude Code desktop app. The checker will tell you when.

## 4. Path B: official MCP
Beta, free for now: "The PriceLabs MCP is currently in beta. Enjoy complimentary access for a limited time" (developers.pricelabs.co/mcp/overview, read 2026-09-21).

Team member on a sub-login? You won't see the AI Connector (MCP) tab until the account admin turns on MCP access for you under Team Settings. Ask them first if the tab is missing.

PriceLabs side: "1. Navigate to Account Settings. 2. Select the AI Connector (MCP) tab. 3. Copy your MCP URL and Client ID."

**Claude does not register this one. You add it in the app, it takes about a minute.**
1. In the Claude Code desktop app, click the **+** next to the message box, then **Connectors**, then **Manage connectors**. The Connectors settings page opens.
2. Click **+ Add** (top right), then **Add custom connector**.
3. Type a name (PriceLabs is fine) and paste `https://mcp.pricelabs.co/mcp` into **MCP server URL**. Click **Continue**. If the next screen asks for OAuth details, use the Client ID and Client Secret from the custom client you made in PriceLabs (see below), or PriceLabs' shared Client ID `KgPnRwJhQpQx0sbK20aLlat8pRoShmMMSajQbYvQl7w` (PriceLabs' own public ID for Claude, printed on their docs page; it is not a secret) with the secret left blank. If it never asks, carry on, the sign-in alone may be enough.
4. A browser tab opens. Sign in to PriceLabs and approve. It asks for **Read access**, **Write access** and **Customization write access**, "each granted on its own." Read is enough.
5. Done, it is on automatically. Come back and tell Claude "connected".

"PriceLabs MCP tools will only appear in new conversations," so open a fresh chat if Claude doesn't see them right away.

Claude runs the live check right after: "List my PriceLabs listings." An answer means it is working. If the tool is not available in the session, say: "I don't see PriceLabs in my tools yet. Check it shows connected under + > Connectors, that Connect finished in the browser, or open a new chat."

**Want your own client instead of PriceLabs' shared one (account admin only)?** "Only the account admin (superadmin) can create, regenerate, or delete custom clients." PriceLabs side: Account Settings > AI Connector (MCP) > **Custom Connectors** > **+ Add Custom Connector** > Name it `Claude Code`. "PriceLabs will generate a Client ID and Client Secret and display them once." Copy both straight into `.env`, no chat:
```
PRICELABS_MCP_CLIENT_ID=
PRICELABS_MCP_CLIENT_SECRET=
```
Save, tell Claude "saved". Use those two values in step 3 above instead of the shared Client ID, if the add-connector screen asks for OAuth details.

Limits from PriceLabs: "Each account can have up to 3 custom clients." "Regenerating credentials immediately revokes all active connections." The Client ID and Secret are shown once; lose them and you regenerate.

## 5. Verify
Run `bash check-connections.sh` from the kit folder. For PriceLabs it makes one real call: `GET https://api.pricelabs.co/v1/listings_minimal` with your key in the `X-API-Key` header.

- `✅ PriceLabs API  connected`: the call came back 200 and the `pricelabs` server is registered. Done.
- `❌ PriceLabs API  missing`: the `.env` line is blank, or the key works but the server is not registered yet. The hint on the row says which.
- `⚠️ PriceLabs API  registered, key fails`: PriceLabs answered **403 with `API_KEY_INVALID`**. Their words: "A 403 with API_KEY_INVALID means the header is missing or the key is wrong." PriceLabs uses 403 for a bad key, not 401, so it's not a permissions problem even though it looks like one. Re-copy the key.
- `🔒 needs a full restart of Claude Code`: you just registered it. Quit, reopen in this folder, run the check again.

`PriceLabs MCP (official, beta)` row: this one never shows up in `~/.claude.json`, the app delivers it straight to the chat session, so the checker cannot see it. The row always prints `🔎 PriceLabs MCP (official, beta)   add it under + > Connectors; Claude checks it live`, whether or not you have added it yet. Not added, or skipped on purpose: Path A is the one the summit skills need. Added: Claude runs the live check ("List my PriceLabs listings") in the chat.

## 6. Troubleshooting
- **Enable button errors out or no key appears:** email support@pricelabs.co (template `emails/pricelabs-enable-api.md`), mark pending with the line in section 2, keep going with the other connectors. When they say done, the key is at the same API Details page.
- **403 `API_KEY_INVALID`:** wrong key or the header never got sent. Open `.env`, check the line reads `PRICELABS_API_KEY=` followed by the key with no quotes and no spaces, re-copy from API Details, save, run `cd "$BUNDLE" && bash fan-out-env.sh` again.
- **Key works in the check but the server says the key is missing:** you skipped `fan-out-env.sh`. The bundled server reads `mcp-servers/pricelabs/.env`, not the root one.
- **Rate limited:** PriceLabs allows "60 requests per minute" and "1,000 requests per hour" per key. Wait a minute and retry. The Revenue Manager paces itself; a big backfill can still bump into the hourly cap.
- **Hospitable listings show `pms: smartbnb`:** that is Hospitable's old name inside PriceLabs. When a tool asks for `pms`, pass `smartbnb` for Hospitable listings.
- **`ERR-MCP-FEATURE-NOT-ENABLED` on a market or neighborhood tool:** that feature is switched off for your account. Ask support@pricelabs.co to enable it.
- **Official MCP tools do not show up (Desktop path):** they only appear in new conversations. Start a fresh chat.
- **Want to change Read / Write grants later:** PriceLabs says disconnect first in Account Settings > AI Connector (MCP), then reconnect and pick again.
- **Custom client refuses to add:** you are at the limit of 3 custom clients, or you are not the account admin. Delete an old one or hand this step to the admin.
- **Connect loops or never comes back:** remove the connector under + > Connectors > Manage connectors and add it again, double-check the URL and (if asked) the Client ID/Secret fields. If it still fails, move on, the summit does not depend on Path B: Path A (the built `pricelabs` server) is what the skills use.
- **Windows: `pricelabs` shows Failed to connect after restart:** it was registered with a `/c/Users/...` path. Re-run the Windows register line in section 3; it overwrites the old entry with the `cygpath -w` form.

## 7. Sources
developers.pricelabs.co/customer-api/api-reference/enable-the-api, developers.pricelabs.co/customer-api/quick-start, developers.pricelabs.co/mcp/overview, developers.pricelabs.co/mcp/connectors/connect-to-claude, developers.pricelabs.co/mcp/connectors/custom-clients, developers.pricelabs.co/llms.txt (all read 2026-09-21).
