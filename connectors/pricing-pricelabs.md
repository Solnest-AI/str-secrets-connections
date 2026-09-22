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

**Gate.** Self serve for the account owner. Team member on someone else's account? PriceLabs says "Only the account owner can enable or revoke API access for team members," so ask the owner to turn on Customer API access for your login first. Once they have, you do section 3 yourself and get your own key on your own API Details page. Do not use the owner's key. If the Enable button throws an error, email support@pricelabs.co with `emails/pricelabs-enable-api.md` and mark it pending:
```bash
echo "pricelabs|$(date +%F)" >> "$BUNDLE/.cache/pending-vendor"
```
Path B's Claude Code route has a second gate: "Only the account admin (superadmin) can create, regenerate, or delete custom clients." Not the admin? Skip that part.

## 3. Path A: API key
Direct link: https://app.pricelabs.co/account_settings?tab=api_details

PriceLabs' own steps: "1. Go to Account Settings 2. Click API Details 3. Click Enable 4. Select I Need API Access 5. Enter API in the confirmation field, then click Continue". So: **Account Settings** > **API Details** > **Enable** > pick **I Need API Access** > type `API` in the box > **Continue**.

The key shows up on that same page. Hit **Copy API Key**. It is not a one-time reveal; you can come back and copy it again whenever. **Regenerate API Key** makes a new one, so assume the old one stops working if you press it.

Drop it on this line in `.env` (Claude opens the file for you; never type the key into the chat):
```
PRICELABS_API_KEY=
```
Save, tell Claude "saved", then push it out to the bundled server (it reads its own `.env` inside `mcp-servers/pricelabs/`):
```bash
cd "$BUNDLE" && bash fan-out-env.sh
```

**SAFE:** `cd "$BUNDLE" && { git check-ignore -q .env 2>/dev/null || grep -qx '.env' .gitignore; } && echo "protected ✅"`
**FILLED:** `grep -q '^PRICELABS_API_KEY=.\+' "$BUNDLE/.env" && echo "present ✅" || echo "still blank"`
**WORKS:** `cd "$BUNDLE" && bash -c '. lib/env.sh; . lib/probes.sh; env_load .env; probe_pricelabs; echo rc=$?'` (0 works, 1 rejected, 2 blank, 3 unreachable)

**Register** (build first, one time):
```bash
cd "$BUNDLE/mcp-servers/pricelabs" && npm ci --silent && npm run build --silent
claude mcp add --transport stdio pricelabs --scope user -- node "$BUNDLE/mcp-servers/pricelabs/dist/index.js" >/dev/null 2>&1 && echo "pricelabs registered ✅"
echo pricelabs >> "$BUNDLE/.cache/needs-restart"
```

