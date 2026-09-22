# KEYS.md: every key this kit uses, and where to get it

## Keys never touch the chat

Claude never asks for a key in the chat window. Not "paste it here", not "what's your key". Every key goes straight into a file called `.env` in this folder, and that file is the only place any of it lives. If a key ever ends up in the chat by accident, no drama: go rotate it (make a fresh one, delete the old one) in the vendor's dashboard, then paste the new one into `.env`.

If this folder lives on a Desktop or Documents that syncs to iCloud or OneDrive, your `.env` syncs with it. That is your own private cloud, which is fine, just know it is there.

## The 2-minute how-to

1. Claude opens `.env` for you. If it's not already open, ask it to.
2. Find the line for the key you have (each one ends in `=`, nothing after it yet).
3. Paste the key right after the `=`. No quotes, no spaces before or after it.
4. Save the file (Cmd+S on Mac, Ctrl+S on Windows).
5. Tell Claude "saved". It picks it up from there.

## Every variable, what it's for, and where to get it

Claude fills `STACK_PMS`, `STACK_PRICING`, `STACK_RANKING`, `STACK_OPS`, `SUPABASE_PROJECT_REF`, `SUPABASE_DB_PASSWORD`, and the three `SKILL_PATH_*` lines for you, from answers you give in chat or from what it finds on your machine. None of those are secrets and none of them need a vendor site. Everything below is a real credential you go get yourself.

### PMS: fill only the one you use

| Variable | For | Required? | Where to get it | Cost / gate |
|---|---|---|---|---|
| `HOSPITABLE_API_KEY` | Hospitable read/write API | if PMS = Hospitable | my.hospitable.com > Apps > API access > Access tokens > + Add new | free, but Essentials plan does not include API access |
| `HOSPITABLE_OFFICIAL_TOKEN` | fallback for Hospitable's official MCP, only if the browser sign-in loops | optional | Hospitable > Settings > Integrations > MCP > Fallback bearer tokens (`connectors/pms-hospitable.md` section 6) | free |
| `HOSTAWAY_ACCOUNT_ID` / `HOSTAWAY_API_KEY` | Hostaway API | if PMS = Hostaway | Hostaway dashboard > Settings > Hostaway API > Create | free, comes with your account |
| `GUESTY_CLIENT_ID` / `GUESTY_CLIENT_SECRET` | Guesty Open API | if PMS = Guesty | Guesty > Integrations > OAuth applications > New application | Pro or Enterprise plan only, not Lite |
| `HOSTFULLY_API_KEY` / `HOSTFULLY_AGENCY_UID` | Hostfully API | if PMS = Hostfully | Agency Settings > API Key field (UID at the bottom of the same page) | paid add-on, ask billing if you don't see it |
| `OWNERREZ_EMAIL` / `OWNERREZ_TOKEN` | OwnerRez Personal Access Token | if PMS = OwnerRez | Settings > Advanced Tools > Developer/API Settings > Personal Access Token | free, self-serve |
| `LODGIFY_API_KEY` | Lodgify Public API | if PMS = Lodgify | Settings > Public API | Starter/Professional/Ultimate only, not Basic |
| `UPLISTING_API_KEY` | Uplisting API | if PMS = Uplisting | Connect > API | free, all plans |
| `SMOOBU_API_KEY` / `SMOOBU_API_SECRET` | Smoobu API | if PMS = Smoobu | Settings > Advanced > API Keys > Create New | paid plan only, not a free trial |

### Pricing: fill only the one you use

| Variable | For | Required? | Where to get it | Cost / gate |
|---|---|---|---|---|
| `PRICELABS_API_KEY` | PriceLabs Customer API | if pricing = PriceLabs | app.pricelabs.co/account_settings?tab=api_details > Enable | $1 per listing per month that syncs prices |
| `PRICELABS_MCP_CLIENT_ID` / `PRICELABS_MCP_CLIENT_SECRET` | PriceLabs official MCP, Claude Code path | optional, account admin only | Account Settings > AI Connector (MCP) > Add Custom Client | free while in beta |
| `BEYOND_TOKEN` | Beyond dynamic pricing | if pricing = Beyond | v2.beyondpricing.com > Settings > Personal Access Tokens | needs an active Beyond Pro trial or subscription |

### Ranking (optional, pick one or neither)

