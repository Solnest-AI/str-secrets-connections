---
server: meta-ads
slot: ads
required: yes
env: [META_ADS_TOKEN]
official_mcp: https://mcp.facebook.com/ads
portal: https://www.facebook.com/adsmanager/
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
A browser sign-in, added in the app.

**Claude does not register this one. You add it in the app, it takes about a minute.**
1. In the Claude Code desktop app, click the **+** next to the message box, then **Connectors**, then **Manage connectors**. The Connectors settings page opens.
2. Click **+ Add** (top right), then **Add custom connector**.
3. Type a name (Meta Ads is fine) and paste `https://mcp.facebook.com/ads` into **MCP server URL**. Click **Continue**.
4. A browser tab opens. Meta's description of what happens next: "The MCP client redirects you to the Facebook Login for Business dialog. You sign in with your Facebook account or your Meta Managed Account (MMA) and approve the requested permissions. No manual token setup is required." Log in with the Facebook profile that owns your ad account, not a personal profile that has never advertised. Approve the requested permissions when the dialog asks.
5. Done, it is on automatically. Come back and tell Claude "connected".

If the browser does not open on its own, copy the link Claude Code prints and open it yourself. Finish the sign-in on the same machine Claude Code is running on.

Capability warning: what you get depends on your ad account. Read tools (ad accounts, campaigns, insights, Ad Library search) need one active ad account. Write tools exist but always create things paused. Meta is rolling the MCP out account by account. Their Business Suite page says it plainly: "1. Go to Settings within Meta Business Suite. 2. Below Integrations, select Ads MCP server. Note: If you don't see this, you do not have access to this feature yet." No waitlist form to fill, but not every account has it yet as of 2026-09-21.

## 5. Verify
Until the real test below has passed once, the row prints `🔎 Meta Ads MCP   add it under + > Connectors; Claude checks it live`, whether or not you have added it yet, and even if you used the token fallback in section 6 (that path really does register in `~/.claude.json` and needs a restart, the row text just does not know to say so for this server). Once the test passes, Claude records it in `.cache/live-ok` and the row shows `✅ Meta Ads MCP   connected   → live check passed <date>` from then on. Say "recheck meta-ads" to run it again.

- Not added yet: run section 4, then tell Claude "connected".
- Added (or using the token fallback and restarted): run the real test below, in the chat. It IS the live check for this row.
- Before you sign in, the server answers every call with `401 Authentication Required`. That is the only code you will see from it un-authenticated, and it means exactly what it says.

The real test is two questions in chat, after the sign-in:

1. **"List my ad accounts."** Claude calls `ads_get_ad_accounts`. Look at `is_ads_mcp_enabled` on each account that comes back.
2. **"Search the Ad Library for 'vacation rental' ads in the US, limit 3."** Claude calls `ads_library_search`. The Ad Library matches loosely on creative text, so one of the three can be an ad that has nothing to do with rentals; that is Meta's search, not a broken connection. Results of any kind mean it works.

Outcomes:
- **Results come back**: works. Row shows ✅. The Ad Spy is live.
- **Error saying no active ad account**: Meta's own help page says you need a Facebook Page and a payment method on the ad account before you can advertise; if the Ad Library test says you have no active ad account, adding a payment method in Ads Manager is the usual fix (nothing runs without your say). Open https://adsmanager.facebook.com, confirm an ad account shows there, add a payment method if it asks, then ask the Ad Library question again. If it still errors with a payment method on file, Meta wants more from the account than that (unverified what, possibly a confirmed payment). Stop there: the Ad Spy runs degraded without it and the rest of the kit is unaffected.
- **Every account shows `is_ads_mcp_enabled: false`**: Meta has not rolled the MCP out to your account yet. Nothing to do on your side. The Ad Spy degrades without it; the rest of the kit is unaffected. Check back in a week or two.

## 6. Troubleshooting
- **Browser sign-in fails with "redirect_uris not registered":** update Claude Code from inside the app (Settings > Check for updates, or however this version surfaces it), then remove the connector under + > Connectors > Manage connectors and add it again.
- **Claude reports a timeout or the tools stop responding on a server you already signed in to:** usually a stale sign-in, not a broken account. Remove the connector under + > Connectors > Manage connectors and add it again. It is a re-login, not a re-register.
- **Fallback when the browser sign-in will not stick, only if you already have a Meta user access token:** we could not find a page in your Facebook or Business Suite account that hands out a token without a Meta developer app (Business Suite > Settings > Integrations > Ads MCP server only allows or blocks ad accounts, and needs full control of the Business Portfolio). If someone technical set a token up for you, register it as a header instead of a browser login (this path uses Claude's file-based register helper, not the Connectors UI, and does need a restart). Meta's one documented rule: a system user token works only with the **Employee** role; an Admin-role system user token is rejected. Any Meta user token expires; when this row flips to `registered, key fails` weeks later you need a fresh token and this section again. No token in hand? Skip this and retry the Connectors UI sign-in in section 4 instead.

  Claude opens `.env` for you; paste the token on this line, no quotes, no spaces, save, and never in the chat:
  ```
  META_ADS_TOKEN=
  ```
  Then Claude registers it as a header:
  ```bash
  set -a; . "$BUNDLE/.env"; set +a
  uv run --python 3.13 python "$BUNDLE/lib/mcp_register.py" meta-ads --http https://mcp.facebook.com/ads --header "Authorization: Bearer META_ADS_TOKEN" && echo "meta-ads registered ✅" || echo "meta-ads register failed ❌"
  echo meta-ads >> "$BUNDLE/.cache/needs-restart"
  ```
  The token lands in `~/.claude.json`, never in the chat. Treat that file as a secret from then on.
- **Signed in with the wrong Facebook profile:** the browser used whichever profile was already logged in at facebook.com. Log out of facebook.com in that browser, remove the connector under + > Connectors > Manage connectors, add it again, and log in with the profile that owns the ad account.
- **"List my ad accounts" works but Ad Library search errors:** you have an ad account but it is not active. Ads Manager will tell you why (no payment method, disabled, restricted). Fix it there, then retry.
- **Claude says it created a campaign or ad set:** it is paused. Meta's rule: "Write tools create entities in a paused state." Open Ads Manager, look at it, delete it or leave it. It only starts spending if someone activates it, either in Ads Manager or through the `ads_activate_entity` tool. The kit never calls that tool; do not ask Claude to.
- **Scoreboard stays on Restart (only happens if you used the token fallback above):** the `needs-restart` marker clears on the next launch. Quit the Claude Code desktop app fully (not just the window) and open it again. The Connectors-UI sign-in in section 4 never needs a restart.
- **Ads MCP server is not under Integrations in Business Suite:** Meta's own note: "If you don't see this, you do not have access to this feature yet." The browser sign-in may still work; try it. If it also fails, wait for the rollout.

## 7. Sources
developers.facebook.com, Ads MCP server "Get started" ("Updated: Sep 4, 2026") and "Tools" pages. facebook.com/business/help/1456422242197840 (How to set up Meta ads AI connectors) and facebook.com/business/help/407323696966570 (ad account basics), read 2026-09-21. Live tool schema for `ads_library_search` and `ads_get_ad_accounts`, read 2026-09-21. Server name from the kit brief, task 10 step 2; Connectors-UI click path confirmed against the Claude Code desktop app, task 12c.
