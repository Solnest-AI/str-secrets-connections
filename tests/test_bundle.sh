#!/usr/bin/env bash
set -u; cd "$(dirname "$0")/.."
fail=0; t(){ if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
for s in hospitable pricelabs turno airroi kie; do
  t "$s exists"            "[ -d mcp-servers/$s ]"
  t "$s has .env.example"  "[ -f mcp-servers/$s/.env.example ]"
  t "$s has .gitignore"    "grep -q '^\.env$' mcp-servers/$s/.gitignore"
  t "$s no .env"           "[ ! -f mcp-servers/$s/.env ]"
  t "$s no node_modules/.venv/dist" "[ ! -d mcp-servers/$s/node_modules ] && [ ! -d mcp-servers/$s/.venv ] && [ ! -d mcp-servers/$s/dist ]"
  t "$s .env.example values blank" "! grep -qE '^[A-Z_]+=.+' mcp-servers/$s/.env.example || grep -qE '^TURNO_ENV=' mcp-servers/$s/.env.example"
done
t "no rankbreeze folder (retired)" "[ ! -d mcp-servers/rankbreeze ]"
t "kie has models.json"     "[ -f mcp-servers/kie/models.json ]"
t "SOURCES.md has hash"     "grep -qE 'commit: [0-9a-f]{7,40}' mcp-servers/SOURCES.md"
t "build files present"     "[ -f build/build-pms-mcp.md ] && [ -f build/build-pricing-ops-mcp.md ]"
t "airroi mcp pinned <2"    "grep -q '^mcp>=1.2,<2$' mcp-servers/airroi/requirements.txt"
t "kie mcp pinned <2"       "grep -q '^mcp\\[cli\\]>=1.2,<2$' mcp-servers/kie/requirements.txt"
t "no secrets anywhere"     "! grep -rEl '(fc-[A-Za-z0-9]{20,}|pt_[A-Za-z0-9]{20,}|bpat_[A-Za-z0-9]{20,}|rb_mcp_[A-Za-z0-9]{10,}|eyJ[A-Za-z0-9_-]{40,})' mcp-servers build connectors 2>/dev/null"
exit $fail
