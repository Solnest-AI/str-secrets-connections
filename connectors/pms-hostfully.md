---
server: hostfully
slot: pms
required: one-of
env: [HOSTFULLY_API_KEY, HOSTFULLY_AGENCY_UID]
official_mcp: none
portal: https://platform.hostfully.com/app/#/agency-settings
---

# Hostfully: your PMS, wired in through a server Claude builds for you

## 1. What it is
Hostfully is your property management system. The summit Revenue Manager skill reads your properties, calendar, nightly rates and reservations through it (Hostfully calls reservations "leads", so do not panic when you see that word). Hostfully does not ship an MCP server, so Claude builds a small one for you from Hostfully's API docs, points it at your agency, and registers it as `hostfully`. You never touch the code.

## 2. Required, cost, gate
One PMS is required and this is one of the eight. Two things to know before you start:

- **The API is a paid add-on.** If the API Key field is not on your Agency Settings page, it is not turned on yet. Hostfully's words: "If you don't see API key, it might be because you haven't added API access to your subscription - in this case, please contact our billing team by typing 'Talk to a human - need help with billing' for further help." So: open the Hostfully chat (their words: 'that little chat box on the bottom right corner of your screen'; it is on the help site and in the PMS), type exactly `Talk to a human - need help with billing`, and ask for the API add-on and its price. If chat gets you nowhere in a day, send this to api@hostfully.com (that address is the API team, so say you already asked billing):

  > **Subject:** Please enable API access on my Hostfully PMS account
  >
  > Hi Hostfully team, I'm an STR operator on Hostfully PMS and I'd like the API add-on enabled on my account (the email I'm writing from) so I can pull my own properties, calendar and pricing into my own tools. Could you turn it on and let me know what it costs? Thanks, <name>, <company>.

  While you wait, tell Claude you have emailed them (the email above is the template; there is no separate `emails/` file for Hostfully). Claude marks the row ⏳ (pending vendor) instead of ❌ so the scoreboard stops nagging, and you carry on with the rest of setup:
  ```bash
  echo "hostfully|$(date +%F)" >> "$BUNDLE/.cache/pending-vendor"
  ```
  When Hostfully confirms the add-on is on, tell Claude "Hostfully is enabled". Claude clears the marker and picks up at section 3 (until it is cleared the checker skips the key test and keeps showing ⏳ even after you paste the values):
  ```bash
  sed -i.bak '/^hostfully|/d' "$BUNDLE/.cache/pending-vendor" && rm -f "$BUNDLE/.cache/pending-vendor.bak"
  ```

- **The key is all-access.** Hostfully: "Agency API key ... provides full access to the agency's data." Treat it like your Hostfully password. It goes in the `.env` file and nowhere else.

No MCP from Hostfully as of 2026-09-21, so there is no Path B here.

## 3. Path A: API key
Hostfully's own steps, word for word: "1. Log in to your Hostfully PMS account. 2. Navigate to your Agency Settings page. 3. Scroll down to find the field API Key." And: "You can find your agency UID at the bottom of the Agency Settings page."

Direct links, both from Hostfully's help: https://platform.hostfully.com/app/#/agency-settings and https://platform.hostfully.com/agency.jsp. Use whichever one opens your Agency Settings.

You need two values from that one page:
1. Log in to your Hostfully PMS account and open **Agency Settings** (the direct link above lands there).
2. **API Key.** Scroll down to the API Key field. A long opaque string; it is displayed, not shown once, so you can come back for it. Copy it.
3. **Agency UID.** Scroll to the very bottom of the same page. Another long opaque string. Copy it.

Both go in the `.env` file Claude opened for you, one per line, no quotes, no spaces:
```
HOSTFULLY_API_KEY=
HOSTFULLY_AGENCY_UID=
```
Save the file and tell Claude "saved". Never put either value in the chat. If one ever does land in a chat, the only way to get a fresh key is to ask Hostfully: "You should contact api@hostfully.com if: you need a new API Key." You cannot regenerate it yourself.

Then Claude runs, in order:

**SAFE:** `if [ -d "$BUNDLE/.git" ]; then git -C "$BUNDLE" check-ignore -q .env && echo "protected ✅" || echo "add .env to $BUNDLE/.gitignore first"; else echo "protected ✅ (not a git folder, nothing can commit it)"; fi`
**FILLED:** `grep -q '^HOSTFULLY_API_KEY=.\+' .env && grep -q '^HOSTFULLY_AGENCY_UID=.\+' .env && echo "present ✅" || echo "still blank"`
**WORKS:** `bash -c '. lib/env.sh; . lib/probes.sh; env_load .env; probe_hostfully; echo rc=$?'` (0 works, 1 rejected, 2 blank, 3 unreachable)

**Build:** Follow `build/README.md` first, then `build/build-pms-mcp.md` (or `build-pricing-ops-mcp.md`) Steps B1 to B3 only (research, reference doc, write the server code into `$BUNDLE/mcp-servers/hostfully/`). Credentials, registering, fan-out and the restart are done from THIS file, not from the build doc. Three overrides for Hostfully: skip that file's Step 2 Hostfully card (it says to click a Generate API Key button that Hostfully's help does not describe; use section 3 above, the key is a field you copy), skip its post-build credential contract (steps 1 to 6 under 'After you finish writing the code'; the root `.env` plus `fan-out-env.sh` already fill `mcp-servers/hostfully/.env`, nothing gets pasted a second time), and make the server load its `.env` from its own folder, not the working directory, exactly like the bundled Hospitable server does (`config({ path: resolve(__dirname, "..", ".env") })` in `src/index.ts`), because `--scope user` means Claude Code can start it from any folder. Then:
```bash
cd "$BUNDLE/mcp-servers/hostfully" && npm install --silent && npm run build --silent && ls dist/index.js
bash "$BUNDLE/fan-out-env.sh"
```
(The built server reads `HOSTFULLY_API_KEY` and `HOSTFULLY_AGENCY_UID` from its own `.env`, which `fan-out-env.sh` fills from the root one. Nothing is typed twice.)

