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
t "guide version matches VERSION" "[ \"\$(grep -oE 'Version [0-9]+\.[0-9]+\.[0-9]+' '$HTML' | sort -u)\" = \"Version \$(tr -d ' \r\n' < VERSION)\" ]"
t "download link present once" "[ \"\$(grep -o 'releases/latest/download/str-secrets-connections\.zip' '$HTML' | wc -l | tr -d ' ')\" = 1 ]"

# --- cards keep every step and every branch heading (S2-012) ---
# Counted straight from connectors/*.md, not through gen-cards.py, so a generator bug cannot hide itself.
python3 - "$CARDS" > /tmp/card-steps.out 2>&1 <<'PY'
import html, re, sys
from pathlib import Path
cards = Path(sys.argv[1]).read_text(encoding="utf-8")
bad = 0
for f in sorted(Path("connectors").glob("*.md")):
    if f.name == "_template.md" or f.name.startswith("system-"):
        continue
    text = f.read_text(encoding="utf-8")
    vendor = re.search(r"^#\s+([^:\n]+)", text, re.M).group(1).strip()
    def scope(n):
        m = re.search(rf"^##\s+{n}\.\s.*?$(.*?)(?=^##\s+\d+\.|\Z)", text, re.M | re.S)
        s = m.group(1) if m else ""
        i = s.find("**SAFE:**")
        return s[:i] if i != -1 else s
    sec = scope(3)
    if sec.strip().startswith("_None"):          # sign-in only (Meta, IntelliHost): the steps live in section 4
        sec = scope(4)
    want = len(re.findall(r"^\s*\d+\.\s+\S", sec, re.M))   # 0 = steps quoted inline; not counted here
    card = re.search(r"<h3>" + re.escape(html.escape(vendor)) + r"</h3>.*?</article>", cards, re.S)
    got = card.group(0).count("<li>") if card else -1
    if want and got != want:
        print(f"  {f.name}: {want} numbered steps in the connector, {got} on the card")
        bad = 1
sys.exit(bad)
PY
t "every numbered step in a connector reaches its card" "cat /tmp/card-steps.out; [ ! -s /tmp/card-steps.out ]"
GEM="$(awk '/<h3>Gemini<\/h3>/,/<\/article>/' "$CARDS")"
t "gemini card: 'New to Google AI Studio?' heading kept" "printf '%s' \"\$GEM\" | grep -q 'New to Google AI Studio?'"
t "gemini card: 'Already have a Google Cloud account?' heading kept" "printf '%s' \"\$GEM\" | grep -q 'Already have a Google Cloud account?'"
gem_line() { printf '%s\n' "$GEM" | grep -n -m1 -F "$1" | cut -d: -f1; }
t "gemini card: import steps sit under the Google Cloud heading" "h=\$(gem_line 'Already have a Google Cloud account?'); i=\$(gem_line 'Import projects'); [ -n \"\$h\" ] && [ -n \"\$i\" ] && [ \"\$h\" -lt \"\$i\" ]"
t "gemini card: copy-key step present" "printf '%s' \"\$GEM\" | grep -q 'Copy the new auth API key'"
t "gemini card: copy-key step sits under 'Make the key'" "h=\$(gem_line 'Make the key'); i=\$(gem_line 'Copy the new auth API key'); [ -n \"\$h\" ] && [ -n \"\$i\" ] && [ \"\$h\" -lt \"\$i\" ]"

# --- PDF ---
t "pdf exists" "[ -f '$PDF' ]"
t "pdf under 5MB" "[ -f '$PDF' ] && [ \$(stat -f%z '$PDF' 2>/dev/null || stat -c%s '$PDF' 2>/dev/null || echo 999999999) -lt 5242880 ]"

exit $fail
