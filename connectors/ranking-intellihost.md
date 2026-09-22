---
server: intellihost
slot: ranking
required: optional
env: []
official_mcp: https://clients.intellihost.co/api/mcp
---

# IntelliHost: Airbnb ranking and listing performance, straight from the vendor's MCP

## 1. What it is
IntelliHost is a listing-performance tool for Airbnb hosts. In the summit kit it fills the same slot as RankBreeze: the visibility spoke (search rank, listing performance) that the Revenue Manager skill leans on when it asks "why is this listing not getting booked". IntelliHost ships its own MCP server, so there is nothing to build and nothing to paste. Claude signs in through your browser and gets your account info and property list for free, and on the IntelliHost Agent plan it also gets pricing recommendations, revenue reports and Helix predictions.

## 2. Required, cost, gate
Optional. Pick RankBreeze, IntelliHost, or neither. If you run neither, the Revenue Manager still works, it just cannot see your search rank.

No cost to connect. IntelliHost's own words: "Free tools (account info, list properties) work without a subscription." The property-specific tools (pricing recommendations, revenue reports, Helix predictions) "require an active IntelliHost Agent subscription". On their pricing page the row "MCP (AI Integration)" is ticked for the Agent plan only. Agent was listed at about $49.99 per listing per month on a sliding scale when we read intellihost.co/pricing on 2026-09-21; check the page for today's number. There is a 7-day trial with no card, but we have not confirmed whether the trial unlocks the MCP property tools. So: free to prove the connection, paid to get anything the Revenue Manager can use. RankBreeze's MCP is on every listing plan; if you are choosing between them on price, that matters.

No email, no waitlist, no API key. IntelliHost has no public REST API at all: the MCP is the only way code talks to it. Nothing goes in `.env` for this one.

Watch the domain: **intellihost.co** is this tool. **intellihost.io** is a PriceLabs product now. If the sign-in page does not look like IntelliHost, check the address bar.

## 3. Path A: API key
_None for this connector._ There is no public API and no key to fetch. Go straight to Path B.

## 4. Path B: official MCP
This is the vendor's own Claude Code command, lifted from their Connections page (clients.intellihost.co > **Connections** > card "Connect an AI assistant" > **Claude Code** tab, which says "Run this command in your terminal:"). We add `--scope user` so it follows you into every project.

