#!/usr/bin/env bash
# lib/env_make.py builds a .env shaped to the four answers; lib/env_discover.py finds keys
# the attendee already has. Both run against a throwaway HOME so nothing real is touched.
set -u
cd "$(dirname "$0")/.."
. tests/_helpers.sh
fail=0; t(){ if eval "$2" >/dev/null 2>&1; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

PY=python3; command -v python3 >/dev/null || PY="uv run --python 3.13 python"
H="$(mktemp -d)"; iso_home "$H"; mkdir -p "$H/Desktop" "$H/Documents"
OUT="$H/kit/.env"; mkdir -p "$H/kit"

# ---- env_make: only the chosen slots ----
$PY lib/env_make.py --pms hospitable --pricing pricelabs --ranking none --ops turno --template .env.template --out "$OUT" >/dev/null
t "env_make writes the file"                      "[ -f '$OUT' ]"
t "env_make chmod 600"                            "mode_is_600 '$OUT'"
t "env_make fills the four answers"               "grep -q '^STACK_PMS=hospitable$' '$OUT' && grep -q '^STACK_PRICING=pricelabs$' '$OUT' && grep -q '^STACK_RANKING=none$' '$OUT' && grep -q '^STACK_OPS=turno$' '$OUT'"
t "env_make keeps the chosen PMS slot"            "grep -q '^HOSPITABLE_API_KEY=$' '$OUT'"
t "env_make drops the other seven PMS"            "! grep -qE '^(HOSTAWAY|GUESTY|HOSTFULLY|OWNERREZ|LODGIFY|UPLISTING|SMOOBU)_' '$OUT'"
t "env_make drops the unchosen pricing tool"      "grep -q '^PRICELABS_API_KEY=$' '$OUT' && ! grep -q '^BEYOND_TOKEN=' '$OUT'"
t "env_make drops ranking when none"              "! grep -qE '^(RANKBREEZE|INTELLIHOST)_' '$OUT'"
t "env_make keeps the chosen ops tool only"       "grep -q '^TURNO_API_TOKEN=$' '$OUT' && ! grep -q '^BREEZEWAY_' '$OUT'"
t "env_make keeps every required key"             "for v in AIRROI_API_KEY KIE_API_KEY GEMINI_API_KEY FIRECRAWL_API_KEY SUPABASE_ACCESS_TOKEN; do grep -q \"^\$v=\$\" '$OUT' || exit 1; done"
t "env_make leaves out sign-in fallback tokens"   "! grep -qE '^(META_ADS_TOKEN|HOSPITABLE_OFFICIAL_TOKEN|INTELLIHOST_MCP_TOKEN|PRICELABS_MCP_CLIENT_ID)=' '$OUT'"
t "env_make keeps the banner"                     "head -1 '$OUT' | grep -q '^# ===='"
t "env_make no em-dash"                           "! grep -q '—' '$OUT'"

# ---- env_make re-run: values carried over, old vendor kept, new slot appears ----
awk '$0=="HOSPITABLE_API_KEY=" {print "HOSPITABLE_API_KEY=hosp_sentinel"; next} $0=="AIRROI_API_KEY=" {print "AIRROI_API_KEY=air_sentinel"; next} {print}' "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"
$PY lib/env_make.py --pms lodgify --pricing beyond --ranking rankbreeze --ops none --template .env.template --out "$OUT" >/dev/null
t "re-run carries a filled required key"         "grep -q '^AIRROI_API_KEY=air_sentinel$' '$OUT'"
t "re-run adds the new vendor slots"             "grep -q '^LODGIFY_API_KEY=$' '$OUT' && grep -q '^BEYOND_TOKEN=$' '$OUT' && grep -q '^RANKBREEZE_MCP_URL=$' '$OUT'"
t "re-run keeps the old vendor's filled key"     "grep -q '^HOSPITABLE_API_KEY=hosp_sentinel$' '$OUT' && grep -q 'Kept from before' '$OUT'"
t "re-run updates the answers"                   "grep -q '^STACK_PMS=lodgify$' '$OUT' && grep -q '^STACK_OPS=none$' '$OUT'"
t "re-run drops the old ops slot"                "! grep -q '^TURNO_' '$OUT'"

# ---- env_discover: finds keys in other kits and registered servers, never prints a value ----
OUT="$H/kit2/.env"; mkdir -p "$H/kit2"   # a fresh file: the re-run above left keys filled in the first one
$PY lib/env_make.py --pms hospitable --pricing pricelabs --ranking rankbreeze --ops none --template .env.template --out "$OUT" >/dev/null
mkdir -p "$H/Documents/revenue-manager/mcp-servers/hospitable" "$H/Documents/some-kit/tests/fixtures"
printf 'HOSPITABLE_TOKEN=hosp_from_rm\nPRICELABS_API_KEY=pl_from_rm\n' > "$H/Documents/revenue-manager/.env"
printf 'AIRROI_API_KEY=air_from_fixture\n' > "$H/Documents/some-kit/tests/fixtures/env-leaky.env"
printf 'KIE_API_KEY=kie_from_example\n' > "$H/Documents/some-kit/.env.example"
cat > "$H/.claude.json" <<'EOF'
{"numStartups":1,"mcpServers":{
 "firecrawl":{"type":"http","url":"https://mcp.firecrawl.dev/v2/mcp","headers":{"Authorization":"Bearer fc-from-claude-json"}},
 "rankbreeze":{"type":"http","url":"https://app.rankbreeze.com/api/mcp/rb_mcp_from_json"},
 "supabase-revenue-manager":{"type":"stdio","command":"npx","args":["-y","@supabase/mcp-server-supabase@latest","--project-ref=refabc123"],"env":{"SUPABASE_ACCESS_TOKEN":"sbp_from_json"}},
 "hospitable":{"type":"stdio","command":"node","args":["HOMEDIR/Documents/revenue-manager/mcp-servers/hospitable/dist/index.js"]}
}}
EOF
sed -i.bak "s#HOMEDIR#$(native_path "$H")#" "$H/.claude.json" && rm -f "$H/.claude.json.bak"
printf 'HOSPITABLE_API_KEY=hosp_from_server_dir\n' > "$H/Documents/revenue-manager/mcp-servers/hospitable/.env"
REPORT="$($PY lib/env_discover.py --env "$OUT" --apply 2>&1)"
t "discover reports names only"                  "! printf '%s' \"\$REPORT\" | grep -q 'from_rm\\|from_json\\|from_server_dir\\|from_fixture'"
t "discover finds a key by its alias name"       "grep -q '^PRICELABS_API_KEY=pl_from_rm$' '$OUT'"
t "discover finds a header key in claude.json"   "grep -q '^FIRECRAWL_API_KEY=fc-from-claude-json$' '$OUT'"
t "discover finds a url server in claude.json"   "grep -q '^RANKBREEZE_MCP_URL=https://app.rankbreeze.com/api/mcp/rb_mcp_from_json$' '$OUT'"
t "discover finds env and arg in claude.json"    "grep -q '^SUPABASE_ACCESS_TOKEN=sbp_from_json$' '$OUT' && grep -q '^SUPABASE_PROJECT_REF=refabc123$' '$OUT'"
t "discover prefers a registered server's own .env" "grep -q '^HOSPITABLE_API_KEY=hosp_from_server_dir$' '$OUT'"
t "discover ignores tests/fixtures files"        "! grep -q 'air_from_fixture' '$OUT'"
t "discover ignores .env.example files"          "! grep -q 'kie_from_example' '$OUT'"
t "discover reports the not-found ones"          "printf '%s' \"\$REPORT\" | grep -q '^not found GEMINI_API_KEY'"
t "discover never overwrites a filled line"      "printf 'X\n' >/dev/null; grep -c '^PRICELABS_API_KEY=pl_from_rm$' '$OUT' | grep -q '^1$'"
t "discover helper has no em-dash"               "! grep -q '—' lib/env_discover.py lib/env_make.py"
t "discover counts each env file once"           "printf '%s' \"\$REPORT\" | grep -q '^searched 3 env file(s)'"   # kit/.env from the first block, revenue-manager/.env (reached from two roots, counted once), the hospitable server dir
t "discover reports home .env under its own path, not a server's" "printf '%s' \"\$REPORT\" | grep -q 'HOSPITABLE_API_KEY  <- .claude.json (registered MCP servers): hospitable -> hospitable/.env'"

# ---- a package name is not a path: "@scope/pkg@latest" must never walk the current directory ----
# (2026-09-22: it did, and read the kit's own .env plus whatever .env sat in CWD, labelled as that server's.)
OUT="$H/kit3/.env"; mkdir -p "$H/kit3"
CWD_OUTSIDE_HOME="$(mktemp -d)"   # must sit outside $HOME, or the ordinary home walk finds it legitimately
$PY lib/env_make.py --pms hospitable --pricing pricelabs --ranking none --ops none --template .env.template --out "$OUT" >/dev/null
printf 'GEMINI_API_KEY=leaked_from_cwd\nKIE_API_KEY=leaked_from_cwd\n' > "$CWD_OUTSIDE_HOME/.env"
printf 'FIRECRAWL_API_KEY=leaked_from_home\n' > "$H/.env"
cat > "$H/.claude.json" <<'EOF2'
{"mcpServers":{"scoped":{"type":"stdio","command":"npx","args":["-y","@scope/some-server@latest","--flag=x"]}}}
EOF2
REPO="$PWD"
REPORT3="$(cd "$CWD_OUTSIDE_HOME" && $PY "$REPO/lib/env_discover.py" --env "$OUT" --apply 2>&1)"
t "discover ignores a scoped package name as a path"  "! grep -q 'leaked_from_cwd' '$OUT'"
t "discover does not attribute ~/.env to a server"    "! printf '%s' \"\$REPORT3\" | grep -q 'scoped ->'"
# env_discover prints the native path of the found file: (/private)?<H>/.env on Mac,
# the C:\...\.env form on Windows. Match whichever this OS produces.
if is_windows; then
  _fc_env="$(cygpath -w "$H/.env")"
  t "discover still finds ~/.env by the walk, under its own path" "grep -q '^FIRECRAWL_API_KEY=leaked_from_home$' '$OUT' && printf '%s' \"\$REPORT3\" | grep -qF 'FIRECRAWL_API_KEY  <- $_fc_env'"
else
  t "discover still finds ~/.env by the walk, under its own path" "grep -q '^FIRECRAWL_API_KEY=leaked_from_home$' '$OUT' && printf '%s' \"\$REPORT3\" | grep -qE 'FIRECRAWL_API_KEY  <- (/private)?'\"$H\"'/.env'"
fi
rm -rf "$H" "$CWD_OUTSIDE_HOME"
