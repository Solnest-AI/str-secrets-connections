#!/usr/bin/env bash
set -u; cd "$(dirname "$0")/.."
. lib/mcp.sh
export CLAUDE_STUB_FIXTURE="$PWD/tests/fixtures/mcp-list-mixed.txt"
fail=0; t(){ if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
mcp_load
t "connected"      "[ \"\$(mcp_status hospitable)\" = connected ]"
t "needs-auth"     "[ \"\$(mcp_status meta-ads)\" = needs-auth ]"
t "failed"         "[ \"\$(mcp_status firecrawl)\" = failed ]"
t "pending"        "[ \"\$(mcp_status shared-server)\" = pending ]"
t "disabled"       "[ \"\$(mcp_status old-thing)\" = disabled ]"
t "absent"         "[ \"\$(mcp_status nothere)\" = absent ]"
t "cache has no URL/secret" "! printf '%s' \"\$MCP_LIST_CACHE\" | grep -q rb_mcp_SECRET"
t "windows glyphs" "printf 'x: cmd - √ Connected\ny: cmd - × Failed to connect\n' > /tmp/w.txt; CLAUDE_STUB_FIXTURE=/tmp/w.txt mcp_load; [ \"\$(mcp_status x)\" = connected ] && [ \"\$(mcp_status y)\" = failed ]"

# --- no claude binary on PATH and no desktop app bundle: read ~/.claude.json directly ---
# A minimal PATH (just the OS dirs) has no `claude` and no `uv`, only the system python3,
# which is exactly the desktop-app case this fallback exists for.
NOBIN_HOME="$(mktemp -d)"
cat > "$NOBIN_HOME/.claude.json" <<'JSON'
{"mcpServers":{"hospitable":{"type":"stdio","command":"node","args":["x"]}}}
JSON
nobin_out="$(HOME="$NOBIN_HOME" PATH="/usr/bin:/bin" bash -c '. lib/mcp.sh; mcp_load; printf "%s|%s" "$(mcp_status hospitable)" "$(mcp_status nothere)"')"
t "no-binary: present name is registered" "[ \"\$nobin_out\" = 'registered|absent' ]"
rm -rf "$NOBIN_HOME"

exit $fail
