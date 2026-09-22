#!/usr/bin/env bash
# Scoreboard rows. Depends on row(), mcp_status(), probe_*(), env_filled().
PENDING_FILE=.cache/pending-vendor
RESTART_FILE=.cache/needs-restart
LIVE_FILE=.cache/live-ok
mkdir -p .cache 2>/dev/null; chmod 700 .cache 2>/dev/null

# _cfile SERVER: the connector file that documents this server (hints used to glue the
# server name into a path, which pointed at files that do not exist; Ryan's test run 2026-09-22)
_cfile() {
  case "$1" in
    hospitable|hospitable-official) echo pms-hospitable ;;
    hostaway) echo pms-hostaway ;;   guesty|guesty-official) echo pms-guesty ;;
    hostfully) echo pms-hostfully ;; ownerrez) echo pms-ownerrez ;;
    lodgify|lodgify-official) echo pms-lodgify ;;
    uplisting|uplisting-official) echo pms-uplisting ;;
    smoobu) echo pms-smoobu ;;
    pricelabs|pricelabs-official) echo pricing-pricelabs ;;
    beyond|beyond-official) echo pricing-beyond ;;
    rankbreeze) echo ranking-rankbreeze ;; intellihost) echo ranking-intellihost ;;
    turno) echo ops-turno ;;         breezeway) echo ops-breezeway ;;
    airroi|airroi-official) echo market-airroi ;;
    meta-ads) echo ads-meta ;;       kie) echo ai-kie ;;
    firecrawl) echo web-firecrawl ;; supabase-revenue-manager) echo db-supabase ;;
    *) echo "$1" ;;
  esac
}
_pending_date() { [ -f "$PENDING_FILE" ] && awk -F'|' -v n="$1" '$1==n{print $2; exit}' "$PENDING_FILE"; }
_needs_restart() { [ -f "$RESTART_FILE" ] && grep -qx "$1" "$RESTART_FILE"; }
_live_date()    { [ -f "$LIVE_FILE" ] && awk -F'|' -v n="$1" '$1==n{print $2; exit}' "$LIVE_FILE"; }

# check_api_row LABEL SERVER PROBE  (stdio server whose key is in .env)
check_api_row() {
  local label="$1" server="$2" probe="$3" pd st f
  f=$(_cfile "$server")
  pd=$(_pending_date "$server"); if [ -n "$pd" ]; then row "$label" vendor "emailed $pd; connectors/$f.md"; return; fi
  "$probe"; local prc=$?
  case $prc in
    2) row "$label" missing "paste the key into .env (connectors/$f.md)"; return ;;
    1) row "$label" keyfail "re-check the line in .env (connectors/$f.md)"; return ;;
    3) row "$label" keyfail "vendor unreachable or blocked; try again, then connectors/$f.md"; return ;;
  esac
  st=$(mcp_status "$server")
  if _needs_restart "$server"; then row "$label" restart; return; fi
  case "$st" in
    connected|registered) row "$label" ok ;;
    absent)    row "$label" missing "key works; server not registered yet (connectors/$f.md)" ;;
    *)         row "$label" keyfail "server status: $st (connectors/$f.md)" ;;
  esac
}
# check_oauth_row LABEL SERVER  (sign-in MCP the attendee adds in the app's Connectors UI.
# The app delivers a connected connector straight to the chat session; it never appears in
# ~/.claude.json, so there is nothing here for the checker to see. Claude verifies it live in
# the chat and, when that passes, records "SERVER|DATE" in .cache/live-ok; from then on the
# row shows ✅ with that date. No record yet = print the live-check row.)
check_oauth_row() {
  local label="$1" server="$2" ld
  ld=$(_live_date "$server")
  if [ -n "$ld" ]; then row "$label" ok "live check passed $ld; say \"recheck $server\" to run it again"; return; fi
  row "$label" live
}
# check_env_row LABEL PROBE FILE  (key only, no server)
check_env_row() {
  local label="$1" probe="$2" file="$3"
  "$probe"; case $? in
    0) row "$label" ok ;;
    2) row "$label" missing "paste the key into .env (connectors/$file.md)" ;;
    1) row "$label" keyfail "re-check the line in .env (connectors/$file.md)" ;;
    *) row "$label" keyfail "vendor unreachable; try again (connectors/$file.md)" ;;
  esac
}
# check_url_mcp_row LABEL SERVER VAR  (hosted MCP whose auth is a URL/header from .env)
check_url_mcp_row() {
  local label="$1" server="$2" var="$3" st f
  f=$(_cfile "$server")
  env_filled "$var" || { row "$label" missing "paste it into .env (connectors/$f.md)"; return; }
  if _needs_restart "$server"; then row "$label" restart; return; fi
  st=$(mcp_status "$server")
  case "$st" in connected|registered) row "$label" ok ;; absent) row "$label" missing "not registered (connectors/$f.md)" ;; *) row "$label" keyfail "server status: $st" ;; esac
}