**Register (Mac):**
```bash
uv run --python 3.13 python "$BUNDLE/lib/mcp_register.py" hostfully --stdio node "$BUNDLE/mcp-servers/hostfully/dist/index.js" && echo "hostfully registered ✅" || echo "register failed ❌"
echo hostfully >> "$BUNDLE/.cache/needs-restart"
```

**Register (Windows, in Git Bash):** Claude Code is a native Windows process, so it must be handed a `C:\...` path. Convert it first with `cygpath -w`:
```bash
uv run --python 3.13 python "$BUNDLE/lib/mcp_register.py" hostfully --stdio node "$(cygpath -w "$BUNDLE/mcp-servers/hostfully/dist/index.js")" && echo "hostfully registered ✅" || echo "register failed ❌"
echo hostfully >> "$BUNDLE/.cache/needs-restart"
```
(If Claude built this server in Python instead of Node, the interpreter on Windows is `.venv/Scripts/python.exe`, not `.venv/bin/python`, and that path gets the same `cygpath -w` treatment.)

Quit and reopen the Claude Code desktop app when Claude tells you to (it batches restarts), then say "Check my connections".

## 4. Path B: official MCP
_None for this connector._
Hostfully publishes no MCP server (help site, developer docs and a domain search all came up empty on 2026-09-21). The built `hostfully` server above is the whole story.

## 5. Verify
The checker's `probe_hostfully` makes one real call: `GET https://api.hostfully.com/v3/properties?agencyUid=<your UID>` with the header `X-HOSTFULLY-APIKEY: <your key>`. It prints nothing but the return code:

- **rc=0:** any 2xx. Key and UID both work. The scoreboard shows `✅ Hostfully API` once the server is registered and you have restarted (before the restart it shows 🔒 need restart, which is normal).
- **rc=1:** 401 or 403. Hostfully rejected the key or the UID. Re-copy both from the Agency Settings page.
- **rc=2:** one or both lines in `.env` are blank.
- **rc=3:** anything else (timeout, 5xx, a 404 from a path outside the API). Hostfully is unreachable or the URL is off; try again in a minute.

Our research did not capture the exact error text Hostfully returns for a bad key, so go by the status code, not the message.

After the restart, the real test: ask Claude "list my Hostfully properties". If your listings come back, you are done. Claude shows you the scoreboard, not the raw server list.

## 6. Troubleshooting
- **No API Key field on Agency Settings:** the add-on is not enabled. In-app chat or the email in section 2. Nothing on your side can make the field appear.
- **Need a new key (rotation, or it leaked):** only Hostfully can issue one. Email api@hostfully.com. There is no regenerate button.
- **rc=1 but you are sure the key is right:** check the UID. Both values come from the same page, and the UID is at the very bottom, easy to miss or half-copy. Also check for a stray space or quote after the `=` in `.env`.
- **400 from the properties call:** `agencyUid` is missing. It is a query parameter on list endpoints (properties, leads), not a header. The built server handles this; if you are testing by hand, add `?agencyUid=...`.
- **404 on a call that should work, or rc=1 with a key you trust:** Hostfully's help pages show two base paths, `https://api.hostfully.com/v3/` and `https://api.hostfully.com/api/v3/`, and its developer docs pin `https://api.hostfully.com/api/v3.3/`. The checker uses `/v3/`; the server Claude builds uses `/api/v3.3/` (that is what `build/build-pms-mcp.md` tells it to do). All three answered on 2026-09-21. Note that a wrong version under `/api/` comes back as 401, not 404, so a bad base path in the built server can look like a rejected key. If Hostfully moves things, the base URL constant in `$BUNDLE/mcp-servers/hostfully/` is the first line to change.
- **Rate limit:** Hostfully's developer docs say 10,000 calls an hour; their FAQ says 1,000. Plan for the lower number. A handful of properties checked a few times a day stays well under either.
- **Server shows Failed to connect after restart (Windows):** the registered path is probably a `/c/Users/...` form. Re-run the Windows register line above; it overwrites the old entry with the `cygpath -w` form.
- **Server connects, but every tool says the key is missing (often only from a different folder):** the built server is reading `.env` from the current directory instead of `$BUNDLE/mcp-servers/hostfully/.env`. Fix the dotenv path in `src/index.ts` to resolve relative to the file, rebuild (`npm run build --silent`), quit and reopen the Claude Code desktop app.

## 7. Sources
help.hostfully.com articles 5520003 (API authentication: API key vs OAuth, base URL) and 3453789 (where the API key and agency UID live, api@hostfully.com for new keys, the in-app chat phrase for billing when the field is missing); dev.hostfully.com (header name, rate limit). Read 2026-09-21. No MCP found on any Hostfully property that day.
