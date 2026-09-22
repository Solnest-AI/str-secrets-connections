---
server: smoobu
slot: pms
required: one-of
env: [SMOOBU_API_KEY, SMOOBU_API_SECRET]
official_mcp: none
portal: https://login.smoobu.com
---

# Smoobu: your PMS, if Smoobu is where your bookings live

## 1. What it is
Smoobu is a channel manager and PMS (it calls your properties "apartments"). If it is your PMS, this is the connection the Revenue Manager reads reservations, availability and rates through, and the one every other summit skill leans on for "what do I actually have booked". Smoobu ships no MCP server, so Claude builds a small one for you from Smoobu's own API docs. That server signs every request with Smoobu's new HMAC scheme from day one.

## 2. Required, cost, gate
One PMS is required, and this is one of the eight choices. Pick it only if Smoobu is your PMS.

- **Cost:** nothing extra. The API comes with all three Smoobu plans (smoobu.com/en/pricing, read 2026-09-21). If you read somewhere that it needs "Professional", that is old.
- **Gate:** a paid Smoobu account. Smoobu's words: "Keys can't be generated on a free trial. If you're on a trial and need API access, contact Smoobu Support to have it switched on." So on a trial you have two doors: subscribe, or open the Help menu (or the chat bubble, bottom-right) and ask support to turn on API keys for your trial.
- **Scope:** "Each key gives full access to your whole account". There is no read-only key. Treat it like a password.
- **No email needed.** Nothing to request, nobody to wait on.
- **Heads up on timing:** Smoobu is switching off the old single-header login. Their developer docs say it is "deprecated and will be sunset on September 25, 2026". Their help article says to "add signing before 30 October 2026". Two dates, same message: the old way dies right around the summit. The server Claude builds signs every request the new way from day one, so nothing breaks for you when the switch lands.

## 3. Path A: API key
You need two values, a **Key** and a **Secret**. Both come from the same screen, and the Secret shows once.

**Heads up before you go looking:** Smoobu also has an older, single API Key under **Settings** > **Profile** > **API Key**. That one is legacy and is being switched off along with the old single-header login (section 2). Skip it. Use the Key + Secret pair from **Advanced** > **API Keys** below.

1. Log in to Smoobu (login.smoobu.com). Open **Settings** > **Advanced** > **API Keys**. Smoobu's help article says it as "open Advanced, then API Keys". Same screen.
2. Click **Create New**, top-right corner. The developer docs call this button **Create API Key**. Same thing.
3. In the **Create API token** window, type a short name in **Label** (optional). Use `STR Secrets`. Click **Submit**.
4. Smoobu shows **Token created** with your new **Key**, and your **Secret** below it. Copy both, one at a time.
5. Tick **I have copied my secret**, then click **Close**.

Missed the Secret? You can copy the Key again any time from the **Key** column. The Secret cannot be shown again. Revoke that key and create a new one.

Claude opens your `.env` for you. Paste the two values on these lines, no quotes, no spaces:
```
SMOOBU_API_KEY=
SMOOBU_API_SECRET=
```
Save, then tell Claude "saved". Never put either value in the chat.

**SAFE:** `if [ -d "$BUNDLE/.git" ]; then git -C "$BUNDLE" check-ignore -q .env && echo "protected ✅" || echo "add .env to $BUNDLE/.gitignore first"; else echo "protected ✅ (not a git folder, nothing can commit it)"; fi`
**FILLED:** `grep -q '^SMOOBU_API_KEY=.\+' .env && grep -q '^SMOOBU_API_SECRET=.\+' .env && echo "present ✅" || echo "still blank"`
**WORKS:** `bash -c '. lib/env.sh; . lib/probes.sh; env_load .env; probe_smoobu; echo rc=$?'` (0 works, 1 rejected, 2 blank, 3 unreachable)

**Build the server.** Smoobu has no bundled server. Follow `build/README.md` first, then `build/build-pms-mcp.md` (or `build-pricing-ops-mcp.md`) Steps B1 to B3 only (research, reference doc, write the server code into `$BUNDLE/mcp-servers/smoobu/`), for the folder layout, the tool list and the write-gating only. Credentials, registering, fan-out and the restart are done from THIS file, not from the build doc. That file's Smoobu block is older than this page: it names a legacy `Api-Key` header, a single `SMOOBU_API_KEY` variable, a 'Professional plan' gate and a 1000/min limit. All four are out of date. Where it disagrees with the rules below, this page wins. Build rules that are not optional:
- Base URL is the host only, `https://login.smoobu.com`. Most paths start with `/api/`; availability lives under `/booking/`. Keep `/api` out of the base itself.
- Every request carries Smoobu's four HMAC headers. `X-API-Key` (the Key). `X-Timestamp` (current UTC time, ISO 8601, within 5 minutes of Smoobu's clock). `X-Nonce` (a fresh UUID v4 on every call, never reused). `X-Signature` (base64 of HMAC-SHA256, keyed with the Secret, over this canonical string):
  ```
  METHOD\nPATH\n<query, sorted>\nTIMESTAMP\nNONCE\n<sha256 hex of the body; for GET, the sha256 of an empty string>\nAPI_KEY
  ```
- No legacy `Api-Key` header anywhere in the server. That header dies on the sunset date above.
- Ship a `smoobu_me` tool that calls `GET /api/me` signed. The checker uses it after the switch.
- Declare both variables in the folder's `.env.example` (`SMOOBU_API_KEY=` and `SMOOBU_API_SECRET=`) so `fan-out-env.sh` fills the server's own `.env` from yours.

