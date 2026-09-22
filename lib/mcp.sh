#!/usr/bin/env bash
# Parse `claude mcp list` into name|status. Never keeps or prints the command/URL column.
MCP_LIST_CACHE=""

# mcp_load: run `claude mcp list` once and cache "name|status" lines.
mcp_load() {
  local raw
  raw="$(claude mcp list 2>/dev/null)" || raw=""
  MCP_LIST_CACHE="$(printf '%s\n' "$raw" | awk '
    /^[A-Za-z0-9._-]+: / {
      name=$1; sub(/:$/,"",name)
      st="failed"
      if ($0 ~ /Connected/)              st="connected"
      else if ($0 ~ /Needs authentication/) st="needs-auth"
      else if ($0 ~ /Pending approval/)  st="pending"
      else if ($0 ~ /Disabled/)          st="disabled"
      else if ($0 ~ /Failed/)            st="failed"
      print name "|" st
    }')"
}

# mcp_status <name>: connected|needs-auth|failed|pending|disabled|absent
mcp_status() {
  local s
  s="$(printf '%s\n' "$MCP_LIST_CACHE" | awk -F'|' -v n="$1" '$1==n {print $2; exit}')"
  [ -n "$s" ] && printf '%s\n' "$s" || printf 'absent\n'
}
