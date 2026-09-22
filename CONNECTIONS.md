---
name: str-secrets-connections
description: Checks and fixes every connection the STR Secrets summit skills need (PMS, pricing, ranking, ops, AirROI, Meta Ads, Kie, Gemini, Firecrawl, Supabase) on Mac or Windows. Trigger when the user drags this folder in and says 'Set up my connections', 'Check my connections', or 'Update my connections'.
---

# STR Secrets Connections: the conductor

This is the one file you follow, top to bottom, to get every summit skill wired in. Everything else in this folder (`connectors/*.md`, `emails/*.md`, `lib/`) is a reference this file sends you to. Do not improvise a different setup path.

## Claude, read this first

You run every command yourself, through your Bash tool. One step per message, never a wall of steps at once. Casual Solnest voice: direct, warm, a little funny, never corporate. The attendee never opens a terminal of their own; if a command appears below, it is for you to run, not them.

**ADAPT, DON'T ENFORCE (Ryan-stated 2026-09-21: "it has to remain easy and dynamic for people")**

- The scoreboard is a map, not a gate. Any row can be skipped with "skip for now" and picked up later. Never refuse to keep going because a row is red. Only two things are real blockers, and you say so once, lightly: no PMS at all means the Revenue Manager can't run, and no AirROI key means the Comping Agent can't run. Everything else just degrades gracefully and the rest of the kit is unaffected.
- Let them talk in their own words. "Hospitable, PriceLabs, no ranking tool, I use Turno" in one breath means write all four `STACK_*` answers and move straight on. Never march someone through four questions they already answered in one sentence. If they're unsure, offer the choices, don't interrogate them.
- Vendor screens change weekly. When a click path doesn't match what's actually on screen, ask "what do you see on the screen right now?" and guide from there. Never insist on a button label that might be stale. A missing menu usually just means a plan gate: say what it's probably gated by, offer the email template, and move on.
- Reuse what they already have. Check first with `uv run --python 3.13 python "$BUNDLE/lib/mcp_register.py" --list`, which prints `name<TAB>type` lines only, nothing secret. If a server already does the job under a different name (an existing `firecrawl`, `supabase`, `meta-ads`, or `rankbreeze` from another Solnest kit), use it as-is. Register a second one only when a name is a hard contract, like `supabase-revenue-manager` for the Revenue Manager runner, and say why in one plain sentence.
- Order is a default, not a law. If they want Meta first because that's the tab they're already on, do Meta first. The restart batching below is a suggestion ("we can restart once at the end"), restart whenever they'd rather.
- "I already have that" means go and look, not "paste it again". When they say a key or connection already exists (another Solnest kit, an earlier setup, "it's connected in my other tool"), say "nice, let me find it" and run `python3 "$BUNDLE/lib/env_discover.py" --env "$BUNDLE/.env" --apply --only <VAR>`. Found: the scoreboard probe proves it and you move on. Not found: ask where they think it lives (a folder, another app) and search there with `--extra-dir <folder>`. Only when the machine really has nothing do you send them to the vendor's page. For a sign-in server, "already connected" means it may already sit under + > Connectors in the app: run the live check first, ask them to add it only if the tool is not there.
- Failures get one plain sentence and a next step, never a lecture and never a wall of text. A pasted key gets "no worries, rotate it in the dashboard and paste the new one into the file" and nothing more.
- Every "must", "never", "required" you read inside the connector files is a note written to you, Claude, not a script to recite word for word. Translate it into something a friend would say out loud.

### The credential contract (this one is not adaptive)

- **NEVER ask for an API key in chat.** Not "paste it here", not "what's your key". Keys go in `.env`, full stop, every time.
- Never use your Edit or Write tools to put a value into `.env` yourself. The file is built by `lib/env_make.py` from their four answers (Phase 1), keys they already have are copied in by `lib/env_discover.py`, and everything else they paste in themselves after you open the file. You read the file back afterward; you never type a secret into it.
- Three checks, every connector, in this order: **SAFE** (is `.env` gitignored so nothing can commit it), **FILLED** (is the line actually non-blank), **WORKS** (does the real vendor probe succeed). Register a server only after WORKS passes.
- Never run `claude mcp get`. It can print a secret straight to the terminal, and there's no reason to.
- Never print the raw contents of `~/.claude.json`, whatever is in it. To see what's registered, run `uv run --python 3.13 python "$BUNDLE/lib/mcp_register.py" --list`, names and types only, nothing else.
- A key pasted into chat by accident: no drama, no lecture. Tell them to rotate it in the vendor's dashboard and paste the fresh one into the file. Nothing else needed.

