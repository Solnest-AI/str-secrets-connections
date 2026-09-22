#!/usr/bin/env bash
set -u; cd "$(dirname "$0")/.."
export CURL_STUB_DIR="$PWD/tests/fixtures/curl"
export CLAUDE_STUB_FIXTURE="$PWD/tests/fixtures/mcp-list-hospitable-full.txt"
fail=0; t(){ if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
tmp=$(mktemp -d); cp -R . "$tmp/repo" >/dev/null 2>&1; cd "$tmp/repo"
cp tests/fixtures/env-hospitable-full.env .env
out="$(bash check-connections.sh)"; rc=$?
t "exit 0 when it ran"                 "[ $rc -eq 0 ]"
t "hospitable api ok"                  "printf '%s' \"\$out\" | grep -q '✅ Hospitable API'"
t "hospitable official shows live-check glyph" "printf '%s' \"\$out\" | grep -q '🔎 Hospitable MCP (official).*add it under + > Connectors'"
t "pricelabs keyfail"                  "printf '%s' \"\$out\" | grep -q '⚠️ PriceLabs API .*key fails'"
t "hint names the real connector file" "printf '%s' \"\$out\" | grep -q 'PriceLabs API .*connectors/pricing-pricelabs.md'"
t "no hint points at a file that does not exist" "for f in \$(printf '%s' \"\$out\" | grep -o 'connectors/[a-z0-9-]*\\.md' | sort -u); do [ -f \"\$f\" ] || exit 1; done"
t "meta shows live-check glyph"        "printf '%s' \"\$out\" | grep -q '🔎 Meta Ads MCP.*add it under + > Connectors'"
t "rankbreeze ok"                      "printf '%s' \"\$out\" | grep -q '✅ RankBreeze MCP'"
t "intellihost not used"               "printf '%s' \"\$out\" | grep -q '➖ IntelliHost MCP'"
t "turno not used"                     "printf '%s' \"\$out\" | grep -q '➖ Turno API'"
t "hostaway not shown"                 "! printf '%s' \"\$out\" | grep -q Hostaway"
t "gemini ok (env-only row)"           "printf '%s' \"\$out\" | grep -q '✅ Gemini API key'"
t "summary line present"               "printf '%s' \"\$out\" | grep -qE '^Summary: [0-9]+ connected, [0-9]+ missing, [0-9]+ pending vendor, [0-9]+ not used, [0-9]+ need restart, [0-9]+ need live check'"
t "no secret in output"                "! printf '%s' \"\$out\" | grep -qE 'rb_mcp_|FIXTURESECRET|GEMKEY|abcdefghijklmnopqrst'"
t "no URL in output"                   "! printf '%s' \"\$out\" | grep -q 'https://'"
# unanswered stack: rows show as missing with the ask hint
cp tests/fixtures/env-hospitable-full.env .env; sed -i.bak 's/^STACK_PMS=.*/STACK_PMS=/' .env
out2="$(bash check-connections.sh)"
t "blank STACK_PMS prompts"            "printf '%s' \"\$out2\" | grep -q '❌ PMS .*which PMS'"
# pending vendor persists
mkdir -p .cache; echo "turno|2026-09-22" > .cache/pending-vendor; sed -i.bak 's/^STACK_OPS=.*/STACK_OPS=turno/' .env
out3="$(bash check-connections.sh)"
t "pending vendor row"                 "printf '%s' \"\$out3\" | grep -q '⏳ Turno API .*emailed 2026-09-22'"

# --- no claude binary anywhere (desktop-app-only case): mcp_load reads ~/.claude.json ---
# A PATH with a curl stub but no claude anywhere, and a HOME whose ~/.claude.json already
# has entries, is exactly the attendee's environment: Claude Code itself is running (that's
# how this script got invoked), but there is no `claude` CLI to shell out to.
cp tests/fixtures/env-hospitable-full.env .env; rm -f .env.bak
rm -rf .cache
NOBIN_HOME="$(mktemp -d)"
cat > "$NOBIN_HOME/.claude.json" <<'JSON'
{"mcpServers":{"hospitable":{"type":"stdio","command":"node","args":["x"]},"meta-ads":{"type":"http","url":"https://mcp.facebook.com/ads"}}}
JSON
NOBIN_STUBS="$(mktemp -d)"
cp tests/stubs/curl "$NOBIN_STUBS/curl"; chmod +x "$NOBIN_STUBS/curl"
out4="$(HOME="$NOBIN_HOME" PATH="$NOBIN_STUBS:/usr/bin:/bin" CURL_STUB_DIR="$PWD/tests/fixtures/curl" bash check-connections.sh)"; rc4=$?
t "no-binary: exits 0"                 "[ $rc4 -eq 0 ]"
t "no-binary: meta-ads shows live-check glyph" "printf '%s' \"\$out4\" | grep -q '🔎 Meta Ads MCP.*add it under + > Connectors; Claude checks it live'"
t "no-binary: keyed row with a passing probe is ok" "printf '%s' \"\$out4\" | grep -q '✅ Hospitable API'"
rm -rf "$NOBIN_HOME" "$NOBIN_STUBS"

exit $fail
