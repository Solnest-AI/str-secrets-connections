---
server: firecrawl
slot: web
required: yes
env: [FIRECRAWL_API_KEY]
official_mcp: https://mcp.firecrawl.dev/v2/mcp
---

# Firecrawl: the web, turned into something Claude can read

## 1. What it is
Firecrawl fetches web pages and hands them back as clean text or structured data. Search the web, scrape one page, map a whole site, crawl it. The Comping Agent uses it for address lookups. The Ad Spy uses it too. This kit registers Firecrawl's own hosted MCP server, named `firecrawl`, with your key sent as a header. Nothing to install, nothing to build. 27 tools as of 2026-09-21.

## 2. Required, cost, gate
Required. Free. Firecrawl's pricing page: "Free Plan ... 1,000 credits / month $0" and "no credit card required" (effective Sept 4 2026). That is plenty for a summit weekend. No plan gate, no email to anyone.

Firecrawl also offers a keyless mode: "Try Instantly. No account or key. Search, Scrape, and Parse within daily limits." That is three tools with a daily cap. Not enough for the Comping Agent. Get the free key; it takes two minutes.

## 3. Path A: API key
1. Sign in or create an account at https://www.firecrawl.dev/signin.
2. Go to https://www.firecrawl.dev/app/api-keys (if you are logged out it bounces you to sign-in first; log in and try the link again).
3. Firecrawl's instruction on that page: "Create a Firecrawl API key, then add it as a bearer token in your client config." Create one, copy it.

**What it looks like:** starts with `fc-` followed by a long random string. We did not verify whether the dashboard shows it again later, so treat it as shown once: copy it when you make it.

One key, one line in `.env`. Claude opens the file for you; put the key after the equals sign, no quotes, no spaces, save, close. The file is the only place it goes. The chat window is never the place for it.
```
FIRECRAWL_API_KEY=
```

Then, from the bundle folder (`cd "$BUNDLE"`):

**SAFE:** `git check-ignore -q .env && echo "protected ✅"`
**FILLED:** `grep -q '^FIRECRAWL_API_KEY=.\+' .env && echo "present ✅" || echo "still blank"`
**WORKS:** `bash -c '. lib/env.sh; . lib/probes.sh; env_load .env; probe_firecrawl; echo rc=$?'` (0 works, 1 rejected, 2 blank, 3 unreachable)

**Register** Firecrawl's hosted server with the key in a header. Load the `.env` through the kit's `env_load` first: it trims stray spaces and Windows line endings so the header goes out clean. The remove line is on purpose: it clears any older `firecrawl` entry (keyless, stdio, or a stale key) so the new one wins.
```bash
. "$BUNDLE/lib/env.sh"; env_load "$BUNDLE/.env"
if [ -z "$FIRECRAWL_API_KEY" ]; then echo "FIRECRAWL_API_KEY is blank in .env. Fill it first, then run this block again."; else
claude mcp remove firecrawl -s user >/dev/null 2>&1 || true
if claude mcp add --transport http --scope user firecrawl https://mcp.firecrawl.dev/v2/mcp --header "Authorization: Bearer $FIRECRAWL_API_KEY" >/dev/null 2>&1; then echo "firecrawl registered ✅"; echo firecrawl >> "$BUNDLE/.cache/needs-restart"; else echo "firecrawl register failed. Run the claude mcp add line again without the >/dev/null 2>&1 part to see the error."; fi
fi
```
Then fully quit and reopen Claude Code. New servers only show up after a restart.

The header is stored in `~/.claude.json`, not in the URL. Firecrawl's own rule: "Configure the key through an environment variable or your client's secret storage, never in the MCP URL." So the `mcp.firecrawl.dev/<key>/` URL form is never used in this kit. And Claude never prints `claude mcp list` output to you, whatever is in it.

