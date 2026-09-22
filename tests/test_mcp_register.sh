#!/usr/bin/env bash
# lib/mcp_register.py: merges/removes one entry in $HOME/.claude.json without the claude CLI.
set -u; cd "$(dirname "$0")/.."
fail=0; t(){ if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

TMPHOME="$(mktemp -d)"
export HOME="$TMPHOME"
PY="${PYTHON:-python3}"
REG="lib/mcp_register.py"

cat > "$HOME/.claude.json" <<'JSON'
{"numStartups":3,"mcpServers":{"other":{"type":"http","url":"https://x"}}}
JSON

export FAKE_KEY=sentinel123

# --- register a stdio server ---
out_stdio="$("$PY" "$REG" teststdio --stdio node /abs/path/server.js --env FAKE_KEY 2>&1)"
rc_stdio=$?
t "stdio register exits 0"        "[ $rc_stdio -eq 0 ]"
t "stdio register did not echo the secret" "! printf '%s' \"$out_stdio\" | grep -q sentinel123"

t "stdio shape matches" "\"$PY\" -c '
import json
d = json.load(open(\"$HOME/.claude.json\"))
s = d[\"mcpServers\"][\"teststdio\"]
assert s == {\"type\":\"stdio\",\"command\":\"node\",\"args\":[\"/abs/path/server.js\"],\"env\":{\"FAKE_KEY\":\"sentinel123\"}}, s
'"

# --- register an http server ---
out_http="$("$PY" "$REG" testhttp --http https://example.com/mcp --header "Authorization: Bearer FAKE_KEY" 2>&1)"
rc_http=$?
t "http register exits 0"         "[ $rc_http -eq 0 ]"
t "http register did not echo the secret" "! printf '%s' \"$out_http\" | grep -q sentinel123"

t "http shape matches" "\"$PY\" -c '
import json
d = json.load(open(\"$HOME/.claude.json\"))
s = d[\"mcpServers\"][\"testhttp\"]
assert s == {\"type\":\"http\",\"url\":\"https://example.com/mcp\",\"headers\":{\"Authorization\":\"Bearer sentinel123\"}}, s
'"

# --- an http server with no prefix (bare var name in the header value) ---
"$PY" "$REG" testhttp2 --http https://example.com/mcp2 --header "X-API-KEY: FAKE_KEY" >/dev/null 2>&1
t "http no-prefix header has no leading space" "\"$PY\" -c '
import json
d = json.load(open(\"$HOME/.claude.json\"))
assert d[\"mcpServers\"][\"testhttp2\"][\"headers\"][\"X-API-KEY\"] == \"sentinel123\"
'"

# --- other keys and other servers survive untouched ---
t "numStartups survives"          "\"$PY\" -c '
import json
d = json.load(open(\"$HOME/.claude.json\"))
assert d[\"numStartups\"] == 3
'"
t "other server survives"         "\"$PY\" -c '
import json
d = json.load(open(\"$HOME/.claude.json\"))
assert d[\"mcpServers\"][\"other\"] == {\"type\":\"http\",\"url\":\"https://x\"}
'"

# --- file permissions ---
t "config file is chmod 600" "case \"\$(stat -f '%Lp' \"$HOME/.claude.json\" 2>/dev/null || stat -c '%a' \"$HOME/.claude.json\" 2>/dev/null)\" in *600) true;; *) false;; esac"

# --- --list never leaks a secret, only name<TAB>type ---
list_out="$("$PY" "$REG" --list)"
t "--list has no secret"          "! printf '%s' \"$list_out\" | grep -q sentinel123"
t "--list has no url"             "! printf '%s' \"$list_out\" | grep -q 'https://'"
t "--list shows teststdio as stdio" "printf '%s' \"$list_out\" | grep -qx 'teststdio	stdio'"
t "--list shows testhttp as http"   "printf '%s' \"$list_out\" | grep -qx 'testhttp	http'"
t "--list shows other"              "printf '%s' \"$list_out\" | grep -qx 'other	http'"

# --- --remove deletes only the named entry ---
"$PY" "$REG" teststdio --remove >/dev/null 2>&1
t "remove: teststdio gone"        "\"$PY\" -c '
import json
d = json.load(open(\"$HOME/.claude.json\"))
assert \"teststdio\" not in d[\"mcpServers\"]
'"
t "remove: testhttp still there"  "\"$PY\" -c '
import json
d = json.load(open(\"$HOME/.claude.json\"))
assert \"testhttp\" in d[\"mcpServers\"]
'"
t "remove: other still there"     "\"$PY\" -c '
import json
d = json.load(open(\"$HOME/.claude.json\"))
assert \"other\" in d[\"mcpServers\"]
'"

# --- removing something absent is not an error ---
"$PY" "$REG" nothere --remove >/dev/null 2>&1
t "remove absent exits 0"         "[ $? -eq 0 ]"

# --- a blank env var exits 2 and writes nothing ---
export FAKE_KEY=""
"$PY" "$REG" blankstdio --stdio node /abs/path/server.js --env FAKE_KEY >/dev/null 2>&1
rc_blank=$?
t "blank env var exits 2"         "[ $rc_blank -eq 2 ]"
t "blank env var registered nothing" "\"$PY\" -c '
import json
d = json.load(open(\"$HOME/.claude.json\"))
assert \"blankstdio\" not in d[\"mcpServers\"]
'"
unset FAKE_KEY

# --- malformed ~/.claude.json is backed up, not fatal ---
BADHOME="$(mktemp -d)"
echo 'not json at all {' > "$BADHOME/.claude.json"
HOME="$BADHOME" "$PY" "$REG" recoveryserver --http https://example.com/r >/dev/null 2>&1
t "malformed config recovered, server registered" "\"$PY\" -c '
import json
d = json.load(open(\"$BADHOME/.claude.json\"))
assert \"recoveryserver\" in d[\"mcpServers\"]
'"
t "malformed config was backed up, not deleted" "ls \"$BADHOME\"/.claude.json.bak-* >/dev/null 2>&1"

# --- missing ~/.claude.json entirely: create fresh, key included ---
FRESHHOME="$(mktemp -d)"
HOME="$FRESHHOME" "$PY" "$REG" freshserver --http https://example.com/f >/dev/null 2>&1
t "fresh home: config created" "[ -f \"$FRESHHOME/.claude.json\" ]"
t "fresh home: server present" "\"$PY\" -c '
import json
d = json.load(open(\"$FRESHHOME/.claude.json\"))
assert \"freshserver\" in d[\"mcpServers\"]
'"

rm -rf "$TMPHOME" "$BADHOME" "$FRESHHOME"
exit $fail
