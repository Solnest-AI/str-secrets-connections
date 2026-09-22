---
server: beyond
slot: pricing
required: one-of
env: [BEYOND_TOKEN]
official_mcp: https://neyoba.beyondpricing.com/mcp
portal: https://v2.beyondpricing.com/dashboard/user/personal-access-tokens
---

# Beyond: dynamic pricing for the Revenue Manager

## 1. What it is
Beyond (formerly Beyond Pricing) is a dynamic pricing engine. It reads your PMS calendar and pushes nightly rates. The Revenue Manager uses it as the pricing spoke: it pulls Beyond's recommendations, your calendar, and your per-listing customizations (base, floor, ceiling, min stay) and cross-checks them against what is really on your PMS calendar. You need one pricing tool, PriceLabs or Beyond. If you use Beyond, this is your file. Two connections live here: a server Claude builds on your machine from Beyond's Partners API (`beyond`), and Beyond's own MCP, called Neyoba (`beyond-official`).

## 2. Required, cost, gate
One pricing tool is required (PriceLabs or Beyond). No email to send.

**Beyond Pro is the gate.** Beyond's docs: a personal access token needs an active Beyond Pro trial or subscription. When the trial or subscription ends, Beyond revokes your tokens and every request answers 401. If you cannot find the Personal Access Tokens page, or Generate refuses, the likely cause is that your account is not on Pro (unverified: Beyond does not document what non-Pro accounts see). Upgrading is "Request Pro" inside the app: a Beyond person contacts you, so it is not instant. Ask today. The only cost Beyond's docs tie to the token is the Pro plan itself.

**The MCP (Neyoba) is beta**, read-only, and Beyond says it is available to all Beyond customers at no additional cost during the beta. Their marketing page still says waitlist. Try it anyway; the worst case is a consent page that says no.

## 3. Path A: API key
Beyond calls it a Personal Access Token (PAT). It is for automating your own account, which is exactly this. No partner app, no client secret, no browser step.

1. Log in to Beyond.
2. Sign-in icon (top right) > **Settings** > **Personal Access Tokens**. Direct link: https://v2.beyondpricing.com/dashboard/user/personal-access-tokens
3. Generate a token. The value starts with `bpat_`. Beyond shows it exactly once. Copy it now.
4. Drop it on this line in `.env` (Claude opens the file for you; never type the token into the chat), then save and tell Claude "saved":
   ```
   BEYOND_TOKEN=
   ```
   Whole thing, right after the `=`, no quotes, no spaces.

The token has no permission settings of its own. It does whatever your Beyond login can do. Treat it like your password. Lost it? Generate a new one; the old one cannot be shown again.

**SAFE:** `if [ -d "$BUNDLE/.git" ]; then git -C "$BUNDLE" check-ignore -q .env && echo "protected ✅" || echo "add .env to $BUNDLE/.gitignore first"; else echo "protected ✅ (not a git folder, nothing can commit it)"; fi`
**FILLED:** `grep -q '^BEYOND_TOKEN=.\+' "$BUNDLE/.env" && echo "present ✅" || echo "still blank"`
**WORKS:** `cd "$BUNDLE" && bash -c '. lib/env.sh; . lib/probes.sh; env_load .env; probe_beyond; echo rc=$?'` (0 works, 1 rejected, 2 blank, 3 unreachable)