### Windows

Your Bash tool is Git Bash, not PowerShell, and every command below runs there on both platforms; nothing here needs a separate PowerShell window. Python venv paths are `.venv/Scripts/python.exe`, never `.venv/bin/python`. Any absolute path you hand to the register helper as a `--stdio` argument gets converted first: `BUNDLE_WIN="$(cygpath -w "$BUNDLE")"`, and the Windows form (`C:\...`) is what actually gets registered, because the Claude Code desktop app is a native Windows process and cannot open a `/c/Users/...` path. If an `npx`-based server shows "Failed to connect" after a restart, re-register it as `--stdio cmd //c npx -y <pkg>`, double slash on purpose: Git Bash turns a lone `/c` into `C:/` before Claude Code ever sees the argument.

One exception to all of the above: PriceLabs' official MCP (account admin only) still needs the real `claude` CLI for its OAuth client-credential flow, since that handshake has no file-based equivalent through the register helper. `connectors/pricing-pricelabs.md` section 4 has the binary resolver and the Simple-path fallback if no `claude` binary turns up.

## Phase 0: before anything else

1. Detect the OS. Everything below runs the same on both unless a note says otherwise.
   ```bash
   uname -s
   ```
   `Darwin` means Mac. Anything starting `MINGW` or `MSYS` means Windows Git Bash.

2. Set the bundle path once and reuse it everywhere below. If the GitHub-link install path cloned this kit into a subfolder of the session folder, step into it first:
   ```bash
   [ -f "$PWD/CONNECTIONS.md" ] || cd str-secrets-connections
   BUNDLE="$(pwd)"
   ```
   On Windows also set the form the register helper needs for `--stdio` arguments:
   ```bash
   BUNDLE_WIN="$(cygpath -w "$BUNDLE")"
   ```

3. Confirm the folder is complete.
   ```bash
   ls "$BUNDLE"/CONNECTIONS.md "$BUNDLE"/check-connections.sh "$BUNDLE"/fan-out-env.sh "$BUNDLE"/.env.template "$BUNDLE"/lib/env_make.py "$BUNDLE"/lib/env_discover.py "$BUNDLE"/connectors >/dev/null
   ```
   Anything missing means a bad unzip; have them re-download.

4. SAFE, once, for the whole folder. It checks the folder, not the file, so it runs before `.env` exists.
   ```bash
   if [ -d "$BUNDLE/.git" ]; then git -C "$BUNDLE" check-ignore -q .env && echo "protected ✅" || echo "add .env to .gitignore first"; else echo "protected ✅ (not a git folder, nothing can commit it)"; fi
   ```

5. System rows only. `check-connections.sh` needs a `.env` to print the full board, so before one exists just check the four tools directly:
   ```bash
   for t in git node uv; do command -v "$t" >/dev/null && echo "✅ $t" || echo "❌ $t"; done
   ```
   Anything ❌, open the matching file (`connectors/system-git.md`, `connectors/system-node.md`, or `connectors/system-python-uv.md`) and follow its Path A install for this OS, one tool at a time. `connectors/system-claude-code.md` covers the app itself.

6. After any install, re-check in a genuinely fresh shell, a brand new Bash tool call, not the one you were already in; PATH changes never show up mid-session.

7. Confirm they have a paid claude.ai plan; the free plan cannot run Claude Code at all (`connectors/system-claude-code.md` section 2). For the summit the ask is Max 5x: setup plus the four skills in one day runs Pro dry partway through.

## Phase 1: four questions, then a `.env` shaped to their answers

**Skip this phase entirely** when `$BUNDLE/.env` already exists with all four `STACK_*` lines filled (a re-run, or "Check my connections"). Jump to Phase 2.

Ask about whichever of the four are still unknown, one question per message, unless they volunteer more than you asked in a single answer, in which case take everything they gave you and skip the rest:

1. **PMS.** "What's your PMS? Hospitable, Hostaway, Guesty, Hostfully, OwnerRez, Lodgify, Uplisting, or Smoobu?" Value: `hospitable|hostaway|guesty|hostfully|ownerrez|lodgify|uplisting|smoobu`. "Guesty For Hosts" is not an option anymore: that product was sunset 2026-01-15 and everyone landed on Lite or Pro instead (`connectors/pms-guesty.md`); ask which one they're on, use `guesty` either way, and if it's Lite, mention gently that Open API needs Pro before you get to section 3 of that file.
2. **Pricing.** "PriceLabs or Beyond?" Value: `pricelabs|beyond`.
3. **Ranking**, optional. "Do you use a ranking tool, RankBreeze or IntelliHost? No worries if not." Value: `rankbreeze|intellihost|none`.
4. **Ops**, optional. "Turno or Breezeway for cleaning, or neither?" Value: `turno|breezeway|none`.

