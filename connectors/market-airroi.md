---
server: airroi
slot: market
required: yes
env: [AIRROI_API_KEY]
official_mcp: https://mcp.airroi.com
---

# AirROI: short-term rental market data, by the call

## 1. What it is
AirROI is the market-data feed behind the summit. Search a market, pull comps, get revenue and occupancy numbers for a listing or an area. The Comping Agent, the Listing Optimizer and the Revenue Manager all read from it. This kit wires it up twice: a bundled Python server (`airroi`, ours, runs on uv) and AirROI's own hosted MCP (`airroi-official`). Both use the same key and the same credit balance, so one deposit covers both.

## 2. Required, cost, gate
Required. Pay as you go, no subscription. AirROI's words: "Deposit a minimum of $10 to activate your API key. Credits never expire." Each call costs between $0.01 and $1.00, and "each MCP tool call consumes the same credits as the equivalent REST API call." The key does nothing until the $10 is in; that is the only gate. No plan tier, no email to anyone.

## 3. Path A: API key
1. Go to https://www.airroi.com/api/developer/activate and sign up with email, Google or GitHub.
2. Add API credits. Deposit at least $10. AirROI says the key "is activated instantly after deposit."
3. Open the dashboard at https://www.airroi.com/api/developer and copy your API key.

One key, one line in `.env`. The key is a 40-character run of letters and digits, no prefix, no dashes. You copy it from the dashboard page at https://www.airroi.com/api/developer, so if you lose it, go back to that page rather than making a new account. Claude opens the file for you; put the key after the equals sign, save, close. The file is the only place it goes. The chat window is never the place for it.
```
AIRROI_API_KEY=
```

**SAFE:** `git check-ignore -q .env && echo "protected ✅"`
**FILLED:** `grep -q '^AIRROI_API_KEY=.\+' .env && echo "present ✅" || echo "still blank"`
**WORKS:** `bash -c '. lib/env.sh; . lib/probes.sh; env_load .env; probe_airroi; echo rc=$?'` (0 works, 1 rejected, 2 blank, 3 unreachable)

Then copy it into the server's own `.env` (the root file stays the master; this only fills the copy the bundled server reads):
```bash
cd "$BUNDLE" && bash fan-out-env.sh
```
Run this again after any `.env` change.

**Register** the bundled server. Build its venv, then point Claude Code at it:
```bash
cd "$BUNDLE/mcp-servers/airroi" && uv venv --quiet .venv && uv pip install --quiet -r requirements.txt --python .venv
claude mcp remove airroi -s user >/dev/null 2>&1 || true
claude mcp add --transport stdio airroi --scope user -- "$BUNDLE/mcp-servers/airroi/.venv/bin/python" "$BUNDLE/mcp-servers/airroi/server.py" >/dev/null 2>&1 && echo "airroi registered ✅" || echo "register failed ❌"
echo airroi >> "$BUNDLE/.cache/needs-restart"
```
The server reads the key from its own `.env`, which `fan-out-env.sh` fills from the root `.env`. The key itself never goes into the `claude mcp add` line.

**Windows note:** the venv interpreter is `.venv/Scripts/python.exe`, not `.venv/bin/python`, and Claude Code is a native Windows process, so every absolute path gets converted with `cygpath -w` before it is registered. Same build line, then:
```bash
claude mcp remove airroi -s user >/dev/null 2>&1 || true
claude mcp add --transport stdio airroi --scope user -- "$(cygpath -w "$BUNDLE/mcp-servers/airroi/.venv/Scripts/python.exe")" "$(cygpath -w "$BUNDLE/mcp-servers/airroi/server.py")" >/dev/null 2>&1 && echo "airroi registered ✅" || echo "register failed ❌"
echo airroi >> "$BUNDLE/.cache/needs-restart"
```

