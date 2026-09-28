#!/usr/bin/env bash
# Fan the root .env out to every connector and skill folder that declares its own .env.example.
# MERGE, never overwrite: only declared keys, only non-blank root values, no existing line removed.
# Only the folders in THIS attendee's stack get one: the chosen PMS, pricing and ops servers plus
# the two everyone uses (airroi, kie). A Hostfully shop never gets a hospitable/.env (2026-09-28
# report). A .env with no STACK_* answers yet (an older kit's file) still fans out to every folder.
set -u
cd "$(dirname "$0")"
. lib/env.sh
env_load ./.env || { echo "❌ No .env here. Claude builds it from your four answers (CONNECTIONS.md Phase 1, lib/env_make.py)."; exit 1; }
: "${TURNO_ENV:=production}"; export TURNO_ENV
case "${STACK_PMS:-hospitable}" in hospitable) export HOSPITABLE_TOKEN="${HOSPITABLE_API_KEY:-}" ;; esac   # alias for the Listing Optimizer
MCP_SERVERS_DIR="${MCP_SERVERS_DIR:-$PWD/mcp-servers}"

# in_stack NAME: is this server folder part of the attendee's stack?
STACK_ALL=""
if [ -z "${STACK_PMS:-}${STACK_PRICING:-}${STACK_RANKING:-}${STACK_OPS:-}" ]; then STACK_ALL=1; fi
in_stack() {
  [ -n "$STACK_ALL" ] && return 0
  case "$1" in
    airroi|kie) return 0 ;;
    "${STACK_PMS:-none}"|"${STACK_PRICING:-none}"|"${STACK_RANKING:-none}"|"${STACK_OPS:-none}") return 0 ;;
  esac
  return 1
}

merge_env() {  # merge_env <dir>
  local dir="$1" ex="$1/.env.example" tgt="$1/.env" tmp key val names line
  [ -f "$ex" ] || return 1
  [ -f "$tgt" ] || cp "$ex" "$tgt"
  names=$(grep -oE '^[A-Za-z_][A-Za-z0-9_]*=' "$ex" | tr -d '=')
  tmp=$(mktemp) || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    key=""; case "$line" in [A-Za-z_]*=*) key="${line%%=*}" ;; esac
    if [ -n "$key" ] && printf '%s\n' "$names" | grep -qx -- "$key"; then
      eval "val=\"\${$key:-}\""
      if [ -n "$val" ]; then printf '%s=%s\n' "$key" "$val" >> "$tmp"; continue; fi
    fi
    printf '%s\n' "$line" >> "$tmp"
  done < "$tgt"
  while IFS= read -r key; do
    [ -n "$key" ] || continue; grep -qE "^${key}=" "$tmp" && continue
    eval "val=\"\${$key:-}\""; [ -n "$val" ] && printf '%s=%s\n' "$key" "$val" >> "$tmp"
  done <<< "$names"
  mv "$tmp" "$tgt"; chmod 600 "$tgt" 2>/dev/null || true
  # RankBreeze cookie server is retired: never write RANKBREEZE_SESSION anywhere.
}

echo "Fanning keys out (values are never printed)..."
skipped=""
for d in "$MCP_SERVERS_DIR"/*/; do
  [ -d "$d" ] || continue
  name="$(basename "$d")"
  if ! in_stack "$name"; then [ -f "$d/.env.example" ] && skipped="$skipped $name"; continue; fi
  if merge_env "${d%/}"; then echo "  ✅ $name"; fi
done
[ -n "$skipped" ] && echo "  ➖ not in your stack, left alone:$skipped"
for v in SKILL_PATH_REVENUE_MANAGER SKILL_PATH_LISTING_OPTIMIZER SKILL_PATH_COMPING_AGENT; do
  eval "p=\"\${$v:-}\""
  [ -n "$p" ] && [ -d "$p" ] || continue
  if merge_env "$p"; then echo "  ✅ $(basename "$p") (skill)"; fi
  # revenue manager keeps its own per-connector .envs too
  [ -d "$p/mcp-servers" ] && for d in "$p"/mcp-servers/*/; do merge_env "${d%/}" && echo "  ✅ $(basename "$p")/mcp-servers/$(basename "$d")"; done
done
echo "Done. Restart Claude Code fully so the connectors pick up their keys."
