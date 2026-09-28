#!/usr/bin/env bash
# Renders the Connections Setup Guide HTML to a Letter PDF with headless Chrome (Edge works too on Windows).
# Regenerates the cards/directory fragments first so the PDF never goes stale.
set -eu
cd "$(dirname "$0")"

PY=python3; command -v python3 >/dev/null 2>&1 || PY="uv run --no-project --python 3.13 python"
$PY gen-cards.py

CHROME=""
for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
         "/c/Program Files/Google/Chrome/Application/chrome.exe" \
         "/c/Program Files (x86)/Google/Chrome/Application/chrome.exe" \
         "/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" \
         "/c/Program Files/Microsoft/Edge/Application/msedge.exe"; do
  [ -x "$c" ] && CHROME="$c" && break
done
if [ -z "$CHROME" ]; then
  echo "No Chrome or Edge found to render the PDF" >&2
  exit 1
fi

OUT="$PWD/Connections-Setup-Guide.pdf"
IN="$PWD/connections-setup-guide.html"
PROFILE="$(mktemp -d)"   # a throwaway profile, so an already-open browser does not block the render
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) OUT_ARG="$(cygpath -w "$OUT")"; IN_URL="file:///$(cygpath -m "$IN")"; PROFILE_ARG="$(cygpath -w "$PROFILE")" ;;
  *)                    OUT_ARG="$OUT"; IN_URL="file://$IN"; PROFILE_ARG="$PROFILE" ;;
esac

"$CHROME" --headless --disable-gpu --no-pdf-header-footer --user-data-dir="$PROFILE_ARG" --print-to-pdf="$OUT_ARG" "$IN_URL" 2>/dev/null
rm -rf "$PROFILE"

echo "wrote $OUT ($(du -h "$OUT" | cut -f1))"