**Build the server.** There is no bundled Beyond server. Follow `build/README.md` first, then `build/build-pms-mcp.md` (or `build-pricing-ops-mcp.md`) Steps B1 to B3 only (research, reference doc, write the server code into `$BUNDLE/mcp-servers/beyond/`). Credentials, registering, fan-out and the restart are done from THIS file, not from the build doc. That doc's Beyond text is mostly right (Partners API, Personal Access Token, developers.beyondpricing.com) but four things in it are overridden here: (1) its env name is `BEYOND_API_TOKEN`; ours is `BEYOND_TOKEN`, everywhere. (2) Its click path says Settings > Tokens; the page is called Personal Access Tokens. (3) Skip its 'Create and open the file' handoff and its three SANITY CHECKs for Beyond: the token is already in the root `.env` as `BEYOND_TOKEN`, `fan-out-env.sh` copies it into the server, and the SAFE / FILLED / WORKS lines above are the checks. No second paste needed here. (4) Its WORKS curl has no `-g`, so the `page[size]` brackets make curl fail with error 3; the checker's `probe_beyond` already passes `-g`. Non-negotiables for the build:
- Base URL `https://developers.beyondpricing.com/api/v1/` **with a trailing slash on every path** (`/api/v1/listings/`, not `/api/v1/listings`). Without the slash Beyond answers 301, not data (verified live 2026-09-21).
- Headers: `Authorization: Bearer <token>` and `Accept: application/vnd.api+json`. It is JSON:API: responses come as `{"data": [...]}` and field names are dasherized (`base-price`, not `base_price`).
- Env name is `BEYOND_TOKEN`, declared in the server's `.env.example`. Not `BEYOND_API_TOKEN` (the build doc's name). `fan-out-env.sh` only fills keys the `.env.example` declares, so the wrong name means a server with no token and a 401 on every call while the root `.env` looks fine.
- Read tools first (listings, calendar, recommendations, compsets, customizations). Every write needs `confirm=true` per call. Nothing pushes a price without you saying so.
- Docs to build from: `https://developers.beyondpricing.com/full-documentation.md` and the OpenAPI schema at `https://developers.beyondpricing.com/api/v1/schema/`. Skip `dynamic-api-docs.beyondpricing.com` (that API runs the other direction, PMS vendors feeding Beyond) and the old `api.beyondpricing.com/api` Token API (deprecated, answers 404).
- Model it on `mcp-servers/pricelabs/`, the bundled TypeScript pricing example.
- Ship a `.env.example` in the server folder, so `bash "$BUNDLE/fan-out-env.sh"` can copy your token from the root `.env` into the server's own `.env`. The register block below runs it.

**Register (Mac):**
```bash
cd "$BUNDLE/mcp-servers/beyond" && npm install --silent && npm run build --silent
bash "$BUNDLE/fan-out-env.sh"
uv run --python 3.13 python "$BUNDLE/lib/mcp_register.py" beyond --stdio node "$BUNDLE/mcp-servers/beyond/dist/index.js" && echo "beyond registered ✅" || echo "register failed ❌"
echo beyond >> "$BUNDLE/.cache/needs-restart"
```