**Windows note:** run this under Git Bash (that is what Claude's Bash tool is). `$BUNDLE/.env` and `$BUNDLE/.cache/needs-restart` are read by bash itself, so the Git Bash form (`/c/Users/...`) is right as-is. Nothing here needs `cygpath -w` or `.venv/Scripts/python.exe`: the only things handed to `claude mcp add` are a URL and a header, and those are the same on every OS. That is also why the hosted server is the primary path on Windows; the npx fallback in section 6 has a known env-var problem there.

## 4. Path B: official MCP
This IS the official MCP. The register block in section 3 is the exact `claude mcp add --transport http` line, with the key as a `--header`. Auth is the header, not a browser login, so there is no `/mcp` > Authenticate step and no browser window opens.

Firecrawl documents two other ways in for the same server, and we register neither:
- **Keyless:** `claude mcp add --transport http firecrawl https://mcp.firecrawl.dev/v2/mcp` with no header. Three tools, daily limits. The Comping Agent needs more than that.
- **Sign-in:** the `https://mcp.firecrawl.dev/v2/mcp-oauth` URL, authenticated through the browser. Works, but it leaves no key in `.env`, so the checker has nothing to probe and nothing to rotate. The header form gives you both.

No beta, no waitlist as of 2026-09-21. After the restart, `/mcp` should list `firecrawl` as connected.

## 5. Verify
The checker runs `probe_firecrawl`, which makes one real call: `GET https://api.firecrawl.dev/v2/team/credit-usage` with your key in the `Authorization: Bearer` header. It reads your credit balance; it does not scrape anything. Outcomes (all confirmed live 2026-09-21):

- **200** with a JSON body: works. Row shows ✅.
- **401** `Unauthorized: Invalid token`: the key is wrong, revoked, or copied with a stray character. Re-copy it into `.env`, then re-run the whole register block in section 3 (the key lives inside the registered header, so fixing `.env` alone does not reach the server), restart Claude Code, then say "Check my connections".
- **401** saying "This endpoint is not supported by the keyless free tier": no key reached Firecrawl at all. The `.env` line was blank when the call went out. Fill it, run the probe again, then the register block.
- **Blank**: the `.env` line is empty. Paste the key into the file.
- **Unreachable**: no network, or Firecrawl is down. Try again in a minute.

One thing to know about the "Connected" label: the hosted server accepts the handshake and lists all 27 tools even when the key is bad. We tested it with a fake key on 2026-09-21: connected fine, then the first tool call came back `CREDENTIAL_INVALID` with "The Firecrawl API key is invalid or revoked." Connected means reachable, not authenticated. Trust the probe, not the label.

The in-chat test after restart: ask Claude "What is my Firecrawl credit usage?" It calls `firecrawl_credit_usage` and reports a number. That is the whole check.

## 6. Troubleshooting
- **Tools answer "The Firecrawl API key is invalid or revoked":** that is Firecrawl's `CREDENTIAL_INVALID`. The server was registered with a bad key. Fix the line in `.env`, re-run the whole register block in section 3 (it removes and re-adds), restart. Firecrawl's own fix text says the same: "Replace the key on the existing Firecrawl MCP server, then start a new session."
- **Tools answer "This tool needs a Firecrawl account":** that is `KEYLESS_TOOL_NOT_AVAILABLE`. The server was registered without the header (the keyless form). Re-run the register block in section 3.
- **`/mcp` warns "Leading or trailing whitespace in: headers.Authorization":** the `.env` line has a space or a newline hiding after the key. Claude Code does not trim it and the header goes out wrong. Open `.env`, delete anything after the last character of the key, re-run the register block.
- **Worked last week, now every call fails:** the usual cause is credits. Free plan is 1,000 a month and it resets monthly. Ask Claude for your credit usage; if it is at the cap, wait for the reset or upgrade at https://www.firecrawl.dev/pricing.
- **You already had a `firecrawl` server from before the summit:** the register block removes the user-scope one and replaces it. If yours lived in a project's `.mcp.json`, that copy stays and may win inside that project. Either is fine as long as it has a working key.
- **Hosted server unreachable and you need it now (fallback):** Firecrawl still supports a local server, vendor-pinned to 3.23.7. Needs Node 22 or newer (`node --version` to check; see the Node connector if it is older). The key goes in through `--env`, not the URL:
  ```bash
  . "$BUNDLE/lib/env.sh"; env_load "$BUNDLE/.env"
  if [ -z "$FIRECRAWL_API_KEY" ]; then echo "FIRECRAWL_API_KEY is blank in .env. Fill it first, then run this block again."; else
  claude mcp remove firecrawl -s user >/dev/null 2>&1 || true
  if claude mcp add --transport stdio firecrawl --scope user --env FIRECRAWL_API_KEY="$FIRECRAWL_API_KEY" -- npx -y firecrawl-mcp@3.23.7 >/dev/null 2>&1; then echo "firecrawl registered ✅"; echo firecrawl >> "$BUNDLE/.cache/needs-restart"; else echo "firecrawl register failed. Run the claude mcp add line again without the >/dev/null 2>&1 part to see the error."; fi
  fi
  ```
  Same server name, so the summit skills do not notice the swap. Windows: this path has a known problem passing the env var through npx; stay on the hosted server unless it is actually down.
- **You found the `mcp.firecrawl.dev/<key>/` URL style in an old tutorial:** do not use it. The key ends up in a URL, and URLs get logged. Firecrawl says header or secret storage, never the URL. The kit only ever registers the header form.

## 7. Sources
docs.firecrawl.dev/mcp-server and its keyless, oauth and local sub-pages; firecrawl.dev/pricing (effective Sept 4 2026); firecrawl.dev/app/api-keys; code.claude.com/docs/en/mcp (all read 2026-09-21). Error codes and the 27-tool count confirmed by live calls against api.firecrawl.dev and mcp.firecrawl.dev (server `firecrawl-fastmcp 3.25.2`) on 2026-09-21.