Then build their `.env` from the answers. It contains only the slots that apply to them (one PMS block, one pricing block, ranking and ops only if they said yes, and the required block), with the four answers already filled in. Nobody scrolls past seven other PMS vendors looking for theirs.
```bash
python3 "$BUNDLE/lib/env_make.py" --pms <pms> --pricing <pricing> --ranking <ranking|none> --ops <ops|none> --template "$BUNDLE/.env.template" --out "$BUNDLE/.env"
```
(`uv run --python 3.13 python` in place of `python3` if `python3` is missing.) Re-running it later with different answers is safe: every value already in the file is carried over, and a key for a vendor they no longer chose is kept at the bottom, never deleted.

If they also have the Revenue Manager, Listing Optimizer, or Comping Agent skills unzipped somewhere, ask where and write the folder paths in. Plain paths, not secrets; `fan-out-env.sh` uses them later to reach those skills' own `.env` files, and the search in the next step looks inside them. Skip any they don't have.
```bash
. "$BUNDLE/lib/env.sh"; env_set_if_blank "$BUNDLE/.env" SKILL_PATH_REVENUE_MANAGER <path>
. "$BUNDLE/lib/env.sh"; env_set_if_blank "$BUNDLE/.env" SKILL_PATH_LISTING_OPTIMIZER <path>
. "$BUNDLE/lib/env.sh"; env_set_if_blank "$BUNDLE/.env" SKILL_PATH_COMPING_AGENT <path>
```

**Now go find the keys they already have, before asking for a single one.** Plenty of attendees ran an earlier Solnest kit, or already registered a vendor's server. The helper reads every `.env`-style file in the usual places (Desktop, Documents, Downloads, the skill folders above, the folders of servers already registered in `~/.claude.json`, the Claude Desktop config), matches by name and by the other names the same key goes by, and copies anything it finds into the blank lines. It prints names and where each came from, never a value.
```bash
python3 "$BUNDLE/lib/env_discover.py" --env "$BUNDLE/.env" --apply
```
Tell them what it found in one line ("found your PriceLabs, AirROI and Firecrawl keys from the Revenue Manager kit, still need Hospitable and Supabase"). A found key can be stale, which is why the scoreboard in Phase 2 probes every one of them for real before it turns green.

Then open `.env` for them so they never have to go hunting. Leave it open; every later step reuses this same file.
```bash
open -e "$BUNDLE/.env"           # Mac
notepad "$BUNDLE\.env"           # Windows
xdg-open "$BUNDLE/.env"          # Linux
```

## Phase 2: the first scoreboard

```bash
bash "$BUNDLE/check-connections.sh"
```
Print the whole output, never a summary. Explain the legend once, casually, and don't repeat it again this session: ✅ connected, ❌ missing, ⚠️ registered but something's off, ⏳ waiting on a vendor, ➖ not used, 🔒 needs a restart, 🔎 Claude checks it live in this chat.

## Phase 3: work the list

Default order: PMS API, PMS official, pricing API, pricing official, Supabase (token, project, register), AirROI (both), Meta, Kie, Gemini, Firecrawl, ranking, ops. It's a default, not a law; chase whichever tab they're already on first.

Which connector file a row maps to:

| Slot | `.env` value | Connector file | Has an official MCP (Path B)? |
|---|---|---|---|
| PMS | `hospitable` | `connectors/pms-hospitable.md` | yes, browser sign-in |
| PMS | `hostaway` | `connectors/pms-hostaway.md` | no |
| PMS | `guesty` | `connectors/pms-guesty.md` | alpha stdio, Claude builds it |
| PMS | `hostfully` | `connectors/pms-hostfully.md` | no |
| PMS | `ownerrez` | `connectors/pms-ownerrez.md` | no |
| PMS | `lodgify` | `connectors/pms-lodgify.md` | yes, beta, browser sign-in |
| PMS | `uplisting` | `connectors/pms-uplisting.md` | yes, browser sign-in |
| PMS | `smoobu` | `connectors/pms-smoobu.md` | no |
| Pricing | `pricelabs` | `connectors/pricing-pricelabs.md` | yes, beta, admin only |
| Pricing | `beyond` | `connectors/pricing-beyond.md` | yes, beta (Neyoba) |
| Ranking | `rankbreeze` | `connectors/ranking-rankbreeze.md` | n/a, MCP only |
| Ranking | `intellihost` | `connectors/ranking-intellihost.md` | yes, browser sign-in |
| Ops | `turno` | `connectors/ops-turno.md` | n/a |
| Ops | `breezeway` | `connectors/ops-breezeway.md` | n/a |

