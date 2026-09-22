#!/usr/bin/env bash
set -u; cd "$(dirname "$0")/.."
fail=0
for f in connectors/*.md; do
  [ "$(basename "$f")" = _template.md ] && continue
  for h in "## 1. What it is" "## 2. Required, cost, gate" "## 3. Path A: API key" "## 4. Path B: official MCP" "## 5. Verify" "## 6. Troubleshooting" "## 7. Sources"; do
    grep -qF "$h" "$f" || { echo "FAIL $f missing '$h'"; fail=1; }
  done
  head -1 "$f" | grep -q '^---$' || { echo "FAIL $f no frontmatter"; fail=1; }
  grep -q '^server:' "$f" || { echo "FAIL $f no server:"; fail=1; }
  grep -q "—" "$f" && { echo "FAIL $f contains an em-dash"; fail=1; }
  grep -qE 'claude mcp get' "$f" && { echo "FAIL $f tells Claude to run 'claude mcp get'"; fail=1; }
  grep -qiE 'paste (it|the key|your key) (here|in the chat|into the chat)' "$f" && { echo "FAIL $f asks for a key in chat"; fail=1; }
done
[ $fail -eq 0 ] && echo "ok   connector files lint clean"
exit $fail
