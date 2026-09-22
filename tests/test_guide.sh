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

# --- every connector with a real official_mcp URL shows up in the directory table; bundled ones stay out ---
missing_urls=0
for url in $(grep -h '^official_mcp:[[:space:]]*http' connectors/*.md | grep -v 'reference only' | awk '{print $2}' | sort -u); do
  if ! grep -qF "$(printf '%s' "$url" | sed 's/</\&lt;/g; s/>/\&gt;/g')" "$DIRECTORY"; then
    echo "  missing directory row for url: $url"
    missing_urls=$((missing_urls + 1))
  fi
done
t "every official_mcp URL appears in the directory table" "[ $missing_urls -eq 0 ]"
t "sign-in servers say the attendee adds them" "[ \"\$(grep -c 'You add it' '$DIRECTORY')\" = 7 ]"
t "directory table has no bundled or npm rows" "! grep -qE 'Bundled|@supabase|@guestyorg' '$DIRECTORY'"

# --- attendee-facing hygiene ---
t "no em-dash"                 "! grep -q '—' '$HTML'"
t "no claude mcp add"          "! grep -q 'claude mcp add' '$HTML'"
t "no shell prompt text"       "! grep -q '\\$ ' '$HTML'"
t "download link present once" "[ \"\$(grep -o 'releases/download/v[0-9.]*/str-secrets-connections-v[0-9.]*\.zip' '$HTML' | wc -l | tr -d ' ')\" = 1 ]"

# --- PDF ---
t "pdf exists" "[ -f '$PDF' ]"
t "pdf under 5MB" "[ -f '$PDF' ] && [ \$(stat -f%z '$PDF' 2>/dev/null || stat -c%s '$PDF' 2>/dev/null || echo 999999999) -lt 5242880 ]"

exit $fail
