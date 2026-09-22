#!/usr/bin/env bash
# Refuse to publish if anything secret-shaped or any .env is tracked.
# mcp-servers/*/README.md are synced upstream server docs (code carve-out), not attendee prose.
set -u; cd "$(dirname "$0")/.."
bad=0
git ls-files | grep -E '(^|/)\.env($|\.)' | grep -v '\.env\.template$' | grep -v '\.env\.example$' && { echo "❌ a .env is tracked"; bad=1; }
git grep -nE '(fc-[A-Za-z0-9]{20,}|pt_[A-Za-z0-9]{20,}|bpat_[A-Za-z0-9]{20,}|rb_mcp_[A-Za-z0-9]{10,}|eyJ[A-Za-z0-9_-]{40,}\.[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9]{20,}|AIza[0-9A-Za-z_-]{30,}|sbp_[a-f0-9]{30,})' -- . ':!tests/fixtures' && { echo "❌ secret-shaped string tracked"; bad=1; }
git ls-files | grep -E 'node_modules/|/dist/|\.venv/|__pycache__/' && { echo "❌ build products tracked"; bad=1; }
grep -rl "—" --include=*.md --include=*.html . 2>/dev/null | grep -v node_modules | grep -v '^./docs' | grep -v '^./.superpowers' | grep -v '^./.claude/worktrees' | grep -v '^./mcp-servers/' && { echo "❌ em-dash in attendee-facing text"; bad=1; }
[ $bad -eq 0 ] && echo "✅ prepublish clean"
exit $bad
