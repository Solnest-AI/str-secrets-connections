---
server: rankbreeze
slot: ranking
required: optional
env: [RANKBREEZE_MCP_URL]
official_mcp: https://app.rankbreeze.com/api/mcp/rb_mcp_<key>
---

# RankBreeze: where your listing sits in Airbnb search, and how many people actually see it

## 1. What it is
RankBreeze tracks your Airbnb search rank, first-page impressions, click-through rate, page views, wishlists and booking rate, per listing, per day. It is the visibility spoke of the Revenue Manager: pricing tells you what to charge, RankBreeze tells you whether anyone is seeing the listing at that price. The Revenue Manager reads it through RankBreeze's own hosted MCP server, registered in Claude Code as `rankbreeze`. Read-only, 15 tools, nothing to install.

## 2. Required, cost, gate
Optional. Pick RankBreeze, IntelliHost, or neither. If you pick RankBreeze, this is the whole setup.

No extra cost and no plan gate. RankBreeze's own FAQ: "Do I need a specific Rankbreeze plan to use the MCP? No, the Rankbreeze MCP is available on all listing plans." It is instant. No email, no form, no waiting on a human.

We do not use RankBreeze's REST API. That one is an Enterprise add-on and needs a support ticket. Skip it. The MCP covers everything the summit skills need.

## 3. Path A: API key
_The key path IS the URL._ RankBreeze does not hand you a separate key. It hands you a URL with the secret baked into it, and that URL is the whole config.