## 4. Path B: official MCP
AirROI hosts its own MCP at https://mcp.airroi.com. Auth is the key in a header, not a browser login, so there is no `/mcp` > Authenticate step and no browser window will open. Source the `.env` first so the shell can read the key, then register:
```bash
set -a; . "$BUNDLE/.env"; set +a
if [ -z "${AIRROI_API_KEY:-}" ]; then
  echo "AIRROI_API_KEY is still blank in .env; finish section 3 first"
else
  claude mcp remove airroi-official -s user >/dev/null 2>&1 || true
  claude mcp add --transport http airroi-official --scope user https://mcp.airroi.com --header "X-API-KEY: $AIRROI_API_KEY" >/dev/null 2>&1 && echo "airroi-official registered ✅" || echo "register failed ❌"
  echo airroi-official >> "$BUNDLE/.cache/needs-restart"
fi
```
Keep the `X-API-KEY:` prefix exactly as written; the vendor's setup page says so. Their getting-started page spells it lowercase `x-api-key`. Both work, HTTP headers are case-insensitive.

The header is stored in `~/.claude.json`, never in this folder. `claude mcp list` does not print header values, but we still never paste raw `claude mcp list` output into the chat, because one other server in this kit (RankBreeze) carries its key in the URL.

What you get: read-only market and listing tools, the same data as the REST API, billed per call from the same balance. No beta, no waitlist as of 2026-09-21. Restart Claude Code after registering; `/mcp` should then list both `airroi` and `airroi-official`.

## 5. Verify
The checker runs `probe_airroi`, which makes one real call: `GET https://api.airroi.com/markets/search?query=miami` with your key in the `X-API-KEY` header. It costs $0.01. Outcomes:

- **200** with market results: works. Row shows ✅.
- **403 `Forbidden`**: the key is not active. Almost always the $10 deposit has not landed. Deposit, wait a moment, say "Check my connections" again. Also 403 if the key was copied wrong.
- **Blank**: the `.env` line is empty. Paste the key.
- **Unreachable**: no network, or AirROI is down. Try again in a minute.

The official MCP row checks three things: the `.env` line is filled, `airroi-official` is registered, and Claude Code reports it Connected. It cannot see whether the header holds the same key as `.env`. Two things to know: `claude mcp list` shows `airroi-official` as Connected even when the key is bad, because the handshake does not check it; and if you ever change the key in `.env`, the header keeps the old one until you re-run the section 4 block. Trust the probe, not the Connected label, and re-register after a key change.

## 6. Troubleshooting
- **403 right after signing up:** you have an account but no credits. The key only switches on after the $10 deposit. Go back to https://www.airroi.com/api/developer and add credits.
- **Worked yesterday, 403 today:** check the credit balance on the dashboard. Deposits never expire, but they do run out. Top up.
- **Numbers look off between markets:** currency defaults to each market's native currency. A Cancun comp is in pesos, a Nashville comp is in dollars. Ask Claude to state the currency before comparing.
- **A field you saw in one call is missing in another:** response keys differ per endpoint. Market search, listing metrics and estimates each return their own shape. That is AirROI, not a broken key.
- **Rate limit:** 1,000 requests per minute per key. The summit skills never get close; if you do, you are looping.
- **Header spelling:** `X-API-KEY` on the MCP page, `x-api-key` on the getting-started page. Same header. Do not "fix" one to match the other.
- **`airroi` shows Failed after restart (Windows):** the registered path is probably `/c/Users/...` instead of `C:\Users\...`, or it points at `.venv/bin/python`, which does not exist on Windows. Remove it (`claude mcp remove airroi -s user`) and re-run the Windows register block in section 3.
- **`ModuleNotFoundError: mcp.server.fastmcp`:** the venv picked up `mcp` 2.x. The bundled `requirements.txt` pins `mcp>=1.2,<2`; delete `.venv` and run the build line again.
- **You changed the key in .env:** the bundled `airroi` server picks the new one up after `bash fan-out-env.sh` and a restart, but `airroi-official` keeps the key it was registered with. Re-run the section 4 block (it removes and re-adds), then restart.
- **`airroi` shows Connected but `health_check` says ok false:** the server's own `.env` is empty. Run `cd "$BUNDLE" && bash fan-out-env.sh`, then restart Claude Code.
- **Registered while the .env line was still blank:** the row can show Connected with an empty header. Run FILLED, fix the line, then re-run the section 4 block (it removes and re-adds) and restart.

## 7. Sources
airroi.com/api/getting-started, airroi.com/api/pricing, airroi.com/mcp-server/setup, airroi.com/api/developer, airroi.com/api/developer/activate (read 2026-09-21).
