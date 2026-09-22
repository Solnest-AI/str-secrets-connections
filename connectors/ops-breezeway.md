---
server: breezeway
slot: ops
required: optional
env: [BREEZEWAY_CLIENT_ID, BREEZEWAY_CLIENT_SECRET]
official_mcp: none
---

# Breezeway: cleaning, inspection and maintenance tasks for your properties

## 1. What it is
Breezeway is the ops board a lot of STR operators run their turnovers on: cleans, inspections, maintenance tickets, task costs, all tied to a property and a reservation. In the summit kit it fills the optional ops slot (same slot as Turno). The Revenue Manager and the other summit skills use it to read your properties, reservations and tasks, and to draft new tasks that you confirm before anything gets created. Breezeway has no MCP of its own, so Claude builds a small one on your machine from Breezeway's public API and registers it as `breezeway`.

## 2. Required, cost, gate
Optional. Turno, Breezeway, or neither. Skip it and the summit skills still run; they just cannot see your cleaning and maintenance board.

No cost from us. Breezeway's Client API Request Form says: "For some use cases, we charge a $200 monthly fee." For an owner reading their own account it has not been charged (Ryan, 2026-09-21). If Breezeway quotes the fee, reply that you only need read access to your own properties and tasks, and hold off agreeing to anything until they confirm there is no charge. No plan gate that Breezeway publishes.

The real gate: Breezeway staff issue the credentials. There is no page in the Breezeway app where you can make them yourself. Breezeway's own words: "Using the API as a Breezeway Account Holder. To obtain API keys for your Breezeway account, please complete THIS FORM." Two ways to ask, and you do both today:

1. **Email support@breezeway.io** asking for Client API credentials for your own account. This is the path that has worked for Ryan. Template: `emails/breezeway-request.md`. (That address is the one Breezeway lists on breezeway.io/terms.)
2. **Fill the vendor's Client API Request Form** (same day, not later): https://share.hsforms.com/1u3FL41u0TBqTZYMmW_VmqA1l00c. It is written for software vendors, so answer it like this: Job title = Owner (or whatever you are). Company name = your STR business. Use case = "Account holder. I want to read my own properties, reservations and tasks from my own Breezeway account into an AI assistant on my own computer (Claude Code). Single account, low volume, not a product for other companies." Reviewed the docs and confirmed compatible = Yes. Development team = No. Developer First Name = your own name. Technical email = the email you log into Breezeway with. Nothing in the form is a secret.

No published turnaround. Once the email is sent, Claude marks the row as waiting so the scoreboard stops nagging:
```bash
echo "breezeway|$(date +%F)" >> "$BUNDLE/.cache/pending-vendor"
```
When the credentials land, tell Claude "Breezeway is enabled". Claude clears the marker and picks up at section 3:
```bash
sed -i.bak '/^breezeway|/d' "$BUNDLE/.cache/pending-vendor" && rm -f "$BUNDLE/.cache/pending-vendor.bak"
```

No MCP from Breezeway. Checked breezeway.io and developer.breezeway.io in full on 2026-09-21.

## 3. Path A: API key
Nothing to click. Breezeway emails you two values: a **client_id** and a **client_secret**. Keep that email; there is no in-app page to view them again. Breezeway's docs: "The provided client id and client secret will be used to retrieve an access token."

Claude opens `$BUNDLE/.env` for you (`open -e "$BUNDLE/.env"` on Mac; `notepad "$(cygpath -w "$BUNDLE")\.env"` on Windows). Put each value after its `=`, no quotes, no spaces, then save:
```
BREEZEWAY_CLIENT_ID=
BREEZEWAY_CLIENT_SECRET=
```
Both values go into the file. Nothing goes in the chat. If either one ever ends up in a chat, a screenshot or a Skool post, email support@breezeway.io and ask them to replace the pair.

**SAFE:** `if [ -d "$BUNDLE/.git" ]; then git -C "$BUNDLE" check-ignore -q .env && echo "protected ✅" || echo "add .env to $BUNDLE/.gitignore first"; else echo "protected ✅ (not a git folder, nothing can commit it)"; fi`
**FILLED:** `grep -q '^BREEZEWAY_CLIENT_ID=.\+' "$BUNDLE/.env" && grep -q '^BREEZEWAY_CLIENT_SECRET=.\+' "$BUNDLE/.env" && echo "present ✅" || echo "still blank"`
**WORKS:** `cd "$BUNDLE" && bash -c '. lib/env.sh; . lib/probes.sh; env_load .env; probe_breezeway; echo rc=$?'` (0 works, 1 rejected, 2 blank, 3 unreachable). One run per minute: Breezeway's token endpoint allows 1 request a minute, and a second run inside that window comes back rc=3.

