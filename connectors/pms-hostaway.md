---
server: hostaway
slot: pms
required: one-of
env: [HOSTAWAY_ACCOUNT_ID, HOSTAWAY_API_KEY]
official_mcp: none
portal: https://dashboard.hostaway.com/
---

# Hostaway: your PMS, wired into the summit skills

## 1. What it is
Hostaway is your property management system, so it is where your listings, reservations and calendar live. The Revenue Manager reads all of that through this connection, and any other summit skill that needs your listing data goes through the same door. There is no pre-built Hostaway server in the kit: Claude builds a small local MCP server on your machine from Hostaway's live API docs, following `build/build-pms-mcp.md` Path B. It runs on Node, talks to `https://api.hostaway.com/v1/`, and reads your keys from a local `.env` file, never from the chat.

## 2. Required, cost, gate
One PMS is required and Hostaway is one of the eight we support. No extra cost: the API comes with your Hostaway account (Hostaway pricing is quote-only and neither their docs nor their help center mention a plan gate; if **Settings** > **Hostaway API** is in your dashboard, you have it). No email to send, no waiting on a vendor. Hostaway has no official MCP as of 2026-09-21 (a Hostaway job ad says one is coming; nothing has shipped), so Path A is the only path.

## 3. Path A: API key
You are collecting two values: an **Account ID** (a number) and an **API Key** (a long secret string). You need both, and Hostaway shows them once.

Hostaway's own steps (support article 360002576293):
1. Log in at `https://dashboard.hostaway.com/`, then go to **Settings** > **Hostaway API**.
2. Click **Create**. Choose a **Name** (use `STR Secrets`) and a **Partner**. Partner selection is mandatory. Pick the generic option called **Hostaway Public API** (Hostaway describes it as the option "for software that is not part of our official partners").
3. Click **Create**.
4. "The Account ID and the API Key will be presented in a new window."
5. Copy both. Hostaway: "We will only show it once." And: "After you have generated it and left the page, it will no longer be visible to you or our support team." Keep that window open until both values are in your file.

Claude opens your `.env` for you. Paste each value right after the `=`, no quotes, no spaces, then save and say "saved":
```
HOSTAWAY_ACCOUNT_ID=
HOSTAWAY_API_KEY=
```
If you lose the window before pasting, no drama: go back to **Settings** > **Hostaway API** > **Create** and make a fresh pair.

**SAFE:** `if [ -d "$BUNDLE/.git" ]; then git -C "$BUNDLE" check-ignore -q .env && echo "protected ✅" || echo "add .env to $BUNDLE/.gitignore first"; else echo "protected ✅ (not a git folder, nothing can commit it)"; fi`
**FILLED:** `grep -q '^HOSTAWAY_ACCOUNT_ID=.\+' .env && grep -q '^HOSTAWAY_API_KEY=.\+' .env && echo "present ✅" || echo "still blank"`
**WORKS:** `bash -c '. lib/env.sh; . lib/probes.sh; env_load .env; probe_hostaway; echo rc=$?'` (0 works, 1 rejected, 2 blank, 3 unreachable)

