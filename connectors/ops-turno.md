---
server: turno
slot: ops
required: optional
env: [TURNO_API_TOKEN, TURNO_PARTNER_ID, TURNO_ENV]
official_mcp: none
---

# Turno: your cleaning and turnover schedule, readable by Claude

## 1. What it is
Turno (the app formerly called TurnoverBnB) is where your cleaners, turnover projects and checklists live. The Revenue Manager reads it for operational signals: turnover cost per stay, too many one-night bookings eating your margin, cleans that did not get assigned. We bundle a small Python MCP server (`mcp-servers/turno`, ~47 tools, one per Turno endpoint) that talks to Turno's External API v2 on your behalf. Anything destructive (delete, cancel, disconnect) needs an explicit `confirm=true`, on top of Claude's own permission prompts. This is your live production account, not a sandbox.

## 2. Required, cost, gate
Optional. Pick Turno, Breezeway, or neither for the ops slot. The Revenue Manager still runs without it, you just lose the ops signals.

The gate: **Turno has to switch API access on for your account.** Their docs say only "Please contact us so we can grant you access to the API." There is no self-serve toggle and no published turnaround. **Email help@turno.com today** (the template is in `emails/turno-api-access.md`) or paste the same text into the in-app chat. Turno publishes no fee for API access. While you wait, the scoreboard shows this row as ⏳ with the date you emailed, and setup keeps moving.

Once the email is sent, Claude marks the row as waiting so the scoreboard stops nagging:
```bash
echo "turno|$(date +%F)" >> "$BUNDLE/.cache/pending-vendor"
```
When Turno replies, tell Claude "Turno is enabled". Claude clears the marker and picks up at section 3:
```bash
sed -i.bak '/^turno|/d' "$BUNDLE/.cache/pending-vendor" && rm -f "$BUNDLE/.cache/pending-vendor.bak"
```

## 3. Path A: API key
Wait for Turno to reply "done", tell Claude "Turno is enabled" (Claude runs the clear line from section 2), then:

**Where the values are.** This click path is from Ryan's own Turno account (2026). Turno publishes no owner-facing article for it, so if your screen looks a little different, look for the same words.

1. Log in to Turno in your browser. Top-right initials > **Settings** > **Turno API** (or **API** > **Tokens**).
2. **Create New Token**.
3. Copy the long **Secret Key** (it starts with `eyJ`). It is shown once. Close the dialog and it is gone; make a new token if you missed it.
4. Scroll to the bottom of the same page for the **Partner ID**. It is a UUID (`xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`) and easy to miss.
5. Ignore the shorter hex value next to the Secret Key (Turno labels it "API token" or "Token ID" depending on where you look). It is not the bearer token and we do not use it.

If **Turno API** is not in your Settings menu, Turno has not enabled you yet. No need to hunt for it, just wait for the email.

**Where the values go.** Claude opens your `.env` for you (`open -e "$BUNDLE/.env"` on Mac, `notepad "$(cygpath -w "$BUNDLE")\.env"` on Windows). Never paste either value into the chat. Put each value straight after its `=`, no quotes, no spaces, then save. Fill these two lines and leave the third blank:
```
TURNO_API_TOKEN=eyJ...
TURNO_PARTNER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
TURNO_ENV=
```
Leave `TURNO_ENV=` empty. Claude sets it to `production` when it fans the file out (`bash fan-out-env.sh`), which copies your two values into `mcp-servers/turno/.env` where the server reads them. That is why the register line below carries no key.

**SAFE:** `if [ -d "$BUNDLE/.git" ]; then git -C "$BUNDLE" check-ignore -q .env && echo "protected ✅" || echo "add .env to $BUNDLE/.gitignore first"; else echo "protected ✅ (not a git folder, nothing can commit it)"; fi`
**FILLED:** `grep -q '^TURNO_API_TOKEN=.\+' .env && echo "present ✅" || echo "still blank"` then `grep -q '^TURNO_PARTNER_ID=.\+' .env && echo "present ✅" || echo "still blank"`
**WORKS:** `bash -c '. lib/env.sh; . lib/probes.sh; env_load .env; probe_turno; echo rc=$?'` (0 works, 1 rejected, 2 blank, 3 unreachable)

Then fill the server's own `.env` from the root one (declared keys only, values never printed; this is also where `TURNO_ENV` becomes `production`):
```bash
cd "$BUNDLE" && bash fan-out-env.sh
```

**Register (Mac):** build the server, register it, queue a restart. Windows users: skip this block and use the Windows block below instead.
```bash
cd "$BUNDLE/mcp-servers/turno" && uv sync --quiet
uv run --python 3.13 python "$BUNDLE/lib/mcp_register.py" turno --stdio uv --directory "$BUNDLE/mcp-servers/turno" run turno-mcp && echo "turno registered ✅" || echo "turno register failed ❌"
echo turno >> "$BUNDLE/.cache/needs-restart"
```
`uv` comes from `connectors/system-python-uv.md`; if `uv sync` says command not found, do that file first.

