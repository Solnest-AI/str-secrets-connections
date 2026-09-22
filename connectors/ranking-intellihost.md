---
server: intellihost
slot: ranking
required: optional
env: [INTELLIHOST_MCP_TOKEN]
official_mcp: https://clients.intellihost.co/api/mcp
portal: https://clients.intellihost.co
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
IntelliHost's own Connections page (clients.intellihost.co > **Connections** > card "Connect an AI assistant" > **Claude Code** tab) hands out a CLI command for this. Use the app's own Connectors screen instead:

**Claude does not register this one. You add it in the app, it takes about a minute.**
1. In the Claude Code desktop app, click the **+** next to the message box, then **Connectors**, then **Manage connectors**. The Connectors settings page opens.
2. Click **+ Add** (top right), then **Add custom connector**.
3. Type a name (IntelliHost is fine) and paste `https://clients.intellihost.co/api/mcp` into **MCP server URL**. Click **Continue**.
4. A browser tab opens. Sign in to IntelliHost and authorize the connection. If the browser does not open on its own, copy the link Claude Code prints and open it yourself. Finish the sign-in on the same machine Claude Code is running on.
5. Done, it is on automatically. Come back and tell Claude "connected".

If the sign-in screen asks how much access to give, pick **read-only**. Read and write lets Claude push live prices to your listings, and the summit skills never need that.

Claude runs the live check right after, see section 5.

You can see the same card any time at clients.intellihost.co > **Connections** > the MCP card > **Claude Code** tab.

Capability warning: what IntelliHost shows Claude depends on your plan. Without the Agent plan you get account info and your property list, which is enough to prove the connection but not enough to run the ranking analysis. Nothing on the Connections page is marked beta or waitlist as of 2026-09-21. One thing we could not verify: whether a Premium or trial account sees the Connections page at all (the page is login-gated, and the pricing table ticks MCP for Agent only). If your sidebar has no Connections item, that is the plan gate, not a mistake on your side.

As of 2026-09-21 the vendor names these MCP tools: account info, list properties, pricing recommendations, revenue reports, Helix predictions. We have not seen the full tool list, so whether search rank and funnel numbers come through the MCP (rather than only inside the IntelliHost app) is unverified. If the Revenue Manager asks for rank and IntelliHost has no tool for it, that is why. RankBreeze exposes rank directly; if rank is the number you care about, pick RankBreeze.

## 5. Verify
This row is not driven by `~/.claude.json`. The app delivers a Connectors-UI sign-in straight to the chat session, invisible to the checker, so the row always prints `🔎 IntelliHost MCP   add it under + > Connectors; Claude checks it live`, whether or not you have added it yet, and even if you used the access-token fallback in section 6 (that path really is registered and working, the row text just cannot see it).

- `➖ IntelliHost MCP   not used`: not used just means you told Claude you use RankBreeze or no ranking tool. Nothing to do.
- Not added yet: run section 4, then tell Claude "connected".
- Added, or using the fallback token: Claude runs the live check in the chat, see below.
- Live check comes back empty or says the tool is not available: Connect probably did not finish in the browser, or the sign-in expired. Open + > Connectors, check IntelliHost shows connected, and try again.

The live check: ask Claude "IntelliHost, list my properties". That is one of the free tools, so it works on any IntelliHost account. If it comes back with your listings, the connection is real. If Claude answers with a subscription message on a pricing or revenue question, the connection is fine, that tool is gated to the Agent plan (section 2).

## 6. Troubleshooting
- **IntelliHost tools are not showing up, again:** the browser sign-in was not finished, or it was finished on a different machine. Remove the connector under + > Connectors > Manage connectors, add it again, and finish the sign-in on this same machine.
- **Pricing, revenue or Helix questions return a subscription error:** expected without the IntelliHost Agent plan. Account info and list properties are free; the rest is gated. Upgrade at intellihost.co/pricing or run RankBreeze instead.
- **Sign-in page looks wrong or the account is not found:** you are on intellihost.io (PriceLabs). Use clients.intellihost.co.
- **Claude is offering to change prices:** you granted read and write. Disconnect the assistant in IntelliHost > Connections, remove and re-add the connector, and pick read-only.
- **Funnel numbers look thin or empty:** IntelliHost gathers its funnel data through its Chrome extension. Make sure the extension is installed and running in your Chrome, then ask again.
- **Scoreboard stays on Restart (only happens if you used the access-token fallback below):** the `needs-restart` marker is cleared by the setup flow, not by the restart itself. Quit the Claude Code desktop app fully (not just the window), reopen it in this same folder, and say "Check my connections". If you ran `bash check-connections.sh` by hand instead, clear the marker first: `: > "$BUNDLE/.cache/needs-restart"`. The Connectors-UI sign-in in section 4 never needs a restart.
- **The browser sign-in loops, errors, or never finishes:** fall back to an IntelliHost access token. In IntelliHost > Connections > MCP access tokens, create one named `Claude Code` with Access **Read only**. IntelliHost shows it once. Claude opens `.env` for you; paste it on this line, no quotes, no spaces, save, and never in the chat:
  ```
  INTELLIHOST_MCP_TOKEN=
  ```
  Claude can check the token works without ever printing it (a tool list coming back means it is good; `{"message":"Unauthenticated."}`, HTTP 401, means it is wrong; that is the same answer IntelliHost gives with no token at all, checked 2026-09-21):
  ```bash
  set -a; . "$BUNDLE/.env"; set +a
  curl -s -X POST https://clients.intellihost.co/api/mcp -H "Authorization: Bearer $INTELLIHOST_MCP_TOKEN" -H "Content-Type: application/json" -H "Accept: application/json, text/event-stream" -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'
  ```
  Then Claude registers it as a header:
  ```bash
  set -a; . "$BUNDLE/.env"; set +a
  uv run --python 3.13 python "$BUNDLE/lib/mcp_register.py" intellihost --http https://clients.intellihost.co/api/mcp --header "Authorization: Bearer INTELLIHOST_MCP_TOKEN" && echo "intellihost registered ✅" || echo "intellihost register failed ❌"
  echo intellihost >> "$BUNDLE/.cache/needs-restart"
  ```
  Quit and reopen the Claude Code desktop app. No Authenticate step this time; the header carries the sign-in. The header lives in `~/.claude.json`, one more reason never to print its raw contents.
- **You see "MCP access tokens" in IntelliHost:** those long-lived tokens are for assistants that want an API key instead of a sign-in (ChatGPT, Cursor). The kit only needs one if the browser sign-in fails (bullet above). If you create one, IntelliHost shows it only once, so pick **Read only** and never paste it in chat.

## 7. Sources
clients.intellihost.co/connections (login-gated; text taken from the shipped app bundle app-vNMM7W01.js, read 2026-09-21). intellihost.co/pricing (read 2026-09-21). Register command shape and server name from the kit brief, task 9 step 4.
