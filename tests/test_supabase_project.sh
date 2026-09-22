#!/usr/bin/env bash
# Runs lib/supabase_project.py against the canned Management API in tests/stubs
# (PYTHONPATH shadows urllib; sitecustomize neutralises time.sleep). No network.
set -u
cd "$(dirname "$0")/.."
fail=0
t(){ if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

# Same interpreter the summit conductor uses; plain python3 when uv is absent.
if command -v uv >/dev/null 2>&1; then PY=(uv run --no-project --python 3.13 python); else PY=(python3); fi

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export PYTHONPATH=tests/stubs PYTHONDONTWRITEBYTECODE=1
export SUPABASE_ACCESS_TOKEN=sbp_test_token_not_real

run(){ # $1 scenario -> sets OUT RC LOG ENVF
  ENVF="$TMP/$1.env"; LOG="$TMP/$1.log"; : > "$LOG"
  cp .env.template "$ENVF"
  OUT="$(STUB_SCENARIO="$1" STUB_LOG="$LOG" BUNDLE_ENV="$ENVF" "${PY[@]}" lib/supabase_project.py 2>&1)"; RC=$?
}

# 1. existing project: found by name, nothing created, nothing written
run existing
t "existing: exit 0"                       "[ $RC -eq 0 ]"
t "existing: prints REF= of the match"     "[ \"\$OUT\" = 'REF=abc123ref' ]"
t "existing: no POST sent"                 "! grep -q '\"method\": \"POST\"' \"\$LOG\""
t "existing: BUNDLE_ENV untouched"         "cmp -s .env.template \"\$ENVF\""

# 2. two active projects: CAP, exit 3, nothing created
run cap
t "cap: exit 3"                            "[ $RC -eq 3 ]"
t "cap: prints CAP line"                   "grep -q '^CAP: free tier allows 2 active projects' <<<\"\$OUT\""
t "cap: names the two active projects"     "grep -q 'first-app, second-app' <<<\"\$OUT\""
t "cap: paused project not counted"        "! grep -q 'paused-app' <<<\"\$OUT\""
t "cap: no POST sent"                      "! grep -q '\"method\": \"POST\"' \"\$LOG\""
t "cap: BUNDLE_ENV untouched"              "cmp -s .env.template \"\$ENVF\""

# 3. empty account: creates, polls to ACTIVE_HEALTHY, appends the password, prints REF=
run create
t "create: exit 0"                         "[ $RC -eq 0 ]"
t "create: prints REF= of the new project" "[ \"\$OUT\" = 'REF=newref123456' ]"
t "create: one POST /projects"             "[ \$(grep -c '\"method\": \"POST\", \"url\": \"https://api.supabase.com/v1/projects\"' \"\$LOG\") -eq 1 ]"
t "create: POST names str-secrets-summit"  "grep '\"method\": \"POST\"' \"\$LOG\" | grep -q '\"name\": \"str-secrets-summit\"'"
t "create: POST carries region default"    "grep '\"method\": \"POST\"' \"\$LOG\" | grep -q '\"region_selection\": {\"type\": \"specific\", \"code\": \"us-east-1\"}'"
t "create: POST carries organization_slug" "grep '\"method\": \"POST\"' \"\$LOG\" | grep -q '\"organization_slug\": \"org-slug-1\"'"
t "create: POST sends no deprecated field" "! grep '\"method\": \"POST\"' \"\$LOG\" | grep -qE '\"(plan|region|organization_id)\": '"
t "create: polled the new project status"  "grep -q '\"url\": \"https://api.supabase.com/v1/projects/newref123456\"' \"\$LOG\""
t "create: SUPABASE_DB_PASSWORD= appended" "grep -qE '^SUPABASE_DB_PASSWORD=.{20,}$' \"\$ENVF\""
t "create: appended password is the POSTed db_pass" "pw=\$(grep -E '^SUPABASE_DB_PASSWORD=.+' \"\$ENVF\" | tail -1 | cut -d= -f2-); grep '\"method\": \"POST\"' \"\$LOG\" | grep -qF \"\\\"db_pass\\\": \\\"\$pw\\\"\""
t "create: rest of BUNDLE_ENV intact"      "diff <(grep -v '^SUPABASE_DB_PASSWORD=.\\+' \"\$ENVF\") .env.template >/dev/null"
t "create: token never printed"            "! grep -q 'sbp_test_token_not_real' <<<\"\$OUT\""

# 4. region override reaches the POST body
run_region(){ ENVF="$TMP/region.env"; LOG="$TMP/region.log"; : > "$LOG"; cp .env.template "$ENVF"
  OUT="$(STUB_SCENARIO=create STUB_LOG="$LOG" BUNDLE_ENV="$ENVF" SUPABASE_REGION=ca-central-1 "${PY[@]}" lib/supabase_project.py 2>&1)"; RC=$?; }
run_region
t "region: SUPABASE_REGION reaches POST"   "grep '\"method\": \"POST\"' \"\$LOG\" | grep -q '\"region_selection\": {\"type\": \"specific\", \"code\": \"ca-central-1\"}'"

# 5. blank token: fails before any call
OUT="$(env -u SUPABASE_ACCESS_TOKEN STUB_SCENARIO=create STUB_LOG="$TMP/blank.log" BUNDLE_ENV="$TMP/blank.env" "${PY[@]}" lib/supabase_project.py 2>&1)"; RC=$?
t "blank token: non-zero exit"             "[ $RC -ne 0 ]"
t "blank token: no call made"              "[ ! -s \"$TMP/blank.log\" ]"

# 6. helper output carries no em-dash (attendee-facing script output rule)
t "helper source has no em-dash"           "! grep -q \$'\\xe2\\x80\\x94' lib/supabase_project.py"

[ $fail -eq 0 ] && echo "ok   supabase_project helper"
exit $fail
