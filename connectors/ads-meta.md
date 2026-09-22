---
server: meta-ads
slot: ads
required: yes
env: []
official_mcp: https://mcp.facebook.com/ads
---

# Meta Ads: the Ad Library and your ad accounts, through Meta's own MCP

## 1. What it is
Meta runs an official MCP server for ads at https://mcp.facebook.com/ads. Claude signs in with your Facebook profile and gets tools for your ad accounts, campaigns, insights, and the public Ad Library. The Ad Spy skill searches the Ad Library through it: what your competitors are running, what their hooks say, what offers they push. Nothing to build, nothing to paste, nothing goes in `.env`. Claude signs in through your browser instead of reading a key.

## 2. Required, cost, gate
Required. The Ad Spy does not work without it.

Free. Meta charges nothing for the MCP. Running ads costs money, and this server can touch that: creating things is safe (Meta's docs say "Write tools create entities in a paused state"), but the server also has an `ads_activate_entity` tool that switches a paused campaign live and starts spending. The Ad Spy never calls it. If Claude ever offers to activate, publish, or resume anything in your ad account, say no. Nothing spends unless that tool runs or you flip it on yourself in Ads Manager.

What you need:
- A Facebook profile. Meta's words: "When you sign up for Facebook, you're given an ad account by default."
- At least one **active** ad account on that profile. The live tool schema says the Ad Library search "is only available to viewers who have at least one active ad account; callers without an active ad account will receive an error rather than results."
- No Meta developer app. Meta's get-started page: "Owning a Meta app is not a prerequisite on using the ads MCP server."

Two Meta rules to know before you hit them. "All advertisers are limited to one ad account ID until they make a confirmed payment." And before an account can advertise you need a Page (or a role on one) and to "Set up a valid payment method." Adding a payment method never charges you by itself; a charge only happens when an ad runs. Whether a card on file is enough for Meta to call the account "active" for the Ad Library is something Meta's docs do not say and we could not verify, so treat it as the first thing to try, not a guarantee.

No email to anyone, no waitlist form, no `emails/` file for this one. Rollout is staged on Meta's side, though: see section 5 for how to tell whether your account has it yet.

## 3. Path A: API key
_None for this connector._ There is no key to fetch and no `.env` line. Go straight to Path B.

## 4. Path B: official MCP
One `claude mcp add` line, then a browser sign-in. Meta's own doc shows the line with `--client-id <META_APP_ID>`; that is for people who own a Meta developer app. You do not, so it is dropped. Honesty note: Meta documents this no-app line for Claude Code, and as of 2026-09-21 Meta's sign-in endpoint accepts Claude Code's registration, but we have not run the browser sign-in end to end from Claude Code without a Meta app. If it fails, it is not you; go to section 6.

**Register:**
```bash
claude mcp remove meta-ads -s user >/dev/null 2>&1 || true
claude mcp add --transport http meta-ads --scope user https://mcp.facebook.com/ads >/dev/null 2>&1 && echo "meta-ads registered ✅" || echo "meta-ads register failed ❌ (run the same line again without the >/dev/null part to see why)"
echo meta-ads >> "$BUNDLE/.cache/needs-restart"
```
Windows: run this in Git Bash (Claude's Bash tool). Nothing on the `claude mcp add` line is a file path, so no `cygpath -w` and no `.venv/Scripts/python.exe` here. The `$BUNDLE/.cache/needs-restart` write stays inside Bash and works as-is.

**Restart Claude Code.** Then type `/mcp`, pick **meta-ads**, choose **Authenticate**. Claude Code opens a browser link. Meta's description of what happens next: "The MCP client redirects you to the Facebook Login for Business dialog. You sign in with your Facebook account or your Meta Managed Account (MMA) and approve the requested permissions. No manual token setup is required."

Log in with the Facebook profile that owns your ad account, not a personal profile that has never advertised. Approve the requested permissions when the dialog asks. If the browser does not open on its own, copy the link Claude Code prints and open it yourself. Finish the sign-in on the same machine Claude Code is running on.

Capability warning: what you get depends on your ad account. Read tools (ad accounts, campaigns, insights, Ad Library search) need one active ad account. Write tools exist but always create things paused. Meta is rolling the MCP out account by account. Their Business Suite page says it plainly: "1. Go to Settings within Meta Business Suite. 2. Below Integrations, select Ads MCP server. Note: If you don't see this, you do not have access to this feature yet." No waitlist form to fill, but not every account has it yet as of 2026-09-21.

## 5. Verify
The checker reads Claude Code's own server status for `meta-ads` and shows one row, **Meta Ads MCP**, using the same icons and wording as every other row in the scoreboard:

- `✅ Meta Ads MCP   connected`: signed in and working. Move on to the real test.
- `⚠️ Meta Ads MCP   registered, not authenticated (/mcp > Authenticate)`: registered but not signed in yet, or Claude Code is waiting for you to approve the server first (hint: `approve it in /mcp`). Open `/mcp`, approve the server if it asks, then Authenticate and finish the browser sign-in.
- `⚠️ Meta Ads MCP   registered, key fails`: unusual for this row since it has no key; it shows up if the server reports a status the checker does not otherwise recognize. Try `/mcp` > meta-ads > Authenticate again; if that does not clear it, see section 6.
- `🔒 Meta Ads MCP   needs a full restart of Claude Code`: registered this session and Claude Code has not been restarted. Restart, then say "Check my connections" again.
- `❌ Meta Ads MCP   missing`: not registered. Run the register block in section 4.

Before you sign in, the server answers every call with `401 Authentication Required`. That is the only code you will see from it un-authenticated, and it means exactly what it says.

The real test is two questions in chat, after the restart and the sign-in:

1. **"List my ad accounts."** Claude calls `ads_get_ad_accounts`. Look at `is_ads_mcp_enabled` on each account that comes back.
2. **"Search the Ad Library for 'vacation rental' ads in the US, limit 1."** Claude calls `ads_library_search`.

Outcomes:
- **Results come back**: works. Row shows ✅. The Ad Spy is live.
- **Error saying no active ad account**: Meta's own help page says you need a Facebook Page and a payment method on the ad account before you can advertise; if the Ad Library test says you have no active ad account, adding a payment method in Ads Manager is the usual fix (nothing runs without your say). Open https://adsmanager.facebook.com, confirm an ad account shows there, add a payment method if it asks, then ask the Ad Library question again. If it still errors with a payment method on file, Meta wants more from the account than that (unverified what, possibly a confirmed payment). Stop there: the Ad Spy runs degraded without it and the rest of the kit is unaffected.
- **Every account shows `is_ads_mcp_enabled: false`**: Meta has not rolled the MCP out to your account yet. Nothing to do on your side. The Ad Spy degrades without it; the rest of the kit is unaffected. Check back in a week or two.

## 6. Troubleshooting
- **Browser sign-in fails with "redirect_uris not registered":** a Claude Code OAuth bug that has been closed twice (GitHub anthropics/claude-code #57191, #58054). Run `claude update`, then `claude mcp remove meta-ads -s user`, re-run the register block, restart, Authenticate again.
- **Meta Ads MCP row says `server status: failed`, or Claude reports `connection timed out after 30000ms` on a server you already signed in to:** Claude Code issue #89528 (open as of 2026-09-21). Claude Code's OAuth layer wrongly decides the stored Meta token expired; the token itself is fine. The text `OAuth session expired and could not be refreshed` only shows with `claude --debug`, so no need to go hunting for it. The reporter says it is fixed on Claude Code 2.1.270. Run `claude update`, quit and reopen Claude Code, then `/mcp` > meta-ads > **Authenticate** again. It is a re-login, not a re-register.
- **Fallback when OAuth will not stick, only if you already have a Meta user access token:** we could not find a page in your Facebook or Business Suite account that hands out a token without a Meta developer app (Business Suite > Settings > Integrations > Ads MCP server only allows or blocks ad accounts, and needs full control of the Business Portfolio). If someone technical set a token up for you, register it as a header instead of a browser login. Meta's one documented rule: a system user token works only with the **Employee** role; an Admin-role system user token is rejected. Any Meta user token expires; when this row flips to `registered, key fails` weeks later you need a fresh token and this block again. No token in hand? Skip this, run `claude update`, and retry `/mcp` > meta-ads > **Authenticate**. Do this in a terminal you type into yourself (Terminal on Mac, Git Bash on Windows; skip PowerShell and cmd), never the chat, from inside the kit folder. Claude prints the folder path for you; a path is not a secret.
  ```bash
  cd "<kit folder>"
  printf 'Meta token, then Enter: '; read -rs META_TOKEN; echo
  claude mcp remove meta-ads -s user >/dev/null 2>&1 || true
  claude mcp add --transport http meta-ads --scope user https://mcp.facebook.com/ads --header "Authorization: Bearer $META_TOKEN" >/dev/null 2>&1 && echo "meta-ads registered ✅" || echo "meta-ads register failed ❌"
  unset META_TOKEN
  mkdir -p .cache && echo meta-ads >> .cache/needs-restart
  ```
  `read -rs` keeps the token off the screen and out of your shell history. The token lands in `~/.claude.json`. Treat that file as a secret from then on.
- **Signed in with the wrong Facebook profile:** the browser used whichever profile was already logged in at facebook.com. Log out of facebook.com in that browser, run `/mcp` > meta-ads > Authenticate again, and log in with the profile that owns the ad account.
- **"List my ad accounts" works but Ad Library search errors:** you have an ad account but it is not active. Ads Manager will tell you why (no payment method, disabled, restricted). Fix it there, then retry.
- **Claude says it created a campaign or ad set:** it is paused. Meta's rule: "Write tools create entities in a paused state." Open Ads Manager, look at it, delete it or leave it. It only starts spending if someone activates it, either in Ads Manager or through the `ads_activate_entity` tool. The kit never calls that tool; do not ask Claude to.
- **Scoreboard stays on Restart:** the `needs-restart` marker clears on the next launch. Quit Claude Code fully (not just the tab) and open it again.
- **Ads MCP server is not under Integrations in Business Suite:** Meta's own note: "If you don't see this, you do not have access to this feature yet." The browser sign-in may still work; try it. If it also fails, wait for the rollout.

## 7. Sources
developers.facebook.com, Ads MCP server "Get started" ("Updated: Sep 4, 2026") and "Tools" pages. facebook.com/business/help/1456422242197840 (How to set up Meta ads AI connectors) and facebook.com/business/help/407323696966570 (ad account basics), read 2026-09-21. code.claude.com/docs/en/mcp ("Option 1: Add a remote HTTP server"). Live tool schema for `ads_library_search` and `ads_get_ad_accounts`, read 2026-09-21. GitHub anthropics/claude-code #89528 (open), #57191 and #58054 (closed). Register command shape and server name from the kit brief, task 10 step 2.
