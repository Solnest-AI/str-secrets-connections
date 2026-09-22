#!/usr/bin/env bash
# Renders the Connections Setup Guide HTML to a Letter PDF with headless Chrome.
# Regenerates the cards/directory fragments first so the PDF never goes stale.
set -eu
cd "$(dirname "$0")"

python3 gen-cards.py

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
if [ ! -x "$CHROME" ]; then
  echo "Google Chrome not found at: $CHROME" >&2
  exit 1
fi

OUT="$PWD/Connections-Setup-Guide.pdf"
IN="$PWD/connections-setup-guide.html"

"$CHROME" --headless --no-pdf-header-footer --print-to-pdf="$OUT" "file://$IN" 2>/dev/null

echo "wrote $OUT ($(du -h "$OUT" | cut -f1))"