**Register:**
```bash
claude mcp add intellihost --transport http https://clients.intellihost.co/api/mcp --scope user >/dev/null 2>&1 && echo "intellihost registered ✅" || echo "intellihost failed ❌ (run the same line without the >/dev/null part to see why)"
echo intellihost >> "$BUNDLE/.cache/needs-restart"
```
Windows: run this in Git Bash (Claude's Bash tool). Nothing on the `claude mcp add` line is a file path, so no `cygpath -w` and no `.venv/Scripts/python.exe` here. The `$BUNDLE/.cache/needs-restart` write stays inside Bash and works as-is.

**Restart Claude Code.** Then type `/mcp`, pick **intellihost**, choose **Authenticate**. Claude Code opens a browser link. Follow it, sign in to IntelliHost, and authorize the connection. If the browser does not open on its own, copy the link Claude Code prints and open it yourself. Finish the sign-in on the same machine Claude Code is running on.

If the sign-in screen asks how much access to give, pick **read-only**. Read and write lets Claude push live prices to your listings, and the summit skills never need that.

You can see the same card any time at clients.intellihost.co > **Connections** > the MCP card > **Claude Code** tab.

Capability warning: what IntelliHost shows Claude depends on your plan. Without the Agent plan you get account info and your property list, which is enough to prove the connection but not enough to run the ranking analysis. Nothing on the Connections page is marked beta or waitlist as of 2026-09-21. One thing we could not verify: whether a Premium or trial account sees the Connections page at all (the page is login-gated, and the pricing table ticks MCP for Agent only). If your sidebar has no Connections item, that is the plan gate, not a mistake on your side.

As of 2026-09-21 the vendor names these MCP tools: account info, list properties, pricing recommendations, revenue reports, Helix predictions. We have not seen the full tool list, so whether search rank and funnel numbers come through the MCP (rather than only inside the IntelliHost app) is unverified. If the Revenue Manager asks for rank and IntelliHost has no tool for it, that is why. RankBreeze exposes rank directly; if rank is the number you care about, pick RankBreeze.

## 5. Verify
The checker (`check-connections.sh`) reads the `intellihost` line's status from Claude Code's own server list (name and status only; nothing else is printed) and shows one row, **IntelliHost MCP**:

- `✅ IntelliHost MCP   connected` is the pass. Claude Code sees the server as `✔ Connected`.
- `⚠️ IntelliHost MCP   registered, not authenticated (/mcp > Authenticate)` means the browser sign-in has not been finished. Run `/mcp` > intellihost > **Authenticate** and complete it.
- `🔒 IntelliHost MCP   needs a full restart of Claude Code` means you registered this session and have not restarted yet. Quit Claude Code fully, reopen it in this folder, say "Check my connections".
- `❌ IntelliHost MCP   missing → not registered` means the register block in section 4 has not run.
- `⚠️ IntelliHost MCP   registered, key fails → server status: failed` means Claude Code could not reach or talk to the server. If you connected with the browser sign-in (section 4), there is no key involved: the sign-in expired or IntelliHost is down. Run `/mcp` > intellihost > **Authenticate** again; if it still fails, wait a few minutes and try again. If you used the access-token fallback (section 6), the word is right: the token is wrong, revoked, or was copied with a typo. Authenticate will not help there. Make a new token in IntelliHost > Connections > MCP access tokens and run the fallback block again.
- `➖ IntelliHost MCP   not used`: not used just means you told Claude you use RankBreeze or no ranking tool. Nothing to do.
- A hint saying `approve it in /mcp` means Claude Code is waiting for you to approve the server. Open `/mcp` and approve it.

The real-call test, after the restart: ask Claude "IntelliHost, list my properties". That is one of the free tools, so it works on any IntelliHost account. If it comes back with your listings, the connection is real. If Claude answers with a subscription message on a pricing or revenue question, the connection is fine, that tool is gated to the Agent plan (section 2).

## 6. Troubleshooting
- **`/mcp` says it needs authentication, again:** the browser sign-in was not finished, or it was finished on a different machine. Run Authenticate once more and complete it in the browser that opens.
- **Pricing, revenue or Helix questions return a subscription error:** expected without the IntelliHost Agent plan. Account info and list properties are free; the rest is gated. Upgrade at intellihost.co/pricing or run RankBreeze instead.
- **Sign-in page looks wrong or the account is not found:** you are on intellihost.io (PriceLabs). Use clients.intellihost.co.
- **Claude is offering to change prices:** you granted read and write. Disconnect the assistant in IntelliHost > Connections, re-run Authenticate, and pick read-only.
- **Funnel numbers look thin or empty:** IntelliHost gathers its funnel data through its Chrome extension. Make sure the extension is installed and running in your Chrome, then ask again.
- **Scoreboard stays on Restart:** the `needs-restart` marker is cleared by the setup flow, not by the restart itself. Quit Claude Code fully (not just the tab), reopen it in this same folder, and say "Check my connections". If you ran `bash check-connections.sh` by hand instead, clear the marker first: `: > "$BUNDLE/.cache/needs-restart"`.
- **The register block printed nothing, no ✅ and no error:** the server is already registered from an earlier try (maybe from IntelliHost's own command without `--scope user`). Remove it, then run the register block again: `claude mcp remove intellihost --scope user`. If you ran the vendor's line in a plain terminal before, also run `claude mcp remove intellihost --scope local`.
- **The browser sign-in loops, errors, or never finishes:** fall back to an IntelliHost access token. In IntelliHost > Connections > MCP access tokens, create one named `Claude Code` with Access **Read only**. IntelliHost shows it once. Do not paste it into Claude's chat. Open a terminal window of your own (Terminal on Mac, Git Bash on Windows) and paste these lines in, replacing `<token>` with the token you copied:
  ```bash
  curl -s -X POST https://clients.intellihost.co/api/mcp -H "Authorization: Bearer <token>" -H "Content-Type: application/json" -H "Accept: application/json, text/event-stream" -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'
  ```
  A list of tools means the token works. `{"message":"Unauthenticated."}` (HTTP 401) means the token is wrong; that is the same answer IntelliHost gives with no token at all (checked 2026-09-21). When it works, register it in the same terminal:
  ```bash
  claude mcp remove intellihost --scope user >/dev/null 2>&1
  claude mcp add --transport http intellihost --scope user https://clients.intellihost.co/api/mcp --header "Authorization: Bearer <token>"
  ```
  You should see `Added HTTP MCP server intellihost` and a `Headers` block showing `[REDACTED]` where your token is; Claude Code hides it on screen but stores it. Close that terminal, come back to Claude and say "I registered IntelliHost with a token". Claude then runs `echo intellihost >> "$BUNDLE/.cache/needs-restart"` for you (the `$BUNDLE` shortcut only exists inside Claude's Bash tool, which is why that line does not go in your terminal). Restart. No Authenticate step this time; the header carries the sign-in. The header lives in `~/.claude.json`, one more reason never to print `claude mcp list`.
- **You see "MCP access tokens" in IntelliHost:** those long-lived tokens are for assistants that want an API key instead of a sign-in (ChatGPT, Cursor). The kit only needs one if the browser sign-in fails (bullet above). If you create one, IntelliHost shows it only once, so pick **Read only** and never paste it in chat.

## 7. Sources
clients.intellihost.co/connections (login-gated; text taken from the shipped app bundle app-vNMM7W01.js, read 2026-09-21). intellihost.co/pricing (read 2026-09-21). Register command shape and server name from the kit brief, task 9 step 4.
