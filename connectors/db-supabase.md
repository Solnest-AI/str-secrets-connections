---
server: supabase-revenue-manager
slot: db
required: yes
env: [SUPABASE_ACCESS_TOKEN, SUPABASE_PROJECT_REF, SUPABASE_DB_PASSWORD]
official_mcp: https://mcp.supabase.com/mcp (reference only; this kit registers the npm stdio server instead)
---

# Supabase: the database every summit skill writes to

## 1. What it is
Supabase is a hosted Postgres database. The summit skills keep their tables in it. One shared project, named `str-secrets-summit`, holds all of it. Claude reaches it through Supabase's MCP server (`supabase-revenue-manager`), which runs on Node through `npx`. It is not read-only. The skills create their own tables and apply migrations through it, and the Revenue Manager's runner reads this exact server entry out of `~/.claude.json` to find your project.

Three values end up in `.env`. You supply one (the access token). Claude fills the other two (the project ref and the database password) when it creates the project, so there's no need to type those two by hand. If the kit joins a project that already exists (an existing Revenue Manager registration, or a project you chose to reuse, both in section 3), only the ref is filled and the password line stays blank; the skills do not need it.

## 2. Required, cost, gate
Required. Free. Supabase's free tier allows 2 active projects (their pricing page: "Limit of 2 active projects"). Also: "Free projects are paused after 1 week of inactivity." and "Branching (experimental) Requires a paid plan." We need one project, no branching, so the free tier covers the summit. No card, no email to anyone.

The one gate is the token. Supabase now defaults new tokens to **7 days** and **No access**, and both defaults break this kit. A 7-day token made on September 22 dies September 29, which is summit morning. A no-access token is rejected outright; a project-scoped or read-only token passes the token check and then fails the moment a skill tries to create the project or apply a migration. Section 3 walks around both traps. Follow it exactly.

## 3. Path A: API key
Supabase calls it a personal access token. It starts with `sbp_` and is shown once.

1. Go to https://supabase.com/dashboard/account/tokens (sign in, or sign up free first) and click **Generate new token**.
2. The dialog that opens is a two-step scoped wizard ("Step 1 of 2 · Configure"). Skip filling it in. Under Resource access there is a line: "Need a token with full access to your account? Create legacy token". Click **Create legacy token**. Supabase's warning on that screen is real: "Access tokens can be used to control your whole account. Be careful when sharing your tokens." Their API reference says the same: "PATs carry the same privileges as your user account, so be sure to keep it secret." That is why it only ever goes into `.env`.
3. **Name:** `STR Secrets`. **Expires in:** open the dropdown (24 hours / 7 days / 30 days / 90 days / Custom) and pick **Custom**, then the furthest date the picker allows. It caps at exactly one year; on 2026-09-21 the picker offered 21 Sep 2027. The one thing to avoid is leaving it on 7 days. Non-expiring tokens can no longer be created, for either kind of token. Legacy and scoped differ in permissions, not expiry.
4. Click **Generate token**. Copy the token now (it starts with `sbp_`); it is shown once. Claude opens `.env` for you. Put the token after the equals sign on this line, save, close:
```
SUPABASE_ACCESS_TOKEN=
```
The file is the only place it goes. The chat window is never the place for it.

**If the "Create legacy token" link is gone** (Supabase says legacy tokens are being phased out): stay in the scoped wizard. Under Resource access choose **Organization** and pick your organization. Under Permissions open the Preset dropdown and choose **Full access** ("Grants the highest access each resource offers, including write access to your database, API keys, and organization members"). Expires in **Custom**, furthest date allowed (one year). Click **Review access**, then generate. A Project-scoped or Read-only token passes the token check (it can list projects) and then fails at the project step or the first migration with 403 `Forbidden action`. The checker cannot tell the two apart, so if you see ✅ on the token and then a 403 later, the token scope is the cause.

**When it expires:** make a new one the same way, paste it into `.env`, then re-run the Register block below and quit and reopen the Claude Code desktop app. The server keeps its own copy of the token in `~/.claude.json`; pasting into `.env` alone does not reach it. Then say "Check my connections".

**SAFE:** `if [ -d "$BUNDLE/.git" ]; then git -C "$BUNDLE" check-ignore -q .env && echo "protected ✅" || echo "add .env to $BUNDLE/.gitignore first"; else echo "protected ✅ (not a git folder, nothing can commit it)"; fi`
**FILLED:** `grep -q '^SUPABASE_ACCESS_TOKEN=.\+' .env && echo "present ✅" || echo "still blank"`
**WORKS:** `bash -c '. lib/env.sh; . lib/probes.sh; env_load .env; probe_supabase; echo rc=$?'` (0 works, 1 rejected, 2 blank, 3 unreachable)

