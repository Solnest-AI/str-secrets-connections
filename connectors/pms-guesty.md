---
server: guesty
slot: pms
required: one-of
env: [GUESTY_CLIENT_ID, GUESTY_CLIENT_SECRET]
official_mcp: npx -y @guestyorg/sdk@0.2.0-alpha.1 mcp (stdio; hosted https://mcp.guesty.com/v1 not used)
portal: https://app.guesty.com/main/integrations/open-api/applications
---

# Guesty: the Pro-tier PMS, connected through its Open API

## 1. What it is
Guesty is a property management system. If your listings, reservations, calendar and guest messages live at app.guesty.com, this is your PMS row. The Revenue Manager reads your listings, reservations and calendar through it, and can write back (calendar changes, guest messages) only after you approve each one. This kit wires Guesty up twice: a server Claude builds on your machine from Guesty's Open API (`guesty`, ours, reads and writes), and Guesty's own beta MCP (`guesty-official`, read-only). Both use the same two values.

## 2. Required, cost, gate
One PMS is required, and this is one of the eight. Pick it only if Guesty is where your bookings live.

The gate is your plan. Guesty's pricing table lists Open API as Lite: no, Pro: yes, Enterprise: yes. Nothing extra to buy on Pro or Enterprise. Nothing you can buy on Lite that turns it on. If you were on Guesty For Hosts, that product was shut down on 2026-01-15 and you are on Lite or Pro now. Lite has no Open API, and the MCP needs an Open API application, so Lite gets neither. Check which plan you landed on before you start.

You need admin on the Guesty account. Guesty's MCP page says "Admin permissions on your Guesty account," and the Open API "provides a single admin scope," which means the application you create can do anything your admin login can. Treat the two values like a password.

Two hard caps from Guesty: "You can create up to five (5) Open API OAuth applications," and "You can generate a maximum of five access tokens per 24 hours, per clientId." The second one shapes this whole file. No email to anyone. (If you are a software partner rather than a host, Guesty says to "refrain from using the Open API and contact partnerships@guesty.com." That is not this path.)

## 3. Path A: API key
Guesty calls the credential an "OAuth application." Do not let the name scare you. It is a Client ID plus a Client Secret that Claude swaps for a token behind the scenes. No redirect, no browser login.

Guesty's own steps (help article 9370472424605):
1. "Sign in to your Guesty account."
2. "In the side navigation menu, click Integrations." Guesty's developer docs label the same screen "Integrations > Developer tools > OAuth applications."
3. "Select OAuth applications."
4. "At the top right, click New application."
5. "Enter the application name and description and click Save." Name it `STR Secrets`. There is no scope picker; the Open API has a single admin scope.
6. "Click [copy] next to the relevant key." Copy both values.

Direct link: https://app.guesty.com/main/integrations/open-api/applications

Guesty: "Your client ID and client secret are only visible the first time you access it." That is BOTH values, not just the secret. Leave that tab open until both are in the file. If you lose either one, make a new application (you get five).

Two lines in `.env`. Claude opens the file; put each value after its equals sign, save, close. The file is the only place they go. Nothing goes in the chat.
```
GUESTY_CLIENT_ID=
GUESTY_CLIENT_SECRET=
```

Run these from inside `$BUNDLE`:
**SAFE:** `if [ -d "$BUNDLE/.git" ]; then git -C "$BUNDLE" check-ignore -q .env && echo "protected ✅" || echo "add .env to $BUNDLE/.gitignore first"; else echo "protected ✅ (not a git folder, nothing can commit it)"; fi`
**FILLED:** `grep -q '^GUESTY_CLIENT_ID=.\+' .env && grep -q '^GUESTY_CLIENT_SECRET=.\+' .env && echo "present ✅" || echo "still blank"`
**WORKS:** `bash -c '. lib/env.sh; . lib/probes.sh; env_load .env; probe_guesty; echo rc=$?'` (0 works, 1 rejected, 2 blank, 3 unreachable)

WORKS spends one of today's five tokens and caches it in `$BUNDLE/.cache/guesty.token` for 23 hours. Run it once, not five times.

**Build** the server. There is no pre-built Guesty server in the bundle. Claude builds one on your machine by following `build/build-pms-mcp.md`, Path B, the Guesty Pro card, Steps B1 to B3 only. Stop before Step B4: registration happens in the Register block below, and skip B5 (smoke test) and B6 (first-run discovery) for Guesty. WORKS already proved the pair, and every process that exchanges its own token spends one of today's five. If a smoke test gets written anyway, it needs to read `$BUNDLE/.cache/guesty.token` exactly the way the server does. Two things the built server has to do, no exceptions:
- Read the two values from its own `.env` in `$BUNDLE/mcp-servers/guesty/`, which `fan-out-env.sh` fills from the root `.env`. The values never go into the register line.
- Read and write the shared token cache at `$BUNDLE/.cache/guesty.token`, the same file `probe_guesty` uses. One token then covers the checker and the server. Without this, the checker and the server each burn their own slot, and the cap is five a day.
- Claude: `build/build-pms-mcp.md` was written for a different kit. Skip its Step 2 credential walk and its create-`.env`, paste, three-sanity-checks flow for Guesty. Its Guesty card says "API & Webhooks", "grant scopes", name it "Claude MCP", and "contact Guesty support to enable it"; section 3 above is correct on all four (the screen is OAuth applications, there is no scope picker, the name is `STR Secrets`, and Lite has no Open API). Its Sanity Check 3 is a raw token call that spends a slot; WORKS above already proved the pair. Write `mcp-servers/guesty/.env.example` with exactly the lines `GUESTY_CLIENT_ID=` and `GUESTY_CLIENT_SECRET=` (fan-out matches on those names), then run `bash "$BUNDLE/fan-out-env.sh"` before you register, or the server starts with an empty `.env` and shows Failed to connect after the restart.

**Register:**
```bash
bash "$BUNDLE/fan-out-env.sh" >/dev/null && echo "fanned out ✅" || echo "fan-out failed ❌"
uv run --python 3.13 python "$BUNDLE/lib/mcp_register.py" guesty --stdio node "$BUNDLE/mcp-servers/guesty/dist/index.js" && echo "guesty registered ✅" || echo "register failed ❌"
echo guesty >> "$BUNDLE/.cache/needs-restart"
```
If Claude built it in Python instead of Node, swap `node "$BUNDLE/mcp-servers/guesty/dist/index.js"` for `"$BUNDLE/mcp-servers/guesty/.venv/bin/python" "$BUNDLE/mcp-servers/guesty/server.py"`, as `build/build-pms-mcp.md` shows.

**Windows note:** Claude Code is a native Windows process, so every absolute path gets converted with `cygpath -w` before it is registered:
```bash
bash "$BUNDLE/fan-out-env.sh" >/dev/null && echo "fanned out ✅" || echo "fan-out failed ❌"
uv run --python 3.13 python "$BUNDLE/lib/mcp_register.py" guesty --stdio node "$(cygpath -w "$BUNDLE/mcp-servers/guesty/dist/index.js")" && echo "guesty registered ✅" || echo "register failed ❌"
echo guesty >> "$BUNDLE/.cache/needs-restart"
```
For a Python build, the venv interpreter is `.venv/Scripts/python.exe`, not `.venv/bin/python`, and it gets the same treatment: `"$(cygpath -w "$BUNDLE/mcp-servers/guesty/.venv/Scripts/python.exe")" "$(cygpath -w "$BUNDLE/mcp-servers/guesty/server.py")"` in place of the `node ...` part.

## 4. Path B: official MCP
Guesty ships its own MCP as an npm package. It is a beta, and Guesty says so in plain words: "early-stage beta release ... experimental. Do not rely on it for any production use." It is read-only. It needs Node 20 or later (see `system-node.md`). Auth is the same Client ID and Client Secret, passed as environment variables. No browser window opens and there is no `/mcp` > Authenticate step. Guesty: "If you use your CLIENT_ID, CLIENT_SECRET there is no need to manually get token."

Source the `.env` first, then register (the two values are read by the helper from the environment; their variable NAMES are the only thing on this line, never the values):
```bash
set -a; . "$BUNDLE/.env"; set +a
export CLIENT_ID="$GUESTY_CLIENT_ID" CLIENT_SECRET="$GUESTY_CLIENT_SECRET"
uv run --python 3.13 python "$BUNDLE/lib/mcp_register.py" guesty-official --stdio npx -y @guestyorg/sdk@0.2.0-alpha.1 mcp --env CLIENT_ID --env CLIENT_SECRET && echo "guesty-official registered ✅" || echo "guesty-official failed ❌"
echo guesty-official >> "$BUNDLE/.cache/needs-restart"
```
The `@0.2.0-alpha.1` pin is deliberate. `@0.2.0` does not exist on npm (checked 2026-09-21: only `0.2.0-alpha` and `0.2.0-alpha.1` are published). No need to "clean it up." Guesty's docs show `npx -y @guestyorg/sdk mcp` with no version; the pin makes sure you get the newest published build, and the same one every time (unpinned, npm's `latest` tag hands you the older `0.2.0-alpha`). Guesty's MCP page lists Cursor, Claude Desktop, VS Code and Antigravity; it has no Claude Code section, so the register line above is our translation of their config, not a line Guesty published or one we have run end to end.

