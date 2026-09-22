#!/usr/bin/env bash
set -u; cd "$(dirname "$0")/.."
fail=0; t(){ if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
for s in hospitable pricelabs turno airroi kie; do
  t "$s exists"            "[ -d mcp-servers/$s ]"
  t "$s has .env.example"  "[ -f mcp-servers/$s/.env.example ]"
  t "$s has .gitignore"    "grep -q '^\.env$' mcp-servers/$s/.gitignore"
  # These are about what SHIPS, so they ask git, not the working folder. Asking the folder
  # made the suite fail on any machine that had actually run the kit: setup fans a real .env
  # into each server and builds its venv/node_modules, all gitignored and none of it shipped.
  t "$s ships no .env"     "! git ls-files mcp-servers/$s | grep -qE '(^|/)\.env$'"
  t "$s ships no build products" "! git ls-files mcp-servers/$s | grep -qE '(^|/)(node_modules|\.venv|dist)/'"
  t "$s .env.example values blank" "! grep -qE '^[A-Z_]+=.+' mcp-servers/$s/.env.example || grep -qE '^TURNO_ENV=' mcp-servers/$s/.env.example"
done
t "no rankbreeze folder (retired)" "[ ! -d mcp-servers/rankbreeze ]"
t "kie has models.json"     "[ -f mcp-servers/kie/models.json ]"
t "SOURCES.md has hash"     "grep -qE 'commit: [0-9a-f]{7,40}' mcp-servers/SOURCES.md"
t "build files present"     "[ -f build/build-pms-mcp.md ] && [ -f build/build-pricing-ops-mcp.md ]"
t "airroi mcp pinned <2"    "grep -q '^mcp>=1.2,<2$' mcp-servers/airroi/requirements.txt"
t "kie mcp pinned <2"       "grep -q '^mcp\\[cli\\]>=1.2,<2$' mcp-servers/kie/requirements.txt"
# Tracked files only, for the same reason: a filled .env sitting in a server folder after a
# real setup is the attendee's own key, gitignored and never published.
t "no secrets in tracked files" "! git grep -lE '(fc-[A-Za-z0-9]{20,}|pt_[A-Za-z0-9]{20,}|bpat_[A-Za-z0-9]{20,}|rb_mcp_[A-Za-z0-9]{10,}|eyJ[A-Za-z0-9_-]{40,})' -- mcp-servers build connectors 2>/dev/null"
exit $fail