**Project step.** Once the token works, Claude creates (or finds) the shared project. Nothing for you to click. Claude asks one question, which region: US East (`us-east-1`), Canada Central (`ca-central-1`) or EU West (`eu-west-1`). Pick the one closest to you. Then Claude runs the bundled helper with the token read from the environment after sourcing, never passed as an argument. Claude puts your answer in as `SUPABASE_REGION` (one of `us-east-1`, `ca-central-1`, `eu-west-1`) on the front of this line; if it is left off, the helper defaults to `us-east-1`.
```bash
set -a; . "$BUNDLE/.env"; set +a
SUPABASE_REGION=ca-central-1 BUNDLE_ENV="$BUNDLE/.env" uv run --python 3.13 python "$BUNDLE/lib/supabase_project.py"
```
What it does, in order: lists your projects; if `str-secrets-summit` already exists it prints `REF=<ref>` and stops; if you already have two active projects it prints `CAP: free tier allows 2 active projects; existing: ...` and stops (what to do then is at the end of this paragraph); otherwise it creates `str-secrets-summit` on the free tier in your region, generates a strong database password, appends `SUPABASE_DB_PASSWORD=` to `.env`, waits for the project to come up (it polls for up to ten minutes), and prints `REF=<ref>`. Claude reads the `REF=` line and writes it with `. "$BUNDLE/lib/env.sh"; env_set_if_blank "$BUNDLE/.env" SUPABASE_PROJECT_REF <ref>`. A project ref is not a secret; the password is, and it never appears in the chat. The helper matches on the project name and reads the `ref` Supabase returns; a ref is 20 lowercase letters. If it prints `CAP`, the safest move is section 6's fix: pause a project you no longer need in the Supabase dashboard (a paused project does not count), then run this step again so the kit gets its own `str-secrets-summit`. If you would rather reuse an existing project, Claude runs `set -a; . "$BUNDLE/.env"; set +a; curl -sS -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" https://api.supabase.com/v1/projects | uv run --no-project --python 3.13 python -c 'import json,sys; [print(p["name"], p["ref"], p["status"]) for p in json.load(sys.stdin)]'` (names, refs and statuses only, no secrets), you pick one, and Claude writes it with `. "$BUNDLE/lib/env.sh"; env_set_if_blank "$BUNDLE/.env" SUPABASE_PROJECT_REF <ref>`. `SUPABASE_DB_PASSWORD` stays blank on the reuse path; the summit skills reach the database through the MCP server and do not need it.

**Windows note (Git Bash):** the helper runs inside Git Bash, so `$BUNDLE/lib/supabase_project.py` works as written; nothing here is handed to Claude Code as a path, so no `cygpath -w` on this line. `uv run` picks its own interpreter, so there is no `.venv/bin/python` versus `.venv/Scripts/python.exe` question either. Never type `python` on Windows (see `system-python-uv.md`).

**Already have `supabase-revenue-manager` from the Revenue Manager kit?** The checker never shows a server's full entry, so Claude pulls just the ref out of `~/.claude.json` with a one-line Python read that prints only the ref (or nothing), never the token:
```bash
uv run --python 3.13 python -c 'import json,os; d=json.load(open(os.path.expanduser("~/.claude.json"))); s=d.get("mcpServers",{}).get("supabase-revenue-manager",{}); print(next((a.split("=",1)[1] for a in s.get("args",[]) if a.startswith("--project-ref=")), ""))'
```
If a ref comes back and `SUPABASE_PROJECT_REF` in `.env` is blank, Claude writes that ref with `. "$BUNDLE/lib/env.sh"; env_set_if_blank "$BUNDLE/.env" SUPABASE_PROJECT_REF <ref>` and skips the project step: your Revenue Manager tables already live in that project and the summit skills join it. Only run the project step when no ref is registered yet.

**Register** the server. This is the canonical register block; the troubleshooting fallbacks in section 6 refer back to it and only swap the one line that differs. Source `.env` first so the shell can read the project ref, then hand the helper the token's variable NAME (never its value):
```bash
set -a; . "$BUNDLE/.env"; set +a
[ -n "${SUPABASE_PROJECT_REF:-}" ] && [ -n "${SUPABASE_ACCESS_TOKEN:-}" ] || { echo "fill SUPABASE_ACCESS_TOKEN and let Claude set SUPABASE_PROJECT_REF first"; }
uv run --python 3.13 python "$BUNDLE/lib/mcp_register.py" supabase-revenue-manager --stdio npx -y @supabase/mcp-server-supabase@latest --project-ref="$SUPABASE_PROJECT_REF" --env SUPABASE_ACCESS_TOKEN && echo "supabase-revenue-manager registered ✅" || echo "supabase-revenue-manager failed ❌"
echo supabase-revenue-manager >> "$BUNDLE/.cache/needs-restart"
```
No `--read-only` flag. The skills apply migrations through this server, so it needs write access. The token is stored as the server's environment in `~/.claude.json`, which is why the kit never shows you the raw contents of that file and never asks you to print it.

