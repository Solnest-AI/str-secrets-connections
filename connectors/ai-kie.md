---
server: kie
slot: ai
required: yes
env: [KIE_API_KEY]
official_mcp: none
---

# Kie.ai: the image and video generator behind your ads

## 1. What it is
Kie.ai is a reseller. One account, one key, one credit balance, and behind it sit the image and video models the summit's ad skills use to make the pictures and clips for your ads. You never talk to Kie directly; the bundled `kie` server (ours, Python, runs on uv) does, and Claude calls that server. Kie does not publish an MCP server of its own, so there is no Path B here.

## 2. Required, cost, gate
Required. Prepaid credits, no subscription. Kie's words: "New users also receive 80 free credits for testing", "KIE credits do not expire", "Failed tasks are not charged." Each generation spends credits, priced per model. The free 80 are enough to prove the connection and make a few test images; budget a top-up before the ad skills run for real. No plan tier, no approval, no email to anyone. Sign in is "Sign in with Google / Sign in with Microsoft".

## 3. Path A: API key
1. Go to https://kie.ai/api-key and sign in with Google or Microsoft.
2. Click **Create New Key**. Name it `STR Secrets`.
3. The key table has columns for Name, Key, Created Date, Created by, IP Whitelist, Allowed Models and Safe-Spend Limits. Leave **IP Whitelist** empty: your house and the venue have different IPs, and a whitelisted key stops working the moment your IP changes. Leave Allowed Models unrestricted; the skills pick the model and Kie changes the lineup often. A Safe-Spend Limit is optional and only caps what the key can burn.
4. Copy the key now. Kie does not say whether it shows the full key again later, so treat it as a one-time view.

One key, one line in `.env`. Claude opens the file for you; put the key after the equals sign, no quotes, no spaces, save, close. The file is the only place it goes. Never paste it in the chat. If it ever lands there, go back to https://kie.ai/api-key, delete that key, make a new one.
```
KIE_API_KEY=
```

Then Claude runs, in this order:

**SAFE:** `if [ -d "$BUNDLE/.git" ]; then git -C "$BUNDLE" check-ignore -q .env && echo "protected ✅" || echo "add .env to $BUNDLE/.gitignore first"; else echo "protected ✅ (not a git folder, nothing can commit it)"; fi`
**FILLED:** `grep -q '^KIE_API_KEY=.\+' .env && echo "present ✅" || echo "still blank"`
**WORKS:** `bash -c '. lib/env.sh; . lib/probes.sh; env_load .env; probe_kie; echo rc=$?'` (0 works, 1 rejected, 2 blank, 3 unreachable)

**Register** the bundled server. Build its venv, then point Claude Code at it. Run exactly one of the two blocks: the first on Mac/Linux, the second on Windows.
```bash
if ( cd "$BUNDLE/mcp-servers/kie" && { [ -d .venv ] || uv venv --quiet .venv; } && uv pip install --quiet -r requirements.txt --python .venv ) && [ -x "$BUNDLE/mcp-servers/kie/.venv/bin/python" ]; then
  echo "kie venv built ✅"
  claude mcp remove kie -s user >/dev/null 2>&1 || true
  claude mcp add --transport stdio kie --scope user --env KIE_ENV_PATH="$BUNDLE/.env" -- "$BUNDLE/mcp-servers/kie/.venv/bin/python" "$BUNDLE/mcp-servers/kie/server.py" >/dev/null 2>&1 && { echo "kie registered ✅"; echo kie >> "$BUNDLE/.cache/needs-restart"; } || echo "kie register failed ❌. Run the claude mcp add line again without the >/dev/null 2>&1 part to see the error."
else
  echo "kie venv build failed ❌. Nothing registered. Is uv installed? See connectors/system-python-uv.md, then run this block again."
fi
```
`$BUNDLE` is the absolute path of this folder; Claude resolved it once in Phase 0. The only thing that goes into the `claude mcp add` line is `KIE_ENV_PATH`, the path to your `.env` file. The server reads that file the first time a tool needs the key and takes `KIE_API_KEY` out of it. The key itself never enters the Claude Code config. Change the key later and the server picks it up on the next restart, no re-register needed.

**Windows note:** the venv interpreter is `.venv/Scripts/python.exe`, not `.venv/bin/python`, and Claude Code is a native Windows process, so every absolute path gets converted with `cygpath -w` before it is registered. That includes the `.env` path handed to `KIE_ENV_PATH`, because the server is a native Windows Python and cannot open a `/c/Users/...` path.
```bash
if ( cd "$BUNDLE/mcp-servers/kie" && { [ -d .venv ] || uv venv --quiet .venv; } && uv pip install --quiet -r requirements.txt --python .venv ) && [ -f "$BUNDLE/mcp-servers/kie/.venv/Scripts/python.exe" ]; then
  echo "kie venv built ✅"
  claude mcp remove kie -s user >/dev/null 2>&1 || true
  claude mcp add --transport stdio kie --scope user --env KIE_ENV_PATH="$(cygpath -w "$BUNDLE/.env")" -- "$(cygpath -w "$BUNDLE/mcp-servers/kie/.venv/Scripts/python.exe")" "$(cygpath -w "$BUNDLE/mcp-servers/kie/server.py")" >/dev/null 2>&1 && { echo "kie registered ✅"; echo kie >> "$BUNDLE/.cache/needs-restart"; } || echo "kie register failed ❌. Run the claude mcp add line again without the >/dev/null 2>&1 part to see the error."
else
  echo "kie venv build failed ❌. Nothing registered. Is uv installed? See connectors/system-python-uv.md, then run this block again."
fi
```