Both values land in `~/.claude.json` as that server's environment. That is a second copy of your secret, which is one reason we never print the raw contents of that file to you.

**Read this before you register it.** Guesty: "When using CLIENT_ID and CLIENT_SECRET, each restart requests a new token, which counts toward the 5-tokens-per-24-hours limit." Verified live: each `guesty-official` start actually spends TWO of today's five tokens, not one. Do the math as checker probe (1, and only when the built server's cached token is stale) plus two for every Claude Code restart with `guesty-official` registered. Two restarts already puts you at five before the summit starts. So: set the official Guesty MCP up last, on a day you will not restart Claude Code again. If you restart often, skip it for now, the built `guesty` server plus the checker share one cached token and that is enough for the summit skills. Guesty says a browser sign-in version is coming, which should remove this cap entirely. Claude: if the attendee skips Path B, that row stays ❌ on purpose. Say so once and move on.

Capability warning: read-only. Calendar writes and guest messages go through the built `guesty` server, never this one. Guesty also lists a hosted version at `https://mcp.guesty.com/v1`, but says "Claude.ai web is not currently a supported client" because that client "defaults to OAuth discovery, which this server does not support." We use the stdio package for that reason. Beta as of 2026-09-21 (Guesty's MCP page is dated 2026-08-22). No waitlist.

**Windows note:** the only paths in this block (`$BUNDLE/.env`, the needs-restart file) are read by Git Bash itself, not handed to Claude Code, so no `cygpath -w` here. If `guesty-official` shows `Failed to connect` after the restart and `node -v` is 20 or newer, re-run the register block with `cmd //c npx -y @guestyorg/sdk@0.2.0-alpha.1 mcp` in place of `npx -y @guestyorg/sdk@0.2.0-alpha.1 mcp` (double slash on purpose: Git Bash turns a lone `/c` into `C:/`); it overwrites the old entry. That is one more restart, so one more token slot; do it tomorrow if today's count is already at four.

## 5. Verify
The checker runs `probe_guesty`. Two real calls:
1. `POST https://open-api.guesty.com/oauth2/token`, form-encoded, `grant_type=client_credentials&scope=open-api` plus your two values. Skipped when `.cache/guesty.token` is under 23 hours old.
2. `GET https://open-api.guesty.com/v1/listings?limit=1` with `Authorization: Bearer <token>`.

Outcomes:
- **rc=0**: 200 on the listings call. Works. Row shows ✅.
- **rc=1**: the token call came back 4xx, or the listings call came back 401 or 403. Usually a wrong Client ID or Client Secret (a stray space, or the two values swapped between the lines). It can also mean today's five tokens are spent, because a refused exchange is a 4xx too. Before you re-copy anything, check whether `$BUNDLE/.cache/guesty.token` is missing or older than 23 hours, and count your restarts. If you made a new application today, the cached token belongs to the old one: run `rm -f "$BUNDLE/.cache/guesty.token"` and WORKS once more before you re-copy anything.
- **rc=2**: one or both `.env` lines are blank. Fill them in.
- **rc=3**: no network, or Guesty is down. Try again in a minute.

The checker reports `guesty` and, if you did Path B, `guesty-official`. Inside the desktop app with no `claude` CLI on PATH it just reads the registration out of `~/.claude.json`, which spends nothing. If a `claude` CLI is present and the checker uses it, every run starts `guesty-official` fresh and spends a token; that is the one case where re-checking too often matters. `Connected` (or `registered`, from the file-based reading) is what you want. `Failed to connect` on `guesty` right after a build usually means the build did not finish or `fan-out-env.sh` has not run since the build. `Failed` on `guesty-official` the first time is often the `npx` download running past the startup timeout; the next "Check my connections" retries it, and that retry can cost a slot when a CLI is involved.

## 6. Troubleshooting
- **"OAuth applications" is not in the Integrations menu:** your plan does not include the Open API. That is Lite, including anyone moved off Guesty For Hosts onto Lite. Upgrade to Pro, or pick a different PMS row. No support ticket unlocks it on Lite.
- **You saw the values once and now they are hidden:** by design, "only visible the first time." Make a new application, name it `STR Secrets 2`, copy both values right away. You only get five applications, so delete the dead one. Then delete the old token so the new pair is really tested: `rm -f "$BUNDLE/.cache/guesty.token"`, then WORKS once. That spends one of the new application's five, on purpose.
- **429 from the API:** more than 15 concurrent requests. The built server backs off on its own. If a summit skill hits it, the skill is looping; stop the run and ask Claude to page instead of blasting.
- **Token exchange refused, credentials are right:** you spent today's five tokens. Usual causes: restarting Claude Code repeatedly with `guesty-official` registered, deleting `.cache/guesty.token`, or running WORKS over and over. Wait for the 24-hour window to roll over. A new application gets its own five, but you only get five applications, so save that move for when you are really stuck.
- **Intermittent 403 from `guesty-official`:** Guesty's MCP page: "403, inconsistently ... confirm that the OAuth client has MCP scopes provisioned in addition to Open API v1 access." That is a setting on Guesty's side of your application. Contact Guesty support and ask them to provision MCP scopes on the OAuth client. The built `guesty` server is not affected; it only needs Open API v1.
- **Tried to add Guesty as a connector at claude.ai:** it will not work. Guesty: "Claude.ai web is not currently a supported client." Claude Code and Claude Desktop only.
- **`guesty-official` will not start:** `node -v` must print v20 or newer. See `system-node.md`. On Windows, if `npx` throws `npm.ps1 cannot be loaded`, the fix is in the same file. On Windows, if it still fails after that, use the `cmd //c` form in the section 4 Windows note.
- **Hand-rolled the token call from Guesty's docs and got rejected:** Guesty's reference/get-started page shows a JSON body; their authentication page shows form-encoded. Use the form version. That is what the probe and the built server send.
- **`guesty` shows Failed after restart (Windows):** the registered path is probably `/c/Users/...` instead of `C:\Users\...`, or it points at `.venv/bin/python`, which does not exist on Windows. Re-run the Windows register block in section 3; it overwrites the old entry.

## 7. Sources
open-api-docs.guesty.com: guesty-mcp-server-beta (page dated 2026-08-22), authentication, rate-limits. help.guesty.com articles 9370472424605 (OAuth applications) and 38838334086301 (MCP). guesty.com/pricing (Open API row). npm registry, @guestyorg/sdk versions. All read 2026-09-21.
