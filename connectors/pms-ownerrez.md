---
server: ownerrez
slot: pms
required: one-of
env: [OWNERREZ_EMAIL, OWNERREZ_TOKEN]
official_mcp: none
portal: https://app.ownerrez.com/settings/api
---

# OwnerRez: your PMS, read through a Personal Access Token

## 1. What it is
OwnerRez is one of the eight PMS choices for the summit. You pick one PMS; this is your file if it is OwnerRez. The revenue manager, listing optimizer and comping agent read your properties, bookings and calendar through the `ownerrez` MCP server that Claude builds for you in section 3. Reads run on their own. Anything that would change a price or a calendar shows you the exact change and waits for a yes.

## 2. Required, cost, gate
One PMS is required, and OwnerRez counts. No plan gate, no approval, no email to send: the Personal Access Token is self-serve inside your account (as of 2026-09-21).

Two things to know before you click around:
- **You do not need to create an OAuth app.** OwnerRez says to use a Personal Access Token for your own account. Ignore the "Grant Access To Me" button, that is for webhook apps. Vendor: "If you only need to access your own account ... use a Personal Access Token instead."
- **No official MCP yet.** OwnerRez staff, 2026-07-16: "Both an MCP server, and a CLI are in the works". Until that ships, the server Claude builds in section 3 is the path.

Two limits, neither of which touches the summit skills: a Personal Access Token cannot send guest messages (the API answers 402 `messaging_not_enabled`), and "Listing endpoints requires a partnership agreement between your business and OwnerRez." The skills read properties and bookings. OwnerRez has no GET for nightly rates, so the built server reads occupancy from bookings and writes rates via `PATCH /v2/spotrates` only behind approval, showing you the exact per-date change and waiting for a yes before anything goes out.

## 3. Path A: API key
You need two values: your OwnerRez **login email** and a **Personal Access Token**.

Vendor's words: "go to Developer/API Settings (Settings > Advanced Tools > Developer/API Settings)", or "go to Developer/API Settings in the dropdown arrow at the top-right of your OwnerRez screen". Direct link: https://app.ownerrez.com/settings/api

1. Open https://app.ownerrez.com/settings/api (log in if it asks).
2. Create a new Personal Access Token. Name it `STR Secrets`. Leave the IP restriction on **Allow All** (the default). Deny All blocks every call unless your current IP is on the list, and your IP changes when you move between home, cafe and hotel wifi.
3. Copy the token right away. It starts with `pt_` and OwnerRez shows it once. Lose it and you make a new one, no harm done.
4. Note the email you log in to OwnerRez with. That is the other half. Basic auth is email plus token.

Claude opens `.env` for you. Fill these two lines and save. The token goes in the file, never in the chat.
```
OWNERREZ_EMAIL=
OWNERREZ_TOKEN=
```
(The built server reads its own `.env` inside `mcp-servers/ownerrez/`, which `fan-out-env.sh` fills from this one. Nothing to copy by hand.)

**SAFE:** `if [ -d "$BUNDLE/.git" ]; then git -C "$BUNDLE" check-ignore -q .env && echo "protected ✅" || echo "add .env to $BUNDLE/.gitignore first"; else echo "protected ✅ (not a git folder, nothing can commit it)"; fi`
**FILLED:** `grep -q '^OWNERREZ_EMAIL=.\+' .env && grep -q '^OWNERREZ_TOKEN=.\+' .env && echo "present ✅" || echo "still blank"`
**WORKS:** `bash -c '. lib/env.sh; . lib/probes.sh; env_load .env; probe_ownerrez; echo rc=$?'` (0 works, 1 rejected, 2 blank, 3 unreachable)

**Build:** there is no pre-built OwnerRez server. Claude writes one in TypeScript (the default in `$BUNDLE/build/build-pms-mcp.md`, Path B, the OwnerRez brief; read `build/README.md` first for the three overrides). It lands in `$BUNDLE/mcp-servers/ownerrez/` with entry `dist/index.js`. Stick with TypeScript here rather than the Python flavour: every register line in this file assumes `dist/index.js`. Two more overrides for OwnerRez: skip the build doc's own OwnerRez credential card (it points at secure.ownerrez.com and names the token "Claude MCP"; section 3 above already did this, and one token named STR Secrets is all you need) and skip its post-build credential contract (the `.env` block and Sanity Checks 1 to 3): the pair is already in the root `.env`, and `bash "$BUNDLE/fan-out-env.sh"` in the Register block copies it into the server's own `.env`. Leave out the build brief's `send_message` tool: a Personal Access Token gets 402 `messaging_not_enabled` on every messaging call, so that tool could never work. Every request the server sends carries Basic auth (email:token) plus a `User-Agent` header, because OwnerRez answers 403 to anything without one. Tell the build to ship a `.env.example` in that folder listing `OWNERREZ_EMAIL=` and `OWNERREZ_TOKEN=`, so `fan-out-env.sh` can fill the server's own `.env` from yours.

