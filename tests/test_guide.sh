#!/usr/bin/env bash
# Tests for the Connections Setup Guide (guide/). Auto-picked up by tests/run.sh.
set -u
cd "$(dirname "$0")/.."

fail=0
t() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

GUIDE_DIR="guide"
HTML="$GUIDE_DIR/connections-setup-guide.html"
CARDS="$GUIDE_DIR/_cards.html"
DIRECTORY="$GUIDE_DIR/_mcp-directory.html"
PDF="$GUIDE_DIR/Connections-Setup-Guide.pdf"

t "html exists" "[ -f '$HTML' ]"

# --- gen-cards.py runs cleanly and produces both fragments ---
t "gen-cards.py runs" "(cd '$GUIDE_DIR' && python3 gen-cards.py) >/tmp/gen-cards.out 2>&1"
t "cards fragment written" "[ -s '$CARDS' ]"
t "directory fragment written" "[ -s '$DIRECTORY' ]"

# --- every vendor connector produced a card ---
missing_cards=0
for f in connectors/*.md; do
  base="$(basename "$f")"
  [ "$base" = "_template.md" ] && continue
  case "$base" in system-*) continue ;; esac
  vendor="$(sed -n 's/^#[[:space:]]*\([^:]*\):.*/\1/p' "$f" | head -1)"
  [ -z "$vendor" ] && vendor="$(sed -n 's/^#[[:space:]]*//p' "$f" | head -1)"
  if ! grep -qF "<h3>$vendor</h3>" "$CARDS"; then
    echo "  missing card for: $base ($vendor)"
    missing_cards=$((missing_cards + 1))
  fi
done
t "every connector has a card" "[ $missing_cards -eq 0 ]"

# --- every registered server name shows up in the MCP directory table ---
missing_servers=0
for f in connectors/*.md; do
  base="$(basename "$f")"
  [ "$base" = "_template.md" ] && continue
  case "$base" in system-*) continue ;; esac
  server="$(sed -n 's/^server:[[:space:]]*//p' "$f" | head -1)"
  [ -z "$server" ] && continue
  [ "$server" = "none" ] && continue
  if ! grep -qF "<code>$server</code>" "$DIRECTORY"; then
    echo "  missing directory row for server: $server ($base)"
    missing_servers=$((missing_servers + 1))
  fi
done
t "every server name appears in the directory table" "[ $missing_servers -eq 0 ]"

# --- attendee-facing hygiene ---
t "no em-dash"                 "! grep -q '—' '$HTML'"
t "no claude mcp add"          "! grep -q 'claude mcp add' '$HTML'"
t "no shell prompt text"       "! grep -q '\\$ ' '$HTML'"
t "DOWNLOAD_URL_PLACEHOLDER once" "[ \"\$(grep -o 'DOWNLOAD_URL_PLACEHOLDER' '$HTML' | wc -l | tr -d ' ')\" = '1' ]"

# --- PDF ---
t "pdf exists" "[ -f '$PDF' ]"
t "pdf under 5MB" "[ -f '$PDF' ] && [ \$(stat -f%z '$PDF' 2>/dev/null || stat -c%s '$PDF' 2>/dev/null || echo 999999999) -lt 5242880 ]"

exit $fail