Windows: those three run in Git Bash (Claude's Bash tool) as-is. `$BUNDLE/.env` needs no `cygpath -w` because nothing here leaves Bash.

**Build the server.** Follow `build/README.md` first, then `build/build-pms-mcp.md` (or `build-pricing-ops-mcp.md`, Track B, tool 5, Breezeway) Steps B1 to B3 only (research, reference doc, write the server code into `$BUNDLE/mcp-servers/breezeway/`). Credentials, registering, fan-out and the restart are done from THIS file, not from the build doc. Ignore the build doc's "1-2 business days"; Breezeway publishes no turnaround. The facts the build needs, all from developer.breezeway.io (read 2026-09-21):
- Auth: `POST https://api.breezeway.io/public/auth/v1/` with JSON `{"client_id": ..., "client_secret": ...}`, values read from the server's own `.env`, never typed by Claude. Response: `access_token` (24-hour life) and `refresh_token` (30 days).
- Refresh: `POST https://api.breezeway.io/public/auth/v1/refresh` with the refresh token in the `Authorization: JWT` header. Every refresh hands back a new refresh token, so store the newest one. Build the auto-refresh in.
- Every other call: header literally `Authorization: JWT <access_token>`. "JWT", not "Bearer".
- Data lives under `https://api.breezeway.io/public/inventory/v1` for property, reservation AND task: list tasks is `GET /public/inventory/v1/task/` and create task is `POST /public/inventory/v1/task` (vendor OpenAPI, read 2026-09-21). The build doc's `/public/task/v1/task` is stale, so skip it in favor of the path above. Confirm every other path against developer.breezeway.io/reference before wiring it.
- Reads first. Every create, update, close or delete needs `confirm=true` per call, same as the bundled Turno server.
- Token endpoints are rate-limited to 1 req/min and answer 429 when hit: cache the token for its 24 hours and back off on 429.
- Ship `.env.example` with the two variables, a `.gitignore` covering `.env`, and name the console script `breezeway-mcp` so the register line below is exact.

Then fill the server's own `.env` from the root one (declared keys only, values never printed):
```bash
cd "$BUNDLE" && bash fan-out-env.sh
```

**Register:** pick the line that matches what Claude built (same shape as Track B step B5, but run these lines, not the build doc's). Python with uv, modeled on the bundled Turno server, is the default:
```bash
claude mcp add --transport stdio breezeway --scope user -- uv --directory "$BUNDLE/mcp-servers/breezeway" run breezeway-mcp >/dev/null 2>&1 && echo "breezeway registered ✅" || echo "breezeway register failed ❌ (already registered? run: claude mcp remove breezeway --scope user, then this line again; still failing: run it once more without the >/dev/null part to see why)"
echo breezeway >> "$BUNDLE/.cache/needs-restart"
```
If Claude built it in TypeScript (PriceLabs-style) or plain Python with a venv, swap the first line for the matching one. Same name, same scope:
```bash
claude mcp add --transport stdio breezeway --scope user -- node "$BUNDLE/mcp-servers/breezeway/dist/index.js" >/dev/null 2>&1 && echo "breezeway registered ✅" || echo "breezeway register failed ❌ (already registered? run: claude mcp remove breezeway --scope user, then this line again; still failing: run it once more without the >/dev/null part to see why)"
claude mcp add --transport stdio breezeway --scope user -- "$BUNDLE/mcp-servers/breezeway/.venv/bin/python" "$BUNDLE/mcp-servers/breezeway/server.py" >/dev/null 2>&1 && echo "breezeway registered ✅" || echo "breezeway register failed ❌ (already registered? run: claude mcp remove breezeway --scope user, then this line again; still failing: run it once more without the >/dev/null part to see why)"
```
**Windows note (Git Bash).** Claude Code on Windows is a native Windows process, so every absolute path handed to `claude mcp add` must be the `C:\...` form. Convert first, then register with the converted path:
```bash
BUNDLE_WIN="$(cygpath -w "$BUNDLE")"
claude mcp add --transport stdio breezeway --scope user -- uv --directory "$BUNDLE_WIN\mcp-servers\breezeway" run breezeway-mcp >/dev/null 2>&1 && echo "breezeway registered ✅" || echo "breezeway register failed ❌ (already registered? run: claude mcp remove breezeway --scope user, then this line again; still failing: run it once more without the >/dev/null part to see why)"
echo breezeway >> "$BUNDLE/.cache/needs-restart"
```
TypeScript build instead: `claude mcp add --transport stdio breezeway --scope user -- node "$BUNDLE_WIN\mcp-servers\breezeway\dist\index.js" >/dev/null 2>&1 && echo "breezeway registered ✅" || echo "breezeway register failed ❌ (already registered? run: claude mcp remove breezeway --scope user, then this line again; still failing: run it once more without the >/dev/null part to see why)"`. Plain Python with a venv: the interpreter is `"$BUNDLE_WIN\mcp-servers\breezeway\.venv\Scripts\python.exe"` (never `.venv/bin/python`) followed by `"$BUNDLE_WIN\mcp-servers\breezeway\server.py" >/dev/null 2>&1 && echo "breezeway registered ✅" || echo "breezeway register failed ❌ (already registered? run: claude mcp remove breezeway --scope user, then this line again; still failing: run it once more without the >/dev/null part to see why)"`. The `$BUNDLE/.cache/needs-restart` write stays inside Bash and works as-is.

**Restart Claude Code** fully (quit, not reload). Then say "Check my connections" again.

## 4. Path B: official MCP
_None for this connector._ Breezeway publishes no MCP server (breezeway.io and developer.breezeway.io read in full, 2026-09-21). The built `breezeway` server in section 3 is the only route.

## 5. Verify
The checker runs `probe_breezeway`: one `POST https://api.breezeway.io/public/auth/v1/` with both values from `.env`, then it reads the body. Breezeway's real behaviour, confirmed live 2026-09-21:

- HTTP 200 with an `access_token` in the body: works, rc 0.
- **HTTP 200 with `{"error":"inactive client"}`: wrong or not-yet-active credentials, rc 1.** Breezeway says 200 either way, so the probe reads the body, not the status code. A bare 200 from a hand-rolled curl isn't proof by itself, check the body too.
- Blank line in `.env`: rc 2.
- 429, timeout, or anything else: rc 3. Usually the 1 req/min limit on the token endpoint. Wait a minute, run it again.

Scoreboard row **Breezeway API** (only shown when `STACK_OPS=breezeway`):
- ✅ connected: probe rc 0 and Claude Code reports `breezeway` as `✔ Connected`.
- ⏳ waiting on vendor: the pending marker from section 2 is set, with the date you emailed.
- ❌ missing: the two lines are blank, or the pair works but the server is not registered yet.
- ⚠️ registered, key fails: rc 1 (re-check the two lines) or rc 3 (vendor unreachable, try again in a minute).
- 🔒 needs a full restart: registered this session. Quit Claude Code, reopen it.

Real-call test after the restart: ask Claude "Breezeway, list my properties". That is a read, it costs nothing, and it proves the token exchange plus the `JWT` header end to end.

## 6. Troubleshooting
- **`{"error":"inactive client"}` on a 200:** the pair is wrong, or Breezeway has not activated it yet. Re-open `.env` and check both lines for stray spaces or quotes. Still failing: reply to Breezeway's email and ask them to confirm the client is active.
- **rc 3 right after an rc 0 or rc 1:** the 1 req/min token limit. The scoreboard, the WORKS check and the server's first start each spend one request. Space them out by a minute.
- **429 from the server after the restart:** same limit. The built server must cache its access token for the full 24 hours and back off on 429. If it re-authenticates on every call, that is a build bug: re-run Track B step B3 on the auth code.
- **401 on data calls with a fresh token:** the header scheme. It is `Authorization: JWT <token>`, not `Bearer`.
- **List tasks returns an error or nothing:** Breezeway's list-tasks endpoint wants exactly one of `home_id` or `reference_property_id`. List properties first, take the property's `id`, then ask for tasks for that property.
- **Token stopped working the next day:** access tokens live 24 hours. The server refreshes with the 30-day refresh token, and every refresh returns a new refresh token, so the server has to store the newest one. If the refresh token itself lapsed (30 days idle), a fresh client_id + client_secret exchange starts over.
- **No reply after a few days:** you already sent both the email and the form on day one (section 2). Reply to your own email thread with the date you submitted the form and ask Breezeway to confirm they have the request. Both routes end with the same emailed pair.
- **Windows: `breezeway` shows Failed to connect after restart:** it was registered with a `/c/Users/...` path. Run `claude mcp remove breezeway --scope user`, then re-register with the Windows block in section 3.
- **Scoreboard still shows ⏳ after the credentials are in:** the pending marker is still set. Run the clear line in section 2, then "Check my connections".

## 7. Sources
developer.breezeway.io/docs/authentication (auth endpoint, `JWT` prefix, 24-hour access token, 30-day refresh token, 1 req/min token limit; page updated 2025-06-11, read 2026-09-21). developer.breezeway.io/docs/obtaining-credentials (Account Holder form; read 2026-09-21). developer.breezeway.io/reference/list-tasks (`home_id` or `reference_property_id`; read 2026-09-21). breezeway.io/terms (support@breezeway.io; read 2026-09-21). Live probe 2026-09-21: bad credentials return HTTP 200 `{"error":"inactive client"}`. Email path and no-fee experience: Ryan, 2026-09-21. Server name, env names and register shape: kit brief task 9 step 6 and `build/build-pricing-ops-mcp.md` step B5.