scoreboard() {
  echo "STR Secrets Connections: scoreboard ($(date '+%Y-%m-%d %H:%M'))"; echo
  echo "System"
  command -v git >/dev/null    && row "Git" ok || row "Git" missing "connectors/system-git.md"
  command -v node >/dev/null   && row "Node.js" ok || row "Node.js" missing "connectors/system-node.md"
  command -v uv >/dev/null     && row "uv (Python)" ok || row "uv (Python)" missing "connectors/system-python-uv.md"
  row "Claude Code" ok
  echo; echo "PMS"
  case "${STACK_PMS:-}" in
    "")        row "PMS" missing "tell Claude which PMS you use" ;;
    hospitable) check_api_row "Hospitable API" hospitable probe_hospitable; check_oauth_row "Hospitable MCP (official)" hospitable-official ;;
    hostaway)  check_api_row "Hostaway API" hostaway probe_hostaway ;;
    guesty)    check_api_row "Guesty API" guesty probe_guesty; check_api_row "Guesty MCP (official, beta)" guesty-official probe_guesty ;;
    hostfully) check_api_row "Hostfully API" hostfully probe_hostfully ;;
    ownerrez)  check_api_row "OwnerRez API" ownerrez probe_ownerrez ;;
    lodgify)   check_api_row "Lodgify API" lodgify probe_lodgify; check_oauth_row "Lodgify MCP (official, beta)" lodgify-official ;;
    uplisting) check_api_row "Uplisting API" uplisting probe_uplisting; check_oauth_row "Uplisting MCP (official)" uplisting-official ;;
    smoobu)    check_api_row "Smoobu API" smoobu probe_smoobu ;;
    *)         row "PMS ($STACK_PMS)" missing "not one of the eight; build from research (build/build-pms-mcp.md)" ;;
  esac
  echo; echo "Pricing"
  case "${STACK_PRICING:-}" in
    "")        row "Pricing tool" missing "tell Claude: PriceLabs or Beyond" ;;
    pricelabs) check_api_row "PriceLabs API" pricelabs probe_pricelabs; check_oauth_row "PriceLabs MCP (official, beta)" pricelabs-official ;;
    beyond)    check_api_row "Beyond API" beyond probe_beyond; check_oauth_row "Beyond MCP (official, beta)" beyond-official ;;
  esac
  echo; echo "Ranking (optional)"
  case "${STACK_RANKING:-}" in
    rankbreeze)  check_url_mcp_row "RankBreeze MCP" rankbreeze RANKBREEZE_MCP_URL; row "IntelliHost MCP" na ;;
    intellihost) row "RankBreeze MCP" na; check_oauth_row "IntelliHost MCP" intellihost ;;
    *)           row "RankBreeze MCP" na; row "IntelliHost MCP" na ;;
  esac
  echo; echo "Ops (optional)"
  case "${STACK_OPS:-}" in
    turno)     check_api_row "Turno API" turno probe_turno; row "Breezeway API" na ;;
    breezeway) row "Turno API" na; check_api_row "Breezeway API" breezeway probe_breezeway ;;
    *)         row "Turno API" na; row "Breezeway API" na ;;
  esac
  echo; echo "Required for everyone"
  check_api_row  "AirROI API"           airroi probe_airroi
  check_url_mcp_row "AirROI MCP (official)" airroi-official AIRROI_API_KEY
  check_oauth_row "Meta Ads MCP"         meta-ads
  check_api_row  "Kie API"              kie probe_kie
  check_env_row  "Gemini API key"       probe_gemini ai-gemini
  check_api_row  "Firecrawl MCP"        firecrawl probe_firecrawl
  check_api_row  "Supabase MCP"         supabase-revenue-manager probe_supabase
  env_filled SUPABASE_PROJECT_REF && row "Supabase shared project" ok || row "Supabase shared project" missing "Claude creates or picks it (connectors/db-supabase.md)"
}