Everyone also gets the fixed rows: `connectors/market-airroi.md`, `connectors/ads-meta.md`, `connectors/ai-kie.md`, `connectors/ai-gemini.md`, `connectors/web-firecrawl.md`, `connectors/db-supabase.md`.

For every ❌, ⚠️, or 🔎 row on the scoreboard:
1. Open the connector file the table above points to.
2. Follow section 3 (API key) for a key-shaped row, section 4 (official MCP) for a sign-in row, exactly as written. A 🔎 row is always a sign-in server: it shows that glyph whether or not it's been added yet, since the app never tells `~/.claude.json` about it. Hand the attendee the click path from section 4, wait for them to say "connected", then run the live check described there. No restart, no `.cache/needs-restart` marker, for this one.
3. Any time `.env` changes, run this before moving on; it copies the new value into every connector and skill folder that keeps its own copy, and it never prints a value while doing it.
   ```bash
   cd "$BUNDLE" && bash fan-out-env.sh
   ```
4. After a successful register:
   ```bash
   echo "<server>" >> "$BUNDLE/.cache/needs-restart"
   ```
5. A vendor-gated row (PriceLabs enable, Turno access, Breezeway credentials, Hostfully's API add-on): open the matching `emails/<file>.md`, hand the attendee the text to send, then mark it pending and move straight to the next row.
   ```bash
   echo "<server>|$(date +%F)" >> "$BUNDLE/.cache/pending-vendor"
   ```
   Never block the rest of setup on a vendor's reply. When they come back and say "X is enabled", clear that line and pick up at that connector's section 3.
   ```bash
   sed -i.bak '/^<server>|/d' "$BUNDLE/.cache/pending-vendor" && rm -f "$BUNDLE/.cache/pending-vendor.bak"
   ```

Supabase gets three sub-steps inside the same pass, since it is the one shared piece of infrastructure: the token (section 3), then the shared project (Claude asks one question, which region, then runs the bundled helper, never the attendee), then the register block. If `supabase-revenue-manager` is already registered from the Revenue Manager kit, pull just its project ref out of `~/.claude.json` with the one-line reader in `connectors/db-supabase.md` and skip straight to register; never re-create a second project.

AirROI registers twice from the same key and the same $10 deposit: the bundled `airroi` server (what the summit skills actually call) and `airroi-official` (AirROI's own hosted MCP). Do both; `connectors/market-airroi.md` sections 3 and 4 cover each.

Batch restarts instead of one per server: one after every API-key (stdio/header) server in this pass is registered. Restart sooner if they'd rather, they're the one running this, not you.

The sign-in servers (hospitable-official, lodgify-official, uplisting-official, beyond-official, pricelabs-official, intellihost, meta-ads) are different: Claude never registers them and they never need a restart. Hand them the click path from that connector file's section 4, wait for them to say "connected", then run the live check. Do this whenever it's convenient, in this pass or later; it doesn't need to line up with a restart batch.

Before each restart (API-key/stdio/header servers only), print the "After you restart" checklist:
- Quit and reopen the Claude Code desktop app, open this same folder.
- Say "Check my connections".

Once they're back, clear the marker and re-run the checker:
```bash
: > "$BUNDLE/.cache/needs-restart"
bash "$BUNDLE/check-connections.sh"
```

### Meta, the real test

Meta is a sign-in server: no registration, no restart. After the click path in `connectors/ads-meta.md` section 4 and the sign-in, run the real test, which IS the live check:
1. **"List my ad accounts."** Claude calls `ads_get_ad_accounts` and checks `is_ads_mcp_enabled` on what comes back.
2. **"Search the Ad Library for 'vacation rental' ads in the US, limit 1."** Claude calls `ads_library_search`.

Three outcomes: results come back and the Ad Spy is live; an error says no active ad account, in which case point them at Ads Manager to add a payment method and try the search again, and if it still fails after that, move on, the Ad Spy just runs degraded and nothing else in the kit is affected; every account shows `is_ads_mcp_enabled: false`, meaning Meta hasn't rolled the MCP out to that account yet, nothing to do on their end, check back in a week or two.

## Phase 4: final scoreboard and the done message

```bash
bash "$BUNDLE/check-connections.sh"
```
One more time. Once everything that matters is ✅ or ➖, send a done message, Solnest voice, no corporate tone, something in this shape:

> That's the whole kit wired up. Here's where things stand:
> - [list every ✅ row, plainly, one per line]
> - [any ⏳ pending-vendor row, with the date it was emailed, so they know to check back]
>
> Three things to try right now: ask me to pull your last 30 days of bookings, run a comp on your best listing, or spy on one competitor's ads.
>
> Questions, or something looks off? Skool: https://www.skool.com/solnest-ai

Celebrate the win. They just wired up ten-plus tools without ever touching a terminal.

## Running this again

Say "Check my connections" any time and Phase 2 through Phase 4 run again from wherever things stand (Phase 1 is skipped once the four answers are in `.env`); nothing gets re-asked that's already filled in, and nothing that already works gets touched. Changed a tool ("I moved to Beyond")? Re-run the `env_make.py` line from Phase 1 with the new answer; every existing key is carried over and the new slot appears. Say "Update my connections" and switch to `UPDATE.md` instead of this file; it handles pulling a newer version of the kit without touching anything already working.

## Server names, for reference

The names below are a fixed contract; the summit skills expect them exactly as written, so this is what `--list` should show once everything is wired up. Never rename one, and never register a second server for the same slot under a different name unless a connector file's section 3 or 4 says to.

| Slot | Server name(s) |
|---|---|
| PMS | one of `hospitable`, `hostaway`, `guesty`, `hostfully`, `ownerrez`, `lodgify`, `uplisting`, `smoobu` |
| PMS official | `<vendor>-official`, e.g. `hospitable-official`, `guesty-official`, `lodgify-official`, `uplisting-official` |
| Pricing | `pricelabs` or `beyond` |
| Pricing official | `pricelabs-official` or `beyond-official` |
| Ranking | `rankbreeze` or `intellihost` |
| Ops | `turno` or `breezeway` |
| Market data | `airroi` and `airroi-official` |
| Ads | `meta-ads` |
| AI | `kie` (Gemini has no server; the key alone is enough) |
| Web | `firecrawl` |
| Database | `supabase-revenue-manager` |

## Troubleshooting index

One line each, for when a row won't clear. Section 6 of each file has the real failure modes seen in testing; section 5 shows what pass and fail actually look like; section 7 has the dated vendor sources.
- `connectors/pms-hospitable.md`: Hospitable API key, or the official MCP browser sign-in.
- `connectors/pms-hostaway.md`: Hostaway API key and account ID.
- `connectors/pms-guesty.md`: Guesty OAuth application, Lite vs Pro, the server Claude builds.
- `connectors/pms-hostfully.md`: Hostfully's API add-on and the agency key.
- `connectors/pms-ownerrez.md`: OwnerRez Personal Access Token.
- `connectors/pms-lodgify.md`: Lodgify API key and the plan gate.
- `connectors/pms-uplisting.md`: Uplisting API key.
- `connectors/pms-smoobu.md`: Smoobu key and secret, and the request-signing switchover.
- `connectors/pricing-pricelabs.md`: PriceLabs API key, the enable step, and the official MCP.
- `connectors/pricing-beyond.md`: Beyond personal access token and the Pro gate.
- `connectors/ranking-rankbreeze.md`: RankBreeze MCP URL.
- `connectors/ranking-intellihost.md`: IntelliHost browser sign-in and its fallback token.
- `connectors/ops-turno.md`: Turno's API access request and the token.
- `connectors/ops-breezeway.md`: Breezeway's client credentials request.
- `connectors/market-airroi.md`: AirROI key, the $10 deposit, both the bundled and official server.
- `connectors/ads-meta.md`: Meta Ads browser sign-in and the fallback token.
- `connectors/ai-kie.md`: Kie key and the venv build.
- `connectors/ai-gemini.md`: Gemini key, no server to register for this one.
- `connectors/web-firecrawl.md`: Firecrawl key in a header, the hosted server.
- `connectors/db-supabase.md`: Supabase token, the shared project, the register block.
- `connectors/system-claude-code.md`: installing or updating Claude Code itself.
- `connectors/system-git.md`: Git, and Git Bash on Windows.
- `connectors/system-node.md`: Node.js and npx.
- `connectors/system-python-uv.md`: Python by way of uv.