**Build:** Follow `build/README.md` first, then `build/build-pms-mcp.md` (or `build-pricing-ops-mcp.md`) Steps B1 to B3 only (research, reference doc, write the server code into `$BUNDLE/mcp-servers/hostaway/`). Credentials, registering, fan-out and the restart are done from THIS file, not from the build doc. That step installs and compiles the server and leaves `dist/index.js` behind. Skip the build doc's own credential steps (its Step B3 `.env` block and sanity checks): your pair is already in the root `.env`, and `bash "$BUNDLE/fan-out-env.sh"` in the Register block copies it into the server's own `.env` at `$BUNDLE/mcp-servers/hostaway/.env`, which is where the built server reads its credentials from. Where the build doc's Hostaway brief disagrees with this file (it says 15 and 20 requests per 10 seconds; Hostaway's live docs say 200), this file wins. Four things the built server has to do, because Hostaway's API demands them:
- Exchange your pair for a Bearer token with `POST /v1/accessTokens` (form body `grant_type=client_credentials&client_id=<Account ID>&client_secret=<API Key>&scope=general`), then sleep 1 second before using it. Hostaway: "The token will be valid 1 second after being returned."
- Cache that token on disk in `$BUNDLE/.cache/hostaway.token` together with its `expires_in`, and reuse it. Hostaway: "Time to live ... is 24 months", though their sample response shows 184 days, so trust `expires_in`, not the prose. On any **403**, drop the cached token, exchange once more (with the 1-second sleep) and retry the call once; if the exchange itself fails with 401, surface "Hostaway credential revoked: create a new pair" instead of a raw error.
- Ship a `.env.example` listing `HOSTAWAY_ACCOUNT_ID` and `HOSTAWAY_API_KEY`, so `fan-out-env.sh` can fill the server's own `.env` from the root one.
- Handle 429 by reading `X-RateLimit-Retry-After` as a **Unix timestamp** (sleep until that time, max 30 seconds, then retry, up to 3 tries with a random extra delay). It is not a number of seconds to wait; a server that treats it as one hangs forever.

If `dist/index.js` is missing after the build step: `cd "$BUNDLE/mcp-servers/hostaway" && npm install --silent && npm run build --silent`.

**Register (macOS / Linux):**
```bash
bash "$BUNDLE/fan-out-env.sh"
uv run --python 3.13 python "$BUNDLE/lib/mcp_register.py" hostaway --stdio node "$BUNDLE/mcp-servers/hostaway/dist/index.js" && echo "hostaway registered ✅" || echo "register failed ❌"
echo hostaway >> "$BUNDLE/.cache/needs-restart"
```

**Register (Windows, Git Bash):** Claude Code is a native Windows process, so it must be handed a `C:\...` path. Convert with `cygpath -w` first and register the Windows form:
```bash
bash "$BUNDLE/fan-out-env.sh"
uv run --python 3.13 python "$BUNDLE/lib/mcp_register.py" hostaway --stdio node "$(cygpath -w "$BUNDLE/mcp-servers/hostaway/dist/index.js")" && echo "hostaway registered ✅" || echo "register failed ❌"
echo hostaway >> "$BUNDLE/.cache/needs-restart"
```
If Claude built the Python flavour instead of Node, the interpreter on Windows is `.venv/Scripts/python.exe` (not `.venv/bin/python`), and both the interpreter path and the `server.py` path go through `cygpath -w` the same way.

Then quit and reopen the Claude Code desktop app and say "Check my connections".

## 4. Path B: official MCP
_None for this connector._ Hostaway publishes no MCP server as of 2026-09-21 (their API docs and help center have zero mentions). The built server above is the whole story for now.

## 5. Verify
The checker runs `probe_hostaway`, which behaves exactly like the built server: it caches the exchanged token in `$BUNDLE/.cache/hostaway.token` and reuses it while it is under 23 hours old, re-exchanging only when the cache is missing or stale.
1. `POST https://api.hostaway.com/v1/accessTokens` with `grant_type=client_credentials&client_id=<Account ID>&client_secret=<API Key>&scope=general`, skipped when the cached token is still fresh. Hostaway's own table: "scope | yes | string | Should be general". Pass looks like HTTP 200 with a JSON body containing `access_token`.
2. `GET https://api.hostaway.com/v1/users` with `Authorization: Bearer <token>` and `Cache-control: no-cache`. HTTP 200 = the pair is real and the token works.

When a fresh exchange runs, the probe waits 1 second before the second call, as Hostaway requires, so a ❌ here is never the timing race.

