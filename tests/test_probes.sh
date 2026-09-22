#!/usr/bin/env bash
set -u; cd "$(dirname "$0")/.."
. lib/env.sh; . lib/probes.sh
export CURL_STUB_DIR="$PWD/tests/fixtures/curl"
fail=0; t(){ if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
export HOSPITABLE_API_KEY=x PRICELABS_API_KEY=x KIE_API_KEY=x AIRROI_API_KEY=x LODGIFY_API_KEY=x BREEZEWAY_CLIENT_ID=x BREEZEWAY_CLIENT_SECRET=x TURNO_API_TOKEN=x TURNO_PARTNER_ID=x SUPABASE_ACCESS_TOKEN=x GEMINI_API_KEY=GEMKEY
t "hospitable 200 → 0"            "probe_hospitable; [ \$? -eq 0 ]"
t "pricelabs 403 → 1 (not 3)"     "probe_pricelabs; [ \$? -eq 1 ]"
t "kie 200 body code 401 → 1"     "probe_kie; [ \$? -eq 1 ]"
t "airroi 403 → 1"                "probe_airroi; [ \$? -eq 1 ]"
t "lodgify 403 empty → 1"         "probe_lodgify; [ \$? -eq 1 ]"
t "breezeway 200 inactive → 1"    "probe_breezeway; [ \$? -eq 1 ]"
t "turno html 403 → 3 (cloudflare)" "probe_turno; [ \$? -eq 3 ]"
t "supabase 200 → 0"              "probe_supabase; [ \$? -eq 0 ]"
t "gemini 200 → 0"                "probe_gemini; [ \$? -eq 0 ]"
t "blank key → 2"                 "unset HOSPITABLE_API_KEY; probe_hospitable; [ \$? -eq 2 ]"
t "unknown host → 3"              "export FIRECRAWL_API_KEY=x; probe_firecrawl; [ \$? -eq 3 ]"
t "probes print nothing"          "export HOSPITABLE_API_KEY=x; [ -z \"\$(probe_hospitable 2>&1; probe_pricelabs 2>&1; probe_kie 2>&1)\" ]"
exit $fail