Then build and register:
```bash
cd "$BUNDLE/mcp-servers/smoobu" && npm install --silent && npm run build --silent
bash "$BUNDLE/fan-out-env.sh"
uv run --python 3.13 python "$BUNDLE/lib/mcp_register.py" smoobu --stdio node "$BUNDLE/mcp-servers/smoobu/dist/index.js" && echo "smoobu registered ✅" || echo "register failed ❌"
echo smoobu >> "$BUNDLE/.cache/needs-restart"
```

**Windows note (Git Bash):** run the build line above as-is (the first line of the block, `cd ... && npm install ... && npm run build`), then use these lines INSTEAD of the register and needs-restart lines. Claude Code on Windows is a native Windows process, so it needs a `C:\...` path, not the `/c/Users/...` form Git Bash shows you. Convert it with `cygpath -w` and register the converted form:
```bash
bash "$BUNDLE/fan-out-env.sh"
uv run --python 3.13 python "$BUNDLE/lib/mcp_register.py" smoobu --stdio node "$(cygpath -w "$BUNDLE/mcp-servers/smoobu/dist/index.js")" && echo "smoobu registered ✅" || echo "register failed ❌"
echo smoobu >> "$BUNDLE/.cache/needs-restart"
```
If Claude built the server in Python instead (airroi style, flat `server.py`), the interpreter on Windows is `$BUNDLE/mcp-servers/smoobu/.venv/Scripts/python.exe`, not `.venv/bin/python`, and both that path and `server.py` get the same `cygpath -w` treatment.

## 4. Path B: official MCP
_None for this connector._ Smoobu publishes no MCP server (checked 2026-09-21: nothing on docs.smoobu.com, nothing in their help center). OAuth 2 is "only supported for Smoobu partners", so Key + Secret is the only door for a host. Path A is the whole setup.

## 5. Verify
The checker's `probe_smoobu` calls `GET https://login.smoobu.com/api/me`. It tries the old `Api-Key` header first (still accepted until the sunset). If Smoobu rejects that and your Secret is filled in, it signs the same call with the four HMAC headers and tries again.

- **Pass:** 200 with your account details (`id`, `firstName`, `lastName`, `email`). rc=0, the row shows ✅.
- **401:** wrong Key, wrong Secret, or (after the switch) the legacy header refused with no Secret to fall back on. rc=1. Reopen `.env`, recheck both lines.
- **rc=2:** `SMOOBU_API_KEY` is blank.
- **rc=3:** could not reach login.smoobu.com. Network hiccup or Smoobu down. Try again in a minute.

**Until the sunset date, the checker's ✅ proves the Key only.** The old header does not use the Secret, so a typo on the `SMOOBU_API_SECRET=` line slips through. The built server signs with the Secret on every call, so `smoobu_me` after the restart is the real test of both values.

After the restart, the built server's own `smoobu_me` tool is the live test: ask Claude to call `smoobu_me`. Your name and email come back, you are connected.

## 6. Troubleshooting
- **No Create New button, or Smoobu refuses to make a key:** you are on a free trial. Smoobu: "Key creation is switched off on free-trial accounts. If you're on a trial and need API access, contact Smoobu Support to have it turned on." Fastest: open **Help** in Smoobu (or the chat bubble, bottom-right), give them your Smoobu User ID (profile-icon menu, top right) and ask for API key creation on your trial. Or subscribe to any plan. Then come back to step 1.
- **Checker says ✅ but `smoobu_me` answers 401:** three things to check, cheapest first. (1) Your computer's clock: Smoobu rejects a timestamp more than 5 minutes off. Turn on automatic time in your OS settings, retry. (2) In Smoobu, **Advanced** > **API Keys** > **IP whitelist** tab: if that list has ANY entry, every signed call from an address not on it gets a plain 401. Leave the list empty (Smoobu: "An empty list means no restriction"). (3) Only then assume the Secret line is wrong (the checker did not test it, see Verify). You cannot re-read a Secret, so revoke that key, **Create New**, paste both new values into `.env`, run `bash "$BUNDLE/fan-out-env.sh"`, restart.
- **401 on one call, 200 on the next:** a nonce got reused. Smoobu's rule: "Never reuse a nonce." The built server makes a fresh UUID v4 per request; if you hand-rolled a test, generate a new one every time.
- **Everything worked, then 401 across the board some day in late September or October 2026:** the legacy `Api-Key` header got switched off and something is still sending it. The built server does not, so this means a stale build. Rebuild (`npm run build` in the server folder) and restart.
- **Lost the Secret:** it cannot be shown again. **Settings** > **Advanced** > **API Keys**, revoke the old key, **Create New**, paste both new values into `.env`, run `bash "$BUNDLE/fan-out-env.sh"`, restart.
- **429 or sudden slowdowns:** the limit is 700 requests per minute. Normal summit use is nowhere near that; a runaway loop is. Stop the loop.
- **Checker says the server failed to start (Windows):** the registered path is probably the `/c/Users/...` form. Re-run the Windows register block in section 3 (it converts with `cygpath -w` and overwrites the old entry), quit and reopen the Claude Code desktop app.

## 7. Sources
docs.smoobu.com (#hmac-authentication; legacy header sunset note), support.smoobu.com articles 360003170740 (create an API key) and 38810363709330, smoobu.com/en/pricing. All read 2026-09-21.