**Windows note (Git Bash):** the only paths in this block (`$BUNDLE/.env` and the needs-restart file) are read by Git Bash itself, not handed to Claude Code, so no `cygpath -w` here. `npx` resolves the package on its own. If `npx` complains that `npm.ps1 cannot be loaded`, the fix is in `system-node.md`.

**Honesty note.** Supabase's current docs describe only their hosted server with a browser sign-in ("You don't need a personal access token (PAT)") and no longer document this npm form. The package is still published (`@supabase/mcp-server-supabase` 0.13.0, checked on npm 2026-09-21) and still takes `SUPABASE_ACCESS_TOKEN` plus `--project-ref`; its own CLI says "Please provide a personal access token (PAT) with the --access-token flag or set the SUPABASE_ACCESS_TOKEN environment variable". We use it because the Revenue Manager runner reads exactly this shape out of `~/.claude.json`.

## 4. Path B: official MCP
Supabase's documented Claude Code path is their own hosted server with a browser login, registered project-scoped at `https://mcp.supabase.com/mcp?features=docs%2Caccount%2Cdatabase%2Cdebugging%2Cdevelopment%2Cfunctions%2Cbranching`. For reference only; this kit does not register it. In Supabase's own words, once it is added: "Select the 'supabase' server, then 'Authenticate'". A browser window opens where you log in to Supabase and grant access to your organization. Their URL also takes `read_only=true`, `project_ref=<id>` "(disables account tools)", and `features=`.

This kit does not register it, and you do not need to run it. It cannot satisfy the Revenue Manager runner's config contract (server name `supabase-revenue-manager`, `--project-ref=` in the args, `SUPABASE_ACCESS_TOKEN` in the env), so the runner would not find your project. If you add it anyway for your own use, it does no harm; it just sits next to ours as a second server named `supabase`.

## 5. Verify
The checker runs `probe_supabase`, one real call: `GET https://api.supabase.com/v1/projects` with your token as `Authorization: Bearer`. Free, no side effects. Outcomes:

- **200** with a JSON list (an empty list `[]` is fine, it means a fresh account): the token works. Row shows ✅.
- **401 `{"message":"Unauthorized"}`**: the token is wrong, expired, or was deleted from the dashboard. Verified 2026-09-21 with a made-up token: this is the exact body. Make a new token per section 3.
- **Blank**: the `.env` line is empty. Paste the token into `.env`.
- **Unreachable**: no network, or api.supabase.com is down. Try again in a minute.
- **403 `{"message":"Forbidden action"}`**: a scoped token that cannot even list projects (No access preset). Shows as rejected. Make a legacy token, or Organization plus Full access.

After the token passes, the row also needs `SUPABASE_PROJECT_REF` filled (the project step does that, or the Revenue Manager check just above the Register block) and the server registered. After you quit and reopen the Claude Code desktop app, Claude asks the server for `list_tables`. An empty result is a pass; the skills create their tables on first run. A tool error mentioning permissions or `403` means the token is scoped too tightly: it passed the token check but cannot write. Make a legacy token, or Organization plus Full access, paste it into `.env`, re-run the Register block, restart.