| Variable | For | Required? | Where to get it | Cost / gate |
|---|---|---|---|---|
| `RANKBREEZE_MCP_URL` | RankBreeze MCP (the whole URL is the key) | optional | RankBreeze > Settings > MCP Credentials > MCP Access > Remote MCP > Copy URL | free, all listing plans |
| `INTELLIHOST_MCP_TOKEN` | fallback for IntelliHost's MCP, only if the browser sign-in loops | optional | IntelliHost > Connections > MCP access tokens (`connectors/ranking-intellihost.md` section 6) | free for the read tools, some features need the Agent plan |

### Ops (optional, pick one or neither)

| Variable | For | Required? | Where to get it | Cost / gate |
|---|---|---|---|---|
| `TURNO_API_TOKEN` / `TURNO_PARTNER_ID` | Turno cleaning and turnover data | if ops = Turno | Settings > Turno API > Tokens, after Turno grants access | free, but Turno has to switch access on for you first |
| `TURNO_ENV` | which Turno environment to use | leave blank, Claude sets `production` | n/a | n/a |
| `BREEZEWAY_CLIENT_ID` / `BREEZEWAY_CLIENT_SECRET` | Breezeway Client API | if ops = Breezeway | emailed to you by support@breezeway.io | usually free for an account holder reading their own data |

### Ads (required, everyone)

| Variable | For | Required? | Where to get it | Cost / gate |
|---|---|---|---|---|
| `META_ADS_TOKEN` | fallback for Meta Ads MCP, only if the browser sign-in won't stick | optional | a Meta system user token with the Employee role (`connectors/ads-meta.md` section 6) | free |

### Market data, AI, web, and database (required, everyone)

| Variable | For | Required? | Where to get it | Cost / gate |
|---|---|---|---|---|
| `AIRROI_API_KEY` | AirROI market data, comps, estimates | yes | airroi.com/api/developer | needs a $10 minimum deposit to activate |
| `KIE_API_KEY` | Kie.ai image and video generation for ads | yes | kie.ai/api-key | 80 free credits, then prepaid |
| `GEMINI_API_KEY` | Gemini photo scoring for the Listing Optimizer | yes | aistudio.google.com/apikey (make a NEW key; do not link billing) | free tier is enough |
| `FIRECRAWL_API_KEY` | Firecrawl, web pages turned into data | yes | firecrawl.dev/app/api-keys | free, 1,000 credits/month |
| `SUPABASE_ACCESS_TOKEN` | the shared database every skill writes to | yes | supabase.com/dashboard/account/tokens > Generate new token > "Create legacy token" link > Expires: Custom, one year out | free tier, one project |

## Day-0: send these today, they take days

A few of these depend on someone else replying, so get them moving the day this kit lands in your hands, not the night before the summit.

1. **Install Claude Code, Git, Node, and uv at home.** It's a real download; do not do this for the first time at the venue.
2. **Confirm you have a paid claude.ai plan** (Pro, Max, Team, or Enterprise). The free plan cannot run Claude Code.
3. **Email Turno** (help@turno.com, or paste into the in-app chat) asking for External API v2 access. Template: `emails/turno-api-access.md`.
4. **Email Breezeway**, if you use it (support@breezeway.io), asking for Client API credentials for your own account. Template: `emails/breezeway-request.md`. Also fill their request form the same day; no promised turnaround either way.
5. **Click Enable on PriceLabs' API Details page today.** If it errors, email support@pricelabs.co. Template: `emails/pricelabs-enable-api.md`. Know it's $1 per listing per month.
6. **Create your AirROI account and deposit $10.** The key does nothing until that deposit lands.
7. **Log in to Ads Manager** (adsmanager.facebook.com) with the Facebook profile that owns your ad account and confirm you can see one. Add a payment method if it asks; nothing runs without your say.
8. **Beyond users:** confirm you're on Beyond Pro, or request it in-app now.
9. **Guesty For Hosts users:** find out whether you landed on Lite (no API) or Pro.
10. **Make a fresh Gemini key** at aistudio.google.com/apikey. Do not link billing.
11. **RankBreeze users:** nothing to email. Log in, Settings > MCP Credentials > MCP Access > Remote MCP, and have the Copy URL button ready.

## If you leaked a key

No lecture, just fix it: go to the vendor's dashboard, delete or regenerate the key, paste the new one into `.env`, tell Claude "saved", and say "Check my connections" so it re-registers with the fresh value.