Scoreboard row: **Hostaway API**. What the codes mean (checked against the live API on 2026-09-21):
- **rc=0, ✅:** both calls returned 200.
- **rc=1, ❌ rejected:** the exchange answered **401** `{"error":"invalid_client","error_description":"Client authentication failed"}`. That is a wrong Account ID, a wrong API Key, or an ID from one credential paired with the key from another. To see which call failed without printing your key, Claude runs: `bash -c '. lib/env.sh; env_load .env; curl -sS -m 15 -o /dev/null -w "exchange HTTP %{http_code}\n" -X POST -H "Content-type: application/x-www-form-urlencoded" --data "grant_type=client_credentials&client_id=$HOSTAWAY_ACCOUNT_ID&client_secret=$HOSTAWAY_API_KEY&scope=general" https://api.hostaway.com/v1/accessTokens'` (prints only the status code). 401 = re-copy both from a fresh **Create**. 200 = the pair is fine and the 403 came from /v1/users; see the next bullet.
- **rc=1, ❌ rejected, but the exchange passed (or the cached token was reused):** `/v1/users` answered **403** with `{"status":"fail","message":"The resource owner or authorization server denied the request."}`. Hostaway sends 403 for a missing, expired or revoked token. Because the probe re-exchanges whenever the cache is missing or older than 23 hours, a 403 on a token that was just exchanged fresh (not reused from cache) means the pair itself was revoked in Settings > Hostaway API, not a timing issue. The probe drops the cached token on a 403, so the next run always re-exchanges. If you want to force that yourself: `rm -f "$BUNDLE/.cache/hostaway.token"`, then re-run WORKS.
- **rc=2, blank:** one of the two lines in `.env` is empty. Both are needed.
- **rc=3, unreachable:** no answer or a 5xx from Hostaway. Check your internet, then try again in a minute.

## 6. Troubleshooting
- **I do not see Hostaway API under Settings.** Hostaway's article says "You can activate the API in the Hostaway Dashboard > Settings > Hostaway API", so it should be there for the account owner. We have NOT verified whether sub-users see it (as of 2026-09-21). Try the owner login first; if it is still missing, open the dashboard's support chat and ask them to enable the Public API on your account. No email path and no waiting list we know of.
- **I closed the window and never copied the key.** It is gone, and Hostaway support cannot see it either. Settings > Hostaway API > **Create** again, paste the new pair into `.env`, run `bash "$BUNDLE/fan-out-env.sh"`, re-check.
- **Create is greyed out or refuses to save.** You skipped the Partner. It is mandatory. Pick **Hostaway Public API**.
- **401 `invalid_client` on WORKS.** Nine times out of ten it is a stray space, quote or line break in `.env`, or an Account ID from one credential paired with the key from another. Open the file, fix the two lines, save, re-run FILLED then WORKS.
- **403 on the very first call after a new token.** The 1-second rule. Hostaway: "Please wait at least 1 second before making API calls using a newly issued token." The built server sleeps 1 second after every exchange; if you wrote your own quick test, add the sleep.
- **It worked last month, now every call is 403.** The server re-exchanges the token on its own. If it keeps failing, the pair was revoked in Settings > Hostaway API (the exchange answers 401): make a new one, paste it into `.env`, run `bash "$BUNDLE/fan-out-env.sh"`, re-check.
- **429 `This error occurs because a server detects that your application has exceeded the rate limits`.** Hostaway's limits (their docs, 2026-09-21): **200 requests per 10 seconds per account** and **200 per 10 seconds per IP** for regular endpoints, 30 per minute for sending guest messages, 400 per 10 seconds for price details. Sliding window, not a fixed clock. The 429 carries `X-RateLimit-Retry-After`, which is a Unix timestamp, not a number of seconds to wait. The built server backs off and retries up to 3 times; if you are hammering it from a loop, slow the loop.
- **Windows: `Failed to connect` after restart.** The server was registered with a `/c/Users/...` path. Re-run the Windows register block above; it overwrites the old entry with the `cygpath -w` form. Quit and reopen the Claude Code desktop app again.
- **The server can read but I want it to write (calendar, messages).** Every write tool is confirmation-gated: it previews the change and only sends it when Claude re-runs it with `confirm=true`. That is on purpose. Claude will always ask first.

## 7. Sources
support.hostaway.com article 360002576293 ("Hostaway API" credential creation; quoted via the 2026-09-21 vendor cards). api.hostaway.com/documentation (Authentication, "Working with authorization token", Rate limits; read live 2026-09-21). Error codes in section 5 confirmed with unauthenticated calls to `api.hostaway.com` on 2026-09-21.