## 6. Troubleshooting
- **`CONNECTION_CLOSED` the first time the server connects:** an npm peer dependency problem in the published package. It declares `zod` and `@modelcontextprotocol/server` as peer dependencies (checked on npm 2026-09-21), and Claude Code issue #95435 tracks the failure. Install the three locally, then re-run the Register block in section 3, but point the helper straight at the installed binary instead of `npx`:
  ```bash
  cd "$BUNDLE" && npm install --silent @supabase/mcp-server-supabase @modelcontextprotocol/server zod
  set -a; . "$BUNDLE/.env"; set +a
  uv run --python 3.13 python "$BUNDLE/lib/mcp_register.py" supabase-revenue-manager --stdio "$BUNDLE/node_modules/.bin/mcp-server-supabase" --project-ref="$SUPABASE_PROJECT_REF" --env SUPABASE_ACCESS_TOKEN && echo "supabase-revenue-manager registered ✅" || echo "supabase-revenue-manager failed ❌"
  echo supabase-revenue-manager >> "$BUNDLE/.cache/needs-restart"
  ```
  **Windows note:** that binary path is handed to Claude Code, a native Windows process, so it must be the `C:\...` form, and the `.bin` shim is a Unix script. Register the package's real entry through `node` instead, converted with `cygpath -w`:
  ```bash
  uv run --python 3.13 python "$BUNDLE/lib/mcp_register.py" supabase-revenue-manager --stdio node "$(cygpath -w "$BUNDLE/node_modules/@supabase/mcp-server-supabase/dist/cli.js")" --project-ref="$SUPABASE_PROJECT_REF" --env SUPABASE_ACCESS_TOKEN
  ```
  (`dist/cli.js` is the package's declared `bin` entry, checked on npm 2026-09-21.)
- **Worked last week, 401 today:** the token expired. If you left the dropdown on 7 days, this is that. New token, Custom expiry a year out, paste it into `.env`, re-run the Register block in section 3, quit and reopen the Claude Code desktop app, then "Check my connections".
- **Token lists projects but the project step or a migration fails with 403 / "Forbidden action":** scoped token, wrong permissions. Legacy token, or Organization plus Full access preset. Read-only is not enough; Project scope is not enough.
- **`CAP: free tier allows 2 active projects`:** Supabase counts active projects only. Safest: pause or delete a project you no longer need in the Supabase dashboard, then run the project step again; a paused project does not count. Or reuse one: Claude lists your projects (names, refs and statuses, nothing secret), you pick, and Claude writes the ref, exactly as the project step in section 3 describes.
- **Project shows as paused on summit morning:** "Free projects are paused after 1 week of inactivity." Set up on the 22nd, untouched until the 29th, and Supabase pauses it. Open the project in the dashboard, restore it, then "Check my connections". Running any summit skill once mid-week keeps it awake.
- **Project creation fails with a 400 that names `organization_slug` or `region_selection`:** Supabase's Management API wants `organization_slug` and `region_selection` on the create call (spec read 2026-09-21), and that is exactly what the helper sends; the older `organization_id`, `region` and `plan` fields are marked deprecated there and the helper does not send them. A 400 naming either field means Supabase changed the create call again after that read. Create the project by hand in the Supabase dashboard, in your organization, named exactly `str-secrets-summit`, in the region closest to you, and put the database password you chose on the `SUPABASE_DB_PASSWORD=` line in `.env`. Run the project step again: the helper finds a project by name, prints `REF=`, and Claude fills the ref.
- **Server shows `Failed to connect` right after registering:** the first `npx` start downloads the package and can run past the 30 second startup timeout. Wait a moment; it usually connects on the second try. Still failing: `node -v` must print v20 or newer (`system-node.md`).
- **Windows: `Failed to connect` after restart:** first check `npx -v` prints a version in Git Bash and that the `npm.ps1` execution-policy fix from `system-node.md` has been applied. If it still fails, Claude Code (a native Windows process) could not launch `npx` directly. Re-run the Register block in section 3, but swap its `npx -y @supabase/mcp-server-supabase@latest` for `cmd //c npx -y @supabase/mcp-server-supabase@latest`. Quit and reopen the Claude Code desktop app again. The Revenue Manager runner still finds `--project-ref=` in the args, so this shape keeps its contract.
  The double slash is deliberate: Git Bash turns a lone `/c` into `C:/` before Claude Code sees it; `//c` reaches Claude Code as `/c`.
- **You see two Supabase servers in `/mcp`:** one is ours (`supabase-revenue-manager`), the other is Supabase's hosted one (`supabase`) if you added it yourself. Harmless. The skills only use ours.

## 7. Sources
supabase.com/docs/guides/ai-tools/mcp; supabase.com/pricing; supabase.com/dashboard/account/tokens (token dialog read on a live dashboard 2026-09-21 21:45; the legacy-token expiry picker capped at 21 Sep 2027); supabase.com/docs/reference/api/introduction (modified 2026-09-22); api.supabase.com/api/v1-json (Management API OpenAPI, read 2026-09-21: bearer auth, 401 Unauthorized, 403 Forbidden action, 429 rate limit; create-project body requires `db_pass`, `name`, `organization_slug`, with `organization_id`, `region` and `plan` deprecated and `region_selection` in their place; a project ref is 20 lowercase letters); npmjs.com/package/@supabase/mcp-server-supabase 0.13.0 (bin `dist/cli.js`, peers `zod` and `@modelcontextprotocol/server`, read 2026-09-21); GitHub anthropics/claude-code #95435.
