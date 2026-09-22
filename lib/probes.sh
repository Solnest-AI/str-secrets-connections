#!/usr/bin/env bash
# One verify probe per vendor. Return codes: 0 works, 1 credential rejected, 2 blank/unset, 3 network/vendor/unknown.
# Probes print NOTHING. Bodies go to a temp file that is deleted. Keys are only ever passed as curl args from the environment.
UA="StrSecretsConnections/1.0 (Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/139.0.0.0 Safari/537.36)"

_http() { # _http BODYFILE args... ; prints status code only
  local body="$1"; shift
  curl -sS -m 15 -o "$body" -w '%{http_code}' "$@" 2>/dev/null || printf '000'
}
_classify() { # _classify STATUS BODYFILE : generic 200→0, 401/403→1, else 3
  case "$1" in 2??) return 0 ;; 401|403) return 1 ;; *) return 3 ;; esac
}

probe_hospitable() {
  env_filled HOSPITABLE_API_KEY || return 2
  local b; b=$(mktemp); local s
  s=$(_http "$b" -H "Accept: application/json" -H "Authorization: Bearer $HOSPITABLE_API_KEY" https://public.api.hospitable.com/v2/user)
  rm -f "$b"; _classify "$s"
}
probe_hostaway() {
  env_filled HOSTAWAY_ACCOUNT_ID && env_filled HOSTAWAY_API_KEY || return 2
  # Mirrors the built server: cache the token and reuse it if under 23h old.
  local cache=".cache/hostaway.token" tok b s
  mkdir -p .cache; chmod 700 .cache
  if [ -f "$cache" ] && [ -n "$(find "$cache" -mmin -1380 2>/dev/null)" ]; then tok=$(cat "$cache"); fi
  if [ -z "${tok:-}" ]; then
    b=$(mktemp); s=$(_http "$b" -X POST -H "Content-type: application/x-www-form-urlencoded" \
        --data "grant_type=client_credentials&client_id=$HOSTAWAY_ACCOUNT_ID&client_secret=$HOSTAWAY_API_KEY&scope=general" \
        https://api.hostaway.com/v1/accessTokens)
    case "$s" in 2??) ;; 4??) rm -f "$b"; return 1 ;; *) rm -f "$b"; return 3 ;; esac
    tok=$(sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p' "$b"); rm -f "$b"
    [ -n "$tok" ] || return 1
    printf '%s' "$tok" > "$cache"; chmod 600 "$cache"
  fi
  b=$(mktemp); s=$(_http "$b" -H "Authorization: Bearer $tok" -H "Cache-control: no-cache" https://api.hostaway.com/v1/users); rm -f "$b"
  [ "$s" = "403" ] && rm -f "$cache"
  _classify "$s"
}
probe_guesty() {
  env_filled GUESTY_CLIENT_ID && env_filled GUESTY_CLIENT_SECRET || return 2
  # Token cap is 5/day/client: reuse a cached token if under 23h old.
  local cache=".cache/guesty.token" tok b s
  mkdir -p .cache; chmod 700 .cache
  if [ -f "$cache" ] && [ -n "$(find "$cache" -mmin -1380 2>/dev/null)" ]; then tok=$(cat "$cache"); fi
  if [ -z "${tok:-}" ]; then
    b=$(mktemp); s=$(_http "$b" -X POST -H "Content-Type: application/x-www-form-urlencoded" \
        --data "grant_type=client_credentials&scope=open-api&client_id=$GUESTY_CLIENT_ID&client_secret=$GUESTY_CLIENT_SECRET" \
        https://open-api.guesty.com/oauth2/token)
    case "$s" in 2??) ;; 4??) rm -f "$b"; return 1 ;; *) rm -f "$b"; return 3 ;; esac
    tok=$(sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p' "$b"); rm -f "$b"
    [ -n "$tok" ] || return 1
    printf '%s' "$tok" > "$cache"; chmod 600 "$cache"
  fi
  b=$(mktemp); s=$(_http "$b" -H "accept: application/json" -H "Authorization: Bearer $tok" "https://open-api.guesty.com/v1/listings?limit=1"); rm -f "$b"
  _classify "$s"
}
probe_hostfully() {
  env_filled HOSTFULLY_API_KEY && env_filled HOSTFULLY_AGENCY_UID || return 2
  local b; b=$(mktemp); local s
  s=$(_http "$b" -H "X-HOSTFULLY-APIKEY: $HOSTFULLY_API_KEY" "https://api.hostfully.com/v3/properties?agencyUid=$HOSTFULLY_AGENCY_UID"); rm -f "$b"
  _classify "$s"
}
probe_ownerrez() {
  env_filled OWNERREZ_EMAIL && env_filled OWNERREZ_TOKEN || return 2
  local b; b=$(mktemp); local s
  s=$(_http "$b" -u "$OWNERREZ_EMAIL:$OWNERREZ_TOKEN" -A "$UA" -H "Content-Type: application/json" https://api.ownerrez.com/v2/users/me); rm -f "$b"
  _classify "$s"
}
probe_lodgify() {
  env_filled LODGIFY_API_KEY || return 2
  local b; b=$(mktemp); local s
  s=$(_http "$b" -H "X-ApiKey: $LODGIFY_API_KEY" -H "accept: application/json" https://api.lodgify.com/v2/properties); rm -f "$b"
  _classify "$s"   # 403 with empty body = bad key (verified live)
}
probe_uplisting() {
  env_filled UPLISTING_API_KEY || return 2
  local b; b=$(mktemp); local s enc
  enc=$(printf '%s' "$UPLISTING_API_KEY" | base64 | tr -d '\n')   # key alone, no colon, no newline
  s=$(_http "$b" -H "Content-Type: application/json" -H "Authorization: Basic $enc" https://connect.uplisting.io/users/me); rm -f "$b"
  _classify "$s"
}
probe_smoobu() {
  env_filled SMOOBU_API_KEY || return 2
  local b; b=$(mktemp); local s
  s=$(_http "$b" -H "Api-Key: $SMOOBU_API_KEY" -H "Cache-Control: no-cache" https://login.smoobu.com/api/me); rm -f "$b"
  case "$s" in 2??) return 0 ;; esac
  # Legacy header rejected (sunset). Try the HMAC scheme if a secret is present.
  env_filled SMOOBU_API_SECRET || { _classify "$s"; return; }
  local ts nonce bodyhash canon sig
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  nonce=$(uuidgen 2>/dev/null | tr 'A-Z' 'a-z' || python3 -c 'import uuid;print(uuid.uuid4())')
  bodyhash=$(printf '' | openssl dgst -sha256 | sed 's/^.* //')
  canon=$(printf 'GET\n/api/me\n\n%s\n%s\n%s\n%s' "$ts" "$nonce" "$bodyhash" "$SMOOBU_API_KEY")
  sig=$(printf '%s' "$canon" | openssl dgst -sha256 -hmac "$SMOOBU_API_SECRET" -binary | base64 | tr -d '\n')
  b=$(mktemp)
  s=$(_http "$b" -H "X-API-Key: $SMOOBU_API_KEY" -H "X-Timestamp: $ts" -H "X-Nonce: $nonce" -H "X-Signature: $sig" https://login.smoobu.com/api/me); rm -f "$b"
  _classify "$s"
}
probe_pricelabs() {
  env_filled PRICELABS_API_KEY || return 2
  local b; b=$(mktemp); local s
  s=$(_http "$b" -H "X-API-Key: $PRICELABS_API_KEY" https://api.pricelabs.co/v1/listings_minimal); rm -f "$b"
  _classify "$s"   # bad key = 403 API_KEY_INVALID
}
probe_beyond() {
  env_filled BEYOND_TOKEN || return 2
  local b; b=$(mktemp); local s
  s=$(_http "$b" -g -H "Authorization: Bearer $BEYOND_TOKEN" -H "Accept: application/vnd.api+json" "https://developers.beyondpricing.com/api/v1/listings/?page[size]=1"); rm -f "$b"
  _classify "$s"
}
probe_turno() {
  env_filled TURNO_API_TOKEN && env_filled TURNO_PARTNER_ID || return 2
  local host="https://api.turnoverbnb.com"; [ "${TURNO_ENV:-production}" = sandbox ] && host="https://sandbox.turnoverbnb.com"
  local b; b=$(mktemp); local s
  s=$(_http "$b" -H "Authorization: Bearer $TURNO_API_TOKEN" -H "TBNB-Partner-ID: $TURNO_PARTNER_ID" -H "Accept: application/json" -A "$UA" "$host/v2/userinfo")
  if [ "$s" = 403 ] && grep -qi "just a moment" "$b"; then rm -f "$b"; return 3; fi   # Cloudflare challenge, not credentials
  rm -f "$b"; _classify "$s"
}
probe_breezeway() {
  env_filled BREEZEWAY_CLIENT_ID && env_filled BREEZEWAY_CLIENT_SECRET || return 2
  local b; b=$(mktemp); local s
  s=$(_http "$b" -X POST -H "accept: application/json" -H "content-type: application/json" \
      --data "{\"client_id\":\"$BREEZEWAY_CLIENT_ID\",\"client_secret\":\"$BREEZEWAY_CLIENT_SECRET\"}" https://api.breezeway.io/public/auth/v1/)
  if [ "$s" = 200 ] && grep -q '"error"' "$b"; then rm -f "$b"; return 1; fi   # HTTP 200 "inactive client" = bad creds
  rm -f "$b"; _classify "$s"
}
probe_airroi() {
  env_filled AIRROI_API_KEY || return 2
  local b; b=$(mktemp); local s
  s=$(_http "$b" -H "X-API-KEY: $AIRROI_API_KEY" "https://api.airroi.com/markets/search?query=miami"); rm -f "$b"
  _classify "$s"   # $0.01 per call; bad key = 403
}
probe_kie() {
  env_filled KIE_API_KEY || return 2
  local b; b=$(mktemp); local s
  s=$(_http "$b" -H "Authorization: Bearer $KIE_API_KEY" https://api.kie.ai/api/v1/chat/credit)
  if [ "$s" = 200 ]; then
    if grep -q '"code":200' "$b"; then rm -f "$b"; return 0; else rm -f "$b"; return 1; fi   # 200 with code 401 = bad key
  fi
  rm -f "$b"; _classify "$s"
}
probe_gemini() {
  env_filled GEMINI_API_KEY || return 2
  local b; b=$(mktemp); local s
  s=$(_http "$b" -H "x-goog-api-key: $GEMINI_API_KEY" "https://generativelanguage.googleapis.com/v1beta/models"); rm -f "$b"
  case "$s" in 200) return 0 ;; 400|401|403) return 1 ;; *) return 3 ;; esac   # header form is the documented one (ai.google.dev api-key page)
}
probe_firecrawl() {
  env_filled FIRECRAWL_API_KEY || return 2
  local b; b=$(mktemp); local s
  s=$(_http "$b" -H "Authorization: Bearer $FIRECRAWL_API_KEY" https://api.firecrawl.dev/v2/team/credit-usage); rm -f "$b"
  _classify "$s"
}
probe_supabase() {
  env_filled SUPABASE_ACCESS_TOKEN || return 2
  local b; b=$(mktemp); local s
  s=$(_http "$b" -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" https://api.supabase.com/v1/projects); rm -f "$b"
  _classify "$s"
}