**Register (Windows, Git Bash):** run all of this in Git Bash (that is what Claude's Bash tool is on Windows). Claude Code itself is a native Windows program, so the path handed to the register helper has to be the `C:\...` form. Convert it with `cygpath -w` and register that instead:
```bash
cd "$BUNDLE/mcp-servers/beyond" && npm install --silent && npm run build --silent
bash "$BUNDLE/fan-out-env.sh"
uv run --python 3.13 python "$BUNDLE/lib/mcp_register.py" beyond --stdio node "$(cygpath -w "$BUNDLE/mcp-servers/beyond/dist/index.js")" && echo "beyond registered ✅" || echo "register failed ❌"
echo beyond >> "$BUNDLE/.cache/needs-restart"
```
If Claude built the Python flavour instead of Node, the interpreter on Windows is `.venv/Scripts/python.exe` (never `.venv/bin/python`), and both the interpreter path and the `server.py` path go through `cygpath -w` the same way.

## 4. Path B: official MCP
Beyond's MCP is called Neyoba. Read-only. You ask it questions about your Beyond account; it does not change prices. Beta, no extra cost for Beyond customers during the beta (support article, 2026-09-11).

**Claude does not register this one. You add it in the app, it takes about a minute.**
1. In the Claude Code desktop app, click the **+** next to the message box, then **Connectors**, then **Manage connectors**. The Connectors settings page opens.
2. Click **+ Add** (top right), then **Add custom connector**.
3. Type a name (Neyoba is fine) and paste `https://neyoba.beyondpricing.com/mcp` into **MCP server URL**. Click **Continue**.
4. A browser opens on `v2.beyondpricing.com/oauth/authorize`. Sign in with your Beyond login and approve the `neyoba:ask` scope.
5. Done, it is on automatically. Come back and tell Claude "connected".

Claude runs the live check right after: "Ask Beyond what listings I have." An answer means it is working. If the tool is not available in the session, say: "I don't see Beyond (Neyoba) in my tools yet. Check it shows connected under + > Connectors, or that Connect finished in the browser."

**If Beyond's consent page rejects the client** (an error instead of an approve button): that is a Beyond-side rollout gap, not something to retry differently on your end. The summit skills run on the built `beyond` server above either way. Neyoba is a bonus.

## 5. Verify
The checker runs two rows when your pricing tool is Beyond.

**Beyond API** (`probe_beyond`): `GET https://developers.beyondpricing.com/api/v1/listings/?page[size]=1` with your token and `Accept: application/vnd.api+json`.
- `200`: ✅ works.
- `401` with `"code":"authentication_failed"` ("Invalid personal access token."): rc 1. Wrong token, or Beyond revoked it because Pro ended.
- `401` with `"code":"not_authenticated"` ("Authentication credentials were not provided."): the header never went out. In practice the checker catches a blank line before calling and reports rc 2.
- No answer: rc 3. Network, or Beyond is down. Retry later.
(Codes verified live 2026-09-21.)

**Beyond MCP (official, beta)** (`beyond-official`): this one never shows up in `~/.claude.json`, the app delivers it straight to the chat session, so the checker cannot see it. The row always prints `🔎 Beyond MCP (official, beta)   add it under + > Connectors; Claude checks it live`. Not added yet: run section 4. Added: the live check is the question in chat, "Ask Beyond what listings I have." An answer means it is working.

Test the built server the same way after the restart: "List my Beyond listings." That is a read; nothing changes.

## 6. Troubleshooting
- **Cannot find "Personal Access Tokens" in Settings, or Generate refuses:** most likely not on Beyond Pro, or you are a team member on someone else's account (the owner generates it). Request Pro in the app, or ask support@beyondpricing.com. Until then PriceLabs is the pricing tool that works today.
- **401 `authentication_failed` right after pasting:** the token must start with `bpat_` and be the whole thing. Re-open `.env`, check the line, no quotes, no spaces. If Pro lapsed, every token is dead; renew Pro, then generate a new one.
- **403 with `plan_not_included`:** your plan does not include API access. Same fix: Pro.
- **301 instead of data:** a path without its trailing slash. The built server must call `/api/v1/listings/`, slash included.
- **A listing you know exists is missing:** listings with no channel connection do not show up in the API. Connect the listing to its channel or PMS inside Beyond first.
- **Fields look odd (`base-price`, `min-stay`):** that is JSON:API, dasherized. The server maps them; leave them as-is rather than "fixing" them.
- **429:** honor `Retry-After` and the `X-RateLimit-*` headers; compset detail is capped around 30 requests a minute. The built server backs off and retries three times.
- **Neyoba's consent page errors out:** Beyond-side rollout gap. The built `beyond` server in section 3 is what the summit skills actually need; move on, Neyoba is a bonus.
- **Neyoba says it cannot change something:** correct, it is read-only. Price changes go through the built `beyond` server, and only with `confirm=true`.
- **Windows: `beyond` shows Failed to connect after restart:** it was registered with a `/c/Users/...` path. Re-run the Windows register block in section 3; it overwrites the old entry with the `cygpath -w` form.
- **Building from the wrong docs:** `dynamic-api-docs.beyondpricing.com` is the Dynamic Integration API for PMS vendors (Beyond calls them, not the other way). The old `api.beyondpricing.com/api` Token API is deprecated and 404s. Use `developers.beyondpricing.com` only.

## 7. Sources
- developers.beyondpricing.com: getting-started/authentication, getting-started/personal-users, mcp, full-documentation.md, api/v1/schema/ (read 2026-09-21)
- developers.beyondpricing.com/.well-known/oauth-authorization-server: registration endpoint, PKCE `S256`, token auth method `none`, scope `neyoba:ask` (fetched 2026-09-21)
- support.beyondpricing.com: Personal Access Tokens article (dated 2026-07-31); Neyoba MCP article (dated 2026-09-11)
- Live probes 2026-09-21: `/api/v1/listings/?page[size]=1` answers 401 `authentication_failed` on a bad token and 401 `not_authenticated` on none; the same path without the trailing slash answers 301; `neyoba.beyondpricing.com/mcp` answers 401 when not signed in.