## 4. Path B: official MCP
_None for this connector._

One warning while you are on their docs. Kie publishes a "Claude Code + kie.ai Integration Guide" (docs.kie.ai/2152008m0). It is not an MCP server. It has you set `ANTHROPIC_BASE_URL` to `https://api.kie.ai/claude` plus one of `ANTHROPIC_API_KEY` (as `Bearer <your Kie key>`) or `ANTHROPIC_AUTH_TOKEN` (the bare key), and says "After installing, do not log in with an Anthropic account." That swaps the Claude you are paying for with Kie's proxy, for every summit skill, not just ads. Skip it. If you already did, all three variables have to go, not just the URL: a leftover `ANTHROPIC_API_KEY` or `ANTHROPIC_AUTH_TOKEN` makes Claude Code send your Kie key to Anthropic and every request fails. That guide offers four places to put them; check each one. On Mac, open `~/.zshrc` and delete every line that starts with `export ANTHROPIC_`. On Windows, in PowerShell run `[Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", $null, "User")` and the same line again for `ANTHROPIC_API_KEY` and for `ANTHROPIC_AUTH_TOKEN`. On both, open `~/.claude/settings.json` and remove those three keys from the `"env"` block (delete the file if that block is all it holds). If you installed the CC-Switch app (the guide's Method C, Windows), switch it back to the official provider or uninstall it. Then quit every terminal window, open a new one, run `claude` and sign in with your claude.ai account. Claude Code should offer the claude.ai login and never mention an API key; if it mentions one, a variable is still set.

## 5. Verify
The checker runs `probe_kie`, which makes one real call, the same one Kie's docs use to prove a key: `GET https://api.kie.ai/api/v1/chat/credit` with your key as `Authorization: Bearer`. It reads your balance; it does not create a task, so nothing gets generated. Kie's own example of a good answer: `{"code": 200, "msg": "success", "data": 100}`.

One thing that is different about Kie: **a wrong key still comes back as HTTP 200.** The real answer is the `code` field inside the body. The probe reads the body, not the HTTP status, so:

- Body `"code":200` and `data` is your credit balance: works. Row shows ✅. If `data` is `0`, the key is fine but the tank is empty; top up before the ad skills run.
- Body `"code":401` with `"msg":"Unauthorized..."`: the key is rejected. Wrong key, deleted key, stray quote or space around it in `.env`, or an IP whitelist on the key. Row shows ⚠️.
- Blank line in `.env`: ❌ missing. Back to section 3.
- Timeout or a 5xx: unreachable. Kie is down or your wifi is. Try again in a minute.

After the restart, `/mcp` lists `kie` as connected. Connected only means the Python server started. It does not open `.env` or check the key until the first tool call, so `kie` shows connected with a blank or wrong key too. The ✅ on the Kie row comes from the probe, not from `/mcp`. Trust the probe.

## 6. Troubleshooting
- **`"code":401` on a key you made a minute ago:** copied short or with a trailing space. Open `.env`, check the line is exactly `KIE_API_KEY=` followed by the key, nothing else. If it still fails, delete the key on the dashboard and make a fresh one.
- **Worked at home, fails at the venue:** the key has an IP whitelist. Kie's dashboard lets you whitelist per key; a whitelisted key fails from any other IP. Clear the whitelist at https://kie.ai/api-key.
- **Claude says the API returned 200 but the probe says rejected:** that is Kie, not a bug. HTTP 200 with `"code":401` in the body means rejected. Trust the probe.
- **A model the skill asked for is gone, or a new one showed up:** models come and go. Kie resells them, and the lineup changes without notice. The `kie` server's own model list is a short list shipped inside this kit, frozen on the day the kit was built; it is not a live query and cannot tell you what Kie has today. The live lineup is docs.kie.ai, where each model page shows its slug. Give Claude the slug of a current model from there; the server passes any docs.kie.ai slug straight to Kie. Nothing to fix in the connection.
- **Generation fails with a credits error:** balance is at zero. Top up on the Kie dashboard. "Failed tasks are not charged", so the failed attempt did not cost you anything.
- **`kie` shows Failed after restart even though the register line succeeded (any OS):** the venv was never built, so the Python path stored in the registration does not exist. `claude mcp add` does not check that. Re-run the register block in section 3 until it prints `kie venv built ✅` first, then the register success line. If it prints `build failed`, uv is missing or the install could not download; see connectors/system-python-uv.md.
- **`kie` shows Failed after restart (Windows):** the registered path is probably `/c/Users/...` instead of `C:\Users\...`, or it points at `.venv/bin/python`, which does not exist on Windows, or `KIE_ENV_PATH` was not converted. Remove it (`claude mcp remove kie -s user`) and re-run the Windows register block in section 3.
- **`kie` shows Failed after restart (any OS) and the `.env` moved:** `KIE_ENV_PATH` is an absolute path. If you moved or renamed the kit folder, remove the server and re-run the register block so the new path is stored.
- **You followed Kie's "Claude Code" guide before the summit:** undo all three variables as described in section 4, in every place that guide offered. Removing only `ANTHROPIC_BASE_URL` leaves Claude Code sending your Kie key to Anthropic. Everything in this kit assumes the real Claude.

## 7. Sources
docs.kie.ai/common-api/quickstart, docs.kie.ai/1973359m0 (API keys and auth), docs.kie.ai/2152008m0 (the proxy guide, listed so you can recognise it and skip it), kie.ai/api-key, kie.ai FAQ (credits). All read 2026-09-21.
