#!/usr/bin/env bash
# Parse the live MCP server list into name|status. Never keeps or prints the command/URL column.
# The attendee runs everything inside the Claude Code desktop app and may never have the
# `claude` CLI on PATH (it is not guaranteed there; the app bundles its own binary). So this
# resolves a binary if one exists and uses it, and otherwise reads registrations straight out
# of ~/.claude.json (every server there gets the status "registered").
MCP_LIST_CACHE=""

# _mcp_resolve_claude_bin: prints an absolute path to a working `claude` binary, or nothing.
# Order: whatever `claude` resolves to on PATH, then the newest Claude Code desktop app
# binary under ~/Library/Application Support/Claude/claude-code/<ver>/claude.app/... on Mac.
_mcp_resolve_claude_bin() {
  local p
  # SSC_NO_CLAUDE_BIN=1 (tests only): pretend there is no binary anywhere. The suite's
  # "no-binary" cases build a minimal PATH, but on a Mac the python dir they keep is
  # Homebrew's, which also holds the npm-global `claude`, so the fallback never ran.
  [ "${SSC_NO_CLAUDE_BIN:-}" = 1 ] && return 1
  p="$(command -v claude 2>/dev/null)"
  if [ -n "$p" ]; then printf '%s\n' "$p"; return 0; fi
  local dir="$HOME/Library/Application Support/Claude/claude-code"
  if [ -d "$dir" ]; then
    p="$(ls -t "$dir"/*/claude.app/Contents/MacOS/claude 2>/dev/null | head -1)"
    if [ -n "$p" ] && [ -x "$p" ]; then printf '%s\n' "$p"; return 0; fi
  fi
  return 1
}

# _mcp_load_from_config: no claude binary anywhere. Read ~/.claude.json's mcpServers keys
# directly and print "name|registered" per entry. Python-only (stdlib), falls back to
# `uv run python` if python3 is not on PATH either.
_mcp_load_from_config() {
  local cfg="$HOME/.claude.json"
  [ -f "$cfg" ] || return 0
  local py_snippet='
import json, sys
try:
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    sys.exit(0)
servers = data.get("mcpServers") if isinstance(data, dict) else None
if isinstance(servers, dict):
    for name in servers:
        print(name + "|registered")
'
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "$py_snippet" "$cfg" 2>/dev/null
  elif command -v python >/dev/null 2>&1; then
    python -c "$py_snippet" "$cfg" 2>/dev/null
  elif command -v uv >/dev/null 2>&1; then
    uv run python -c "$py_snippet" "$cfg" 2>/dev/null
  fi
}

# mcp_load: run `claude mcp list` once if a binary is available and cache "name|status"
# lines; otherwise fall back to reading ~/.claude.json.
mcp_load() {
  local raw claude_bin
  claude_bin="$(_mcp_resolve_claude_bin)"
  if [ -n "$claude_bin" ]; then
    raw="$("$claude_bin" mcp list 2>/dev/null)" || raw=""
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
  else
    MCP_LIST_CACHE="$(_mcp_load_from_config)"
  fi
}

# mcp_status <name>: connected|needs-auth|failed|pending|disabled|registered|absent
mcp_status() {
  local s
  s="$(printf '%s\n' "$MCP_LIST_CACHE" | awk -F'|' -v n="$1" '$1==n {print $2; exit}')"
  [ -n "$s" ] && printf '%s\n' "$s" || printf 'absent\n'
}
