#!/usr/bin/env bash
# Lints CONNECTIONS.md, the conductor doc Claude follows end to end.
set -u; cd "$(dirname "$0")/.."
fail=0
F=CONNECTIONS.md

[ -f "$F" ] || { echo "FAIL $F does not exist"; exit 1; }

# --- frontmatter ---
head -1 "$F" | grep -q '^---$' || { echo "FAIL $F no frontmatter"; fail=1; }
grep -qE '^name: str-secrets-connections$' "$F" || { echo "FAIL $F frontmatter missing 'name: str-secrets-connections'"; fail=1; }

DESC_LINE="$(grep -E '^description:' "$F" | head -1)"
if [ -z "$DESC_LINE" ]; then
  echo "FAIL $F frontmatter missing 'description:'"; fail=1
else
  for phrase in "Set up my connections" "Check my connections" "Update my connections"; do
    printf '%s' "$DESC_LINE" | grep -qF "$phrase" || { echo "FAIL $F description missing phrase: $phrase"; fail=1; }
  done
fi

# --- every real connector file gets referenced by name somewhere in the body ---
for c in connectors/*.md; do
  b="$(basename "$c")"
  [ "$b" = "_template.md" ] && continue
  grep -qF "$b" "$F" || { echo "FAIL $F never references connectors/$b"; fail=1; }
done

# --- no em-dash anywhere ---
grep -q "—" "$F" && { echo "FAIL $F contains an em-dash"; fail=1; }

# --- required literal strings ---
for lit in "check-connections.sh" "fan-out-env.sh" ".cache/needs-restart" "NEVER ask for an API key"; do
  grep -qF "$lit" "$F" || { echo "FAIL $F missing literal string: $lit"; fail=1; }
done

# --- must explicitly forbid `claude mcp get` ---
grep -iE 'never[^.]*claude mcp get' "$F" >/dev/null || grep -iE 'claude mcp get[^.]*never' "$F" >/dev/null \
  || { echo "FAIL $F missing a sentence forbidding 'claude mcp get'"; fail=1; }

# --- must never itself instruct running `claude mcp list` (desktop-app pivot: use mcp_register.py --list) ---
grep -qE 'claude mcp list' "$F" && { echo "FAIL $F still tells Claude to run 'claude mcp list' (pivot uses mcp_register.py --list)"; fail=1; }

# --- length target: 250-350 lines ---
lines=$(wc -l < "$F" | tr -d ' ')
if [ "$lines" -lt 250 ] || [ "$lines" -gt 350 ]; then
  echo "FAIL $F is $lines lines, want 250-350"; fail=1
fi

[ $fail -eq 0 ] && echo "ok   CONNECTIONS.md lint clean ($lines lines)"
exit $fail