**Windows note.** Run all of this in Git Bash (that is what Claude's Bash tool is on Windows). Claude Code itself is a native Windows program, so the path you hand `claude mcp add` has to be the `C:\...` form. Convert it with `cygpath -w` and register that instead:
```bash
claude mcp add --transport stdio pricelabs --scope user -- node "$(cygpath -w "$BUNDLE/mcp-servers/pricelabs/dist/index.js")" >/dev/null 2>&1 && echo "pricelabs registered ✅"
```
This server runs on Node, so there is no venv here. For the Python servers in this kit the Windows interpreter is `.venv/Scripts/python.exe`, never `.venv/bin/python`.

Then a full restart of Claude Code (quit and reopen in this folder). The checker will tell you when.

## 4. Path B: official MCP
Beta, free for now: "The PriceLabs MCP is currently in beta. Enjoy complimentary access for a limited time" (developers.pricelabs.co/mcp/overview, read 2026-09-21). PriceLabs documents two ways in. Do the simple one; do the Claude Code one only if you are the account admin, and do it last.

**Simple: Claude Desktop or the claude.ai app (no custom client).**
PriceLabs side: "1. Navigate to Account Settings. 2. Select the AI Connector (MCP) tab. 3. Copy your MCP URL and Client ID."
Claude side: **Connectors** > the **+** button > **Add custom connector**, then:

| Field | Value |
|---|---|
| Name | `PriceLabs MCP` |
| URL | `https://mcp.pricelabs.co/mcp` |
| Client ID | `KgPnRwJhQpQx0sbK20aLlat8pRoShmMMSajQbYvQl7w` (under **Advanced settings**) |

That Client ID is PriceLabs' shared public one for Claude, printed on their docs page; it is not a secret. **Add** > **Connect** > sign in to PriceLabs in the browser > it asks for **Read access**, **Write access** and **Customization write access**. "Each is granted on its own." Read is enough. Then: "PriceLabs MCP tools will only appear in new conversations," so open a fresh chat.

Heads up: this lives in the Claude app, not in Claude Code, so the checker's official row will still say not registered. That is fine. The summit skills run on the bundled `pricelabs` server from Path A.

**Claude Code CLI (account admin only; the most fragile step in this kit; skip if you are not the admin).**
PriceLabs side: "Sign in to PriceLabs as the account admin and navigate to Account Settings > AI Connector (MCP)" > in **Custom Connectors** click **+ Add Custom Connector** > Name `Claude Code` > Callback URL `http://localhost:8765/callback` (Claude Code's OAuth listener only answers on `/callback`; checked in the Claude Code 2.1.278 binary 2026-09-21. The full PriceLabs handshake has not been run end to end yet, so if Authenticate fails twice, delete the custom client and use the Simple path) > **Add Custom Client**. PriceLabs allows this: "Localhost (http://localhost or http://127.0.0.1) callback URLs are allowed for CLI-based agents such as Claude Code."

"PriceLabs will generate a Client ID and Client Secret and display them once." Copy both straight into `.env`, no chat:
```
PRICELABS_MCP_CLIENT_ID=
PRICELABS_MCP_CLIENT_SECRET=
```
Save, tell Claude "saved". Register:
```bash
set -a; . "$BUNDLE/.env"; set +a
MCP_CLIENT_SECRET="$PRICELABS_MCP_CLIENT_SECRET" claude mcp add --transport http --client-id "$PRICELABS_MCP_CLIENT_ID" --client-secret --callback-port 8765 --scope user pricelabs-official https://mcp.pricelabs.co/mcp >/dev/null 2>&1 && echo "pricelabs-official registered ✅"
echo pricelabs-official >> "$BUNDLE/.cache/needs-restart"
```
`--client-secret` reads the secret from the `MCP_CLIENT_SECRET` environment variable (checked in `claude mcp add --help` on Claude Code 2.1.278). The interactive prompt form does not work inside Claude's Bash tool, so do not drop that variable.

Restart Claude Code, then `/mcp` > **pricelabs-official** > **Authenticate**. A browser tab opens on PriceLabs. Grant **Read**. Grant **Write** only if you want Claude to be able to push price changes later (the Revenue Manager skill asks you before every write; the Write grant itself lets any Claude chat that uses this server push changes). Back in PriceLabs, the custom client card should say **Connected**.

Limits from PriceLabs: "Each account can have up to 3 custom clients." "Regenerating credentials immediately revokes all active connections." The Client ID and Secret are shown once; lose them and you regenerate.

## 5. Verify
Run `bash check-connections.sh` from the kit folder. For PriceLabs it makes one real call: `GET https://api.pricelabs.co/v1/listings_minimal` with your key in the `X-API-Key` header.

- `✅ PriceLabs API  connected`: the call came back 200 and the `pricelabs` server is registered. Done.
- `❌ PriceLabs API  missing`: the `.env` line is blank, or the key works but the server is not registered yet. The hint on the row says which.
- `⚠️ PriceLabs API  registered, key fails`: PriceLabs answered **403 with `API_KEY_INVALID`**. Their words: "A 403 with API_KEY_INVALID means the header is missing or the key is wrong." PriceLabs uses 403 for a bad key, not 401, so do not read it as a permissions problem. Re-copy the key.
- `🔒 needs a full restart of Claude Code`: you just registered it. Quit, reopen in this folder, run the check again.

`PriceLabs MCP (official, beta)` row: `🔒` right after registering, `⚠️ registered, not authenticated` until you do `/mcp` > Authenticate, `✅` after. If you skipped Path B on purpose, this row stays `❌` and that is expected.

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
- **`/mcp` Authenticate loops or never comes back (Claude Code path):** the callback URL on the PriceLabs custom client does not match what Claude Code sends. Check it is exactly `http://localhost:8765/callback`, no trailing slash, and that `--callback-port 8765` was in the register line. If it still fails, delete the custom client, use the Simple path, and move on. The summit does not depend on it.
- **Windows: `pricelabs` shows Failed to connect after restart:** it was registered with a `/c/Users/...` path. Remove and re-add with the `cygpath -w` line in section 3: `claude mcp remove pricelabs -s user`, then the Windows register line.

## 7. Sources
developers.pricelabs.co/customer-api/api-reference/enable-the-api, developers.pricelabs.co/customer-api/quick-start, developers.pricelabs.co/mcp/overview, developers.pricelabs.co/mcp/connectors/connect-to-claude, developers.pricelabs.co/mcp/connectors/custom-clients, developers.pricelabs.co/llms.txt (all read 2026-09-21). `claude mcp add --help` on Claude Code 2.1.278 for the `--client-id` / `--client-secret` / `--callback-port` flags (2026-09-21).
