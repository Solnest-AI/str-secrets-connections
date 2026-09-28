#!/usr/bin/env bash
# Parse the live MCP server list into name|status|kind. Never keeps or prints the command/URL column.
# The attendee runs everything inside the Claude Code desktop app and may never have the
# `claude` CLI on PATH (it is not guaranteed there; the app bundles its own binary). So this
# resolves a binary if one exists and uses it, and otherwise reads registrations straight out
# of ~/.claude.json (every server there gets the status "registered").
# kind is stdio or http (sse counts as http): the URL rows of the scoreboard use it to notice an
# older stdio server squatting on a name like `rankbreeze` (2026-09-28 report).
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
# directly and print "name|registered|kind" per entry. Python-only (stdlib). uv goes first: on
# a stock Windows install the `python3` and `python` on PATH are Microsoft Store stubs that
# print an install prompt and exit 9009, which would read here as "nothing registered".
# UV_PYTHON_DOWNLOADS=never keeps that call from downloading an interpreter of its own.
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
    for name, entry in servers.items():
        kind = "stdio"
        if isinstance(entry, dict):
            t = entry.get("type")
            if t in ("http", "sse") or (not t and entry.get("url")):
                kind = "http"
        print(name + "|registered|" + kind)
'
  local out
  if command -v uv >/dev/null 2>&1; then
    out="$(UV_PYTHON_DOWNLOADS=never uv run --no-project python -c "$py_snippet" "$cfg" 2>/dev/null)" && { printf '%s\n' "$out"; return 0; }
  fi
  if command -v python3 >/dev/null 2>&1; then
    out="$(python3 -c "$py_snippet" "$cfg" 2>/dev/null)" && { printf '%s\n' "$out"; return 0; }
  fi
  if command -v python >/dev/null 2>&1; then
    out="$(python -c "$py_snippet" "$cfg" 2>/dev/null)" && { printf '%s\n' "$out"; return 0; }
  fi
  return 0
}

# mcp_load: run `claude mcp list` once if a binary is available and cache "name|status|kind"
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
        kind="stdio"; if ($2 ~ /^https?:\/\//) kind="http"
        print name "|" st "|" kind
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

# mcp_kind <name>: stdio|http|absent
mcp_kind() {
  local k
  k="$(printf '%s\n' "$MCP_LIST_CACHE" | awk -F'|' -v n="$1" '$1==n {print $3; exit}')"
  [ -n "$k" ] && printf '%s\n' "$k" || printf 'absent\n'
}
