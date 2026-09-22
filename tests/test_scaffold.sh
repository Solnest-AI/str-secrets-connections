#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/.."
fail=0
t(){ if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
t "gitignore blocks .env"            "git check-ignore -q .env"
t "gitignore blocks .env.local"      "git check-ignore -q .env.local"
t "gitignore allows .env.template"   "! git check-ignore -q .env.template"
t "gitignore blocks .cache/"         "git check-ignore -q .cache/x"
t "gitignore blocks node_modules"    "git check-ignore -q mcp-servers/hospitable/node_modules/x"
t "gitignore blocks .venv"           "git check-ignore -q mcp-servers/airroi/.venv/bin/python"
t "gitignore blocks session.txt"     "git check-ignore -q mcp-servers/rankbreeze/session.txt"
t "template has every canonical var" "for v in HOSPITABLE_API_KEY HOSTAWAY_ACCOUNT_ID HOSTAWAY_API_KEY GUESTY_CLIENT_ID GUESTY_CLIENT_SECRET HOSTFULLY_API_KEY HOSTFULLY_AGENCY_UID OWNERREZ_EMAIL OWNERREZ_TOKEN LODGIFY_API_KEY UPLISTING_API_KEY SMOOBU_API_KEY SMOOBU_API_SECRET PRICELABS_API_KEY PRICELABS_MCP_CLIENT_ID PRICELABS_MCP_CLIENT_SECRET BEYOND_TOKEN RANKBREEZE_MCP_URL TURNO_API_TOKEN TURNO_PARTNER_ID TURNO_ENV BREEZEWAY_CLIENT_ID BREEZEWAY_CLIENT_SECRET AIRROI_API_KEY KIE_API_KEY GEMINI_API_KEY FIRECRAWL_API_KEY SUPABASE_ACCESS_TOKEN SUPABASE_PROJECT_REF SUPABASE_DB_PASSWORD STACK_PMS STACK_PRICING STACK_RANKING STACK_OPS SKILL_PATH_REVENUE_MANAGER SKILL_PATH_LISTING_OPTIMIZER SKILL_PATH_COMPING_AGENT; do grep -q \"^\$v=\$\" .env.template || { echo missing \$v; exit 1; }; done"
t "template has no filled values"    "! grep -qE '^[A-Z_]+=.+' .env.template"
t "TURNO_ENV defaults production"    "grep -q '^# TURNO_ENV: production' .env.template"
t "VERSION matches the newest CHANGELOG entry" "[ \"\$(cat VERSION)\" = \"\$(grep -m1 '^## ' CHANGELOG.md | awk '{print \$2}')\" ]"
t "gitattributes forces LF on sh"    "grep -qE '^\*\.sh +text +eol=lf' .gitattributes"
t "gitattributes forces LF on env"   "grep -qE '^\.env\.template +text +eol=lf' .gitattributes"
t "no CRLF in any sh"                "! grep -rl \$'\\r' --include=*.sh . 2>/dev/null | grep -q ."
exit $fail