**Click path:**
1. Log in at `https://app.rankbreeze.com` and click **Settings** in the left sidebar.
2. Under **MCP Credentials**, open **MCP Access**.
3. In the **Remote MCP** section, click **+ Add URL** and name it `Claude Code`. (RankBreeze's tip: one URL per AI tool, so you can revoke one later without touching the others.) Then click **Copy URL** on that row. Already have a URL there and only use Claude Code? Just click **Copy URL** on it.

**What it looks like:** `https://app.rankbreeze.com/api/mcp/rb_mcp_` followed by a long random string. The vendor page does not print that pattern; we confirmed it against the live server on 2026-09-21. It is not shown once: the Remote MCP table keeps it, and Copy URL works any time until you hit Reset URL or the delete icon.

**That URL is your password: never paste it in chat, Skool, or a screenshot.** If it ever gets out, click **Reset URL** in RankBreeze and paste the new one into `.env`.

**The .env line** (Claude opens the file for you; paste the WHOLE URL after the `=`, no quotes, no spaces):
```
RANKBREEZE_MCP_URL=
```

Then, from the bundle folder (`cd "$BUNDLE"`):

**SAFE:** `if [ -d "$BUNDLE/.git" ]; then git -C "$BUNDLE" check-ignore -q .env && echo "protected ✅" || echo "add .env to $BUNDLE/.gitignore first"; else echo "protected ✅ (not a git folder, nothing can commit it)"; fi`
**FILLED:** `grep -q '^RANKBREEZE_MCP_URL=.\+' .env && echo "present ✅" || echo "still blank"`
**WORKS:** one real call to the server. Prints only an HTTP code, never the URL:
```bash
bash -c '. lib/env.sh; env_load .env; [ -n "${RANKBREEZE_MCP_URL:-}" ] || { echo "still blank"; exit 2; }; code=$(curl -s -m 15 -o /dev/null -w "%{http_code}" -X POST -H "Content-Type: application/json" -H "Accept: application/json, text/event-stream" -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"ping\"}" "$RANKBREEZE_MCP_URL" 2>/dev/null); echo "http=$code"'
```
`http=200` works. `http=401` means the URL is wrong or was reset (re-copy it). `http=000` means the server was unreachable (retry). `still blank` means the line is empty.

**Register:**
```bash
set -a; . "$BUNDLE/.env"; set +a
uv run --python 3.13 python "$BUNDLE/lib/mcp_register.py" rankbreeze --http "$RANKBREEZE_MCP_URL" && echo "rankbreeze registered ✅" || echo "rankbreeze register failed ❌ (see section 6)"
echo rankbreeze >> "$BUNDLE/.cache/needs-restart"
```
The helper never prints the URL, on success or failure, so it is safe to run as-is.

Then quit and reopen the Claude Code desktop app. New servers only show up after a restart.

**Windows note:** run this under Git Bash (that is what Claude's Bash tool is). The `$BUNDLE/.env` and `$BUNDLE/.cache/needs-restart` paths are read by bash itself, so the Git Bash form (`/c/Users/...`) is correct as-is. Nothing here needs `cygpath -w` or `.venv/Scripts/python.exe`: the only thing handed to the register helper is the URL, and a URL is the same on every OS.

## 4. Path B: official MCP
This IS the official MCP. There is no separate path and no second server name. The register line from section 3 registers it as an `http` server; it takes the URL alone, no `--header`.

**Auth:** none in the browser. The URL carries the secret, so there is no `/mcp` > Authenticate step and no sign-in window. If Claude Code ever asks you to authenticate `rankbreeze`, the URL is wrong.

**Capability warning:** read-only. RankBreeze says so: "The Rankbreeze MCP is read-only." It can tell you your rank, your funnel, your competitors' pricing and your price recommendations. It cannot change a price, a title, or a photo. Any change it suggests goes through your PMS or pricing tool.

**Status (2026-09-21):** live, not beta, no waitlist, on every listing plan.

## 5. Verify
The checker (`check-connections.sh`) does two things for the `RankBreeze MCP` row: it confirms `RANKBREEZE_MCP_URL` is filled in `.env`, and it reads the `rankbreeze` entry's status (name and status only; the URL is never printed). If a `claude` CLI happens to be on this machine it reads live connection status from it; inside the desktop app with no CLI on PATH it reports `registered` once the entry exists in `~/.claude.json`, which the scoreboard treats the same as connected.

- `✅ RankBreeze MCP   connected` is the pass.
- `❌ RankBreeze MCP   missing → paste it into .env` means the line in `.env` is blank.
- `❌ RankBreeze MCP   missing → not registered` means the register step has not run.
- `🔒 RankBreeze MCP   needs a full restart of Claude Code` means you registered but have not restarted yet.
- `⚠️ RankBreeze MCP   registered, key fails → server status: failed` means Claude Code could not connect: the URL in `.env` is wrong, truncated, or was reset.
- `➖ RankBreeze MCP   not used` means `STACK_RANKING` in `.env` is not set to `rankbreeze`. The checker skips this row entirely until it is. Tell Claude "I use RankBreeze" (or put `STACK_RANKING=rankbreeze` in `.env` yourself), then run the checker again.

**The real proof, after the restart:** ask Claude "RankBreeze, look up my account". Claude calls `lookup_current_user` and comes back with your account and listing count. That is the end-to-end test, and it never needs the raw URL printed anywhere.

**The vendor's real codes** (if you ever curl it): `200` with a valid URL; `401` with body `{"jsonrpc":"2.0","id":null,"error":{"code":-32001,"message":"Unauthorized"}}` when the key part is wrong or reset; `405` if you GET instead of POST (the server is POST-only). All three confirmed live 2026-09-21.

## 6. Troubleshooting
- **Reset URL kills the old one instantly.** Clicked Reset URL, or deleted the row, in RankBreeze? The URL Claude Code has is dead that second. Copy the new one, paste it over the old line in `.env`, then re-run the Register block in section 3 (it overwrites the old entry), quit and reopen the Claude Code desktop app.
- **`✘ Failed to connect, Dynamic Client Registration rejected (HTTP 404)` after the restart.** That long message is what Claude Code prints when RankBreeze rejects the URL; ignore the words "Client Registration" and "404 Not Found", they do not mean RankBreeze is down. Nine times out of ten the URL in `.env` is incomplete or was reset. Re-copy it from the Remote MCP table with the Copy URL button (that avoids the typos retyping it by hand tends to cause), make sure there are no quotes or spaces around it, then run WORKS. `http=401` confirms it is the URL. Fix `.env`, re-run the Register block.
- **Ran Register while the `.env` line was still blank.** `mcp_register.py` reads the URL straight from `$RANKBREEZE_MCP_URL`; if `.env` is blank, that variable expands to nothing and the register line prints the `register failed ❌` branch instead of the ✅ line. Run FILLED, fix the line, then run the Register block again.
- **Register printed `register failed ❌` instead of the ✅ line.** The helper never prints the URL, on success or failure, so it is always safe to see the full message. Most likely the `.env` line is blank (run FILLED). Nothing to remove first: re-running the Register block always overwrites whatever was there.
- **Impressions, click-through, views, wishlists, and booking rate all come back 0.** That listing is not connected to Airbnb Hosting inside RankBreeze. RankBreeze returns 0 for every performance field on an unconnected listing ("not tracked," not "no activity"). Connect the listing's Airbnb Hosting account in RankBreeze; real numbers show up within about 24 hours. Search rankings are not affected by this: RankBreeze gathers those by searching Airbnb directly, so if rankings are missing the cause is something else (ask Claude to check the listing's status with `get_user_listings`).
- **The numbers look a day behind.** They are. RankBreeze collects rankings nightly and imports Airbnb data daily. Ask for yesterday, not today; today's numbers are usually still partial.
- **You pasted the URL in chat, Skool, or a screenshot.** Treat it as burned. Reset URL in RankBreeze, re-paste, re-register, restart. Takes two minutes.
- **No "API" item in your RankBreeze sidebar.** That is the REST add-on, and we do not use it. You are not missing anything. MCP Access under Settings is all you need.

## 7. Sources
RankBreeze support article 16382284, "Remote MCP" setup and FAQ (support.rankbreeze.com/en/articles/16382284, read 2026-09-21). RankBreeze API docs at app.rankbreeze.com/api-docs (REST add-on, read 2026-09-21; deliberately not used). Live checks against the hosted MCP endpoint from Ryan's account, 2026-09-21: 200 valid, 401 bogus, 405 GET. Claude Code MCP docs, code.claude.com/docs/en/mcp (read 2026-09-21).