**Register (Windows, Git Bash):** run this INSTEAD of the Mac block. Claude Code on Windows is a native Windows process, so every absolute path handed to the register helper must be the `C:\...` form. Build, convert the path, then register with the converted path:
```bash
cd "$BUNDLE/mcp-servers/turno" && uv sync --quiet
BUNDLE_WIN="$(cygpath -w "$BUNDLE")"
uv run --python 3.13 python "$BUNDLE/lib/mcp_register.py" turno --stdio uv --directory "$BUNDLE_WIN\mcp-servers\turno" run turno-mcp && echo "turno registered ✅" || echo "turno register failed ❌"
echo turno >> "$BUNDLE/.cache/needs-restart"
```
Turno runs through `uv`, so no interpreter path is passed here. If you ever register a Python server by its venv interpreter instead, the Windows path is `.venv/Scripts/python.exe`, not `.venv/bin/python`.

Then quit and reopen the Claude Code desktop app so the new server loads. After it, say "Check my connections".

## 4. Path B: official MCP
_None for this connector._ Turno has no MCP of its own (zero mentions across apidocs.turnoverbnb.com, turno.com and help.turno.com as of 2026-09-21). The bundled server is the only path.

## 5. Verify
The checker calls `GET https://api.turnoverbnb.com/v2/userinfo` with three headers, `Authorization: Bearer <your token>`, `TBNB-Partner-ID: <your Partner ID>` and `Accept: application/json`, plus a browser User-Agent, 15-second timeout. Production host, not the `sandbox.turnoverbnb.com` printed in Turno's docs.

- **HTTP 200 with JSON** (your user record): rc 0. Once the server is registered and you have restarted, the row reads `✅ Turno API connected`.
- **JSON 401**: rc 1, `⚠️ Turno API registered, key fails`. Wrong token or wrong Partner ID. The probe cannot tell you which, so check both lines.
- **An HTML page saying "Just a moment"** (usually a 403): rc 3. The scoreboard row still says `⚠️ Turno API registered, key fails`, but the arrow hint after it reads `vendor unreachable or blocked; try again`. Read the hint: that is Cloudflare's challenge, not your credentials. No need to make a new token, just run the check again in a minute.
- **rc 2**: one of the two lines in `.env` is still blank.
- `🔒 needs a full restart of Claude Code`: registered, not loaded yet. Quit and reopen.
- `⏳ Turno API waiting on vendor (emailed <date>)`: you are still waiting on help@turno.com. Nothing to fix.

After the restart, the real test: ask Claude "Turno, check the connection". It runs `turno_check_connection` and should report `production` as the active environment and `https://api.turnoverbnb.com` as the base URL. If it says sandbox, see troubleshooting.

## 6. Troubleshooting
- **"Turno API" is missing from the Settings menu:** Turno has not enabled your account yet. Only their staff can. Re-send the email or use the in-app chat, and re-run "Check my connections" once they confirm.
- **JSON 401 right after pasting:** the usual cause is copying the short hex value instead of the long `eyJ` Secret Key. Make a new token, copy the `eyJ` one, re-paste. Second most common: a Partner ID from a different Turno account, or a trailing space.
- **401 from your own curl test:** Turno's sample curl commands omit the `Authorization` line; you must add `Authorization: Bearer <token>` yourself. Also, `/api/v2/` instead of `/v2/` returns 401 too. The bundled server already uses `/v2/`; only hand-written calls hit this.
- **HTML "Just a moment" instead of JSON:** Cloudflare challenge. The probe already sends a browser User-Agent; retry in a minute. If it keeps happening, try a different network (a phone hotspot); some venue wifi trips Cloudflare's challenge.
- **`turno_check_connection` says sandbox:** `TURNO_ENV` in your root `.env` is set to `sandbox`. Blank it, run `bash fan-out-env.sh`, quit and reopen the Claude Code desktop app. The summit runs production only.
- **Sandbox hosts in Turno's docs:** every host printed on apidocs.turnoverbnb.com is `sandbox.turnoverbnb.com`. Production is `api.turnoverbnb.com`, confirmed live 2026-09-21. Your token from the Turno app is a production token.
- **`uv: command not found` during register:** install uv per `connectors/system-python-uv.md` (that step needs a real terminal, once, to install uv itself), then quit and reopen the Claude Code desktop app so its Bash tool picks up the new PATH, and run the register block again.
- **Windows: server shows failed after restart:** the registered path was probably the `/c/Users/...` form. Re-run the Windows register block above; it overwrites the old entry with the `cygpath -w` form.
- **You pasted a token into chat by accident:** rotate it. Create a new token in Turno, paste the new one into `.env`, run `bash fan-out-env.sh`, restart. Remove the exposed token in Turno if the page offers a delete.

## 7. Sources
apidocs.turnoverbnb.com (auth headers, userinfo endpoint, partner gate; read 2026-09-21). turno.com/contact-us (help@turno.com; read 2026-09-21). The Settings > Turno API > Tokens click path and the Secret Key / Partner ID labels are from Ryan's own Turno account, 2026-09-21, not from vendor docs. Bundled server: `mcp-servers/turno/README.md` (credential mapping, sandbox default, `confirm=true` on destructive tools).