**Register:**
```bash
bash "$BUNDLE/fan-out-env.sh"
uv run --python 3.13 python "$BUNDLE/lib/mcp_register.py" ownerrez --stdio node "$BUNDLE/mcp-servers/ownerrez/dist/index.js" && echo "ownerrez registered ✅" || echo "register failed ❌"
echo ownerrez >> "$BUNDLE/.cache/needs-restart"
```

**Register (Windows, Git Bash):** Claude Code is a native Windows process, so it must be handed a `C:\...` path even though you are typing in Git Bash. Skip the block above on Windows; run this one instead, which converts the path with `cygpath -w` first:
```bash
bash "$BUNDLE/fan-out-env.sh"
uv run --python 3.13 python "$BUNDLE/lib/mcp_register.py" ownerrez --stdio node "$(cygpath -w "$BUNDLE/mcp-servers/ownerrez/dist/index.js")" && echo "ownerrez registered ✅" || echo "register failed ❌"
echo ownerrez >> "$BUNDLE/.cache/needs-restart"
```
(This server is TypeScript, so there is no venv. The Python servers in this kit use `.venv/Scripts/python.exe` on Windows instead of `.venv/bin/python`, and that path gets the same `cygpath -w` treatment.)

Then quit and reopen the Claude Code desktop app. Claude batches restarts, so you will usually do one restart after several servers are registered, not one each.

## 4. Path B: official MCP
_None for this connector._ OwnerRez has no MCP server to connect to today. Staff on the feature-request thread (2026-07-16): "Both an MCP server, and a CLI are in the works" (status: Planned). When it ships it gets the name `ownerrez-official` and a section here.

## 5. Verify
The checker runs `probe_ownerrez`: one real call to `GET https://api.ownerrez.com/v2/users/me` with HTTP Basic `email:token`, `Content-Type: application/json` and a `User-Agent` header. It reads both values from `.env` itself, so the token never touches the chat.

- **200** = works, rc 0. You get a ✅ row.
- **401** = OwnerRez rejected the email or the token, rc 1. Wrong email (it must be the one you log in with), a typo, or a token you deleted.
- **403** = also rc 1. The probe always sends a User-Agent, so a 403 from the checker is one of OwnerRez's documented 403 codes: `ip_blocked` (the token's IP restriction is not letting your current IP through; section 6 has the fix), `account_locked` (OwnerRez: "Contact help@ownerrez.com"), or `account_closed`.
- **rc 2** = one of the two lines is still blank.
- **rc 3** = anything else: could not reach api.ownerrez.com (network, VPN, OwnerRez down), or OwnerRez answered 429 `rate_limited` or a 5xx. Wait a minute and run WORKS again before digging.

After the restart, `/mcp` shows `ownerrez` as connected and its read tools (properties, bookings) appear.

## 6. Troubleshooting
- **403 on everything, even with the right token:** first open the token at https://app.ownerrez.com/settings/api and check its IP restriction mode. OwnerRez: a 403 `ip_blocked` means the request came from an IP not allowed for this token; set the mode to Allow All and run WORKS again. If it is already Allow All: OwnerRez: "403 errors most often occur due to missing User-Agent headers, suspicious content, or a blocked IP address." The built server and the probe both send a User-Agent (if you tested with your own curl, add `-A "StrSecretsConnections/1.0"`). If you suspect the IP block list, OwnerRez says to email partnerhelp@ownerrez.com.
- **Two accounts, one laptop, one day:** OwnerRez: "any given IP address may only access two different user accounts within 24 hours." Manage more than two OwnerRez accounts from the same connection and the third is refused until the clock rolls over. OwnerRez does not document which status code that refusal uses, so it can surface as rc 1 or rc 3. Set up your main account first.
- **401 right after creating the token:** the email is not the login email, or the token was pasted with a trailing space or without its `pt_` start. Open `.env`, check both lines, save, run WORKS again.
- **Lost the token:** it is shown once. Go back to Developer/API Settings, make a new one, replace the `OWNERREZ_TOKEN=` line, run `bash fan-out-env.sh`, then WORKS.
- **Windows: `ownerrez` shows Failed to connect after the restart:** the registered path is probably the `/c/Users/...` form. Re-run the Register (Windows, Git Bash) block in section 3; it overwrites the old entry with the `cygpath -w` form.
- **402 `messaging_not_enabled`:** a Personal Access Token cannot use the messaging endpoints. By design, and the summit skills do not send messages through OwnerRez. Nothing to fix.
- **"Do I need to click Grant Access To Me?"** No. That button lives inside a self-built OAuth app and exists for webhooks. Skip it.

## 7. Sources
ownerrez.com/support/articles/api-auth, ownerrez.com/support/articles/api-oauth-app, ownerrez.com/support/articles/api-errors (read 2026-09-21). ownerrez.com/forums/requests/mcp-functionality?page=2 (staff reply 2026-07-16). Live probe 2026-09-21: no User-Agent = 403; with one, bad credentials = 401.
