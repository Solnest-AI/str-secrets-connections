#!/usr/bin/env bash
# STR Secrets Connections scoreboard. Safe to print: never shows a key, URL, header, or command.
# Exit 0 = the checker ran (whatever it found). Exit 1 = the checker could not run.
set -u
cd "$(dirname "$0")"
. lib/env.sh; . lib/mcp.sh; . lib/probes.sh 2>/dev/null || true; . lib/matrix.sh 2>/dev/null || true

# No hard gate on a `claude` CLI here: the attendee runs this from inside the Claude Code
# desktop app, where the CLI is not guaranteed to be on PATH. mcp_load() (lib/mcp.sh) uses
# one if it finds one and otherwise reads ~/.claude.json directly, so the scoreboard still
# works either way.
if ! env_load ./.env; then echo "❌ No .env here. Run: cp .env.template .env"; exit 1; fi

# row <label> <state> [hint]; state: ok|missing|auth|keyfail|vendor|na|restart|live
row() {
  local label="$1" state="$2" hint="${3:-}" glyph text
  case "$state" in
    ok)      glyph="✅"; text="connected" ;;
    missing) glyph="❌"; text="missing" ;;
    auth)    glyph="⚠️"; text="registered, not authenticated (/mcp > Authenticate)" ;;
    keyfail) glyph="⚠️"; text="registered, key fails" ;;
    vendor)  glyph="⏳"; text="waiting on vendor" ;;
    na)      glyph="➖"; text="not used" ;;
    restart) glyph="🔒"; text="needs a full restart of Claude Code" ;;
    live)    glyph="🔎"; text="add it under + > Connectors; Claude checks it live" ;;
    *)       glyph="❓"; text="$state" ;;
  esac
  printf '%s %-32s %s' "$glyph" "$label" "$text"
  [ -n "$hint" ] && printf '   → %s' "$hint"
  printf '\n'
  case "$state" in ok|na) ;; *) NOT_OK=$((NOT_OK+1)) ;; esac
}
NOT_OK=0
mcp_load
OUT="$(scoreboard)"
printf '%s\n' "$OUT"
c=$(printf '%s\n' "$OUT" | grep -c '^✅'); m=$(printf '%s\n' "$OUT" | grep -c '^❌')
v=$(printf '%s\n' "$OUT" | grep -c '^⏳'); n=$(printf '%s\n' "$OUT" | grep -c '^➖'); r=$(printf '%s\n' "$OUT" | grep -c '^🔒')
l=$(printf '%s\n' "$OUT" | grep -c '^🔎')
echo; echo "Summary: $c connected, $m missing, $v pending vendor, $n not used, $r need restart, $l need live check"
exit 0
