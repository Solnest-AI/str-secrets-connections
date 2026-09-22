#!/usr/bin/env bash
set -u; cd "$(dirname "$0")/.."
export CURL_STUB_DIR="$PWD/tests/fixtures/curl"
export CLAUDE_STUB_FIXTURE="$PWD/tests/fixtures/mcp-list-hospitable-full.txt"
tmp=$(mktemp -d); cp -R . "$tmp/repo" >/dev/null 2>&1; cd "$tmp/repo"
cp tests/fixtures/env-leaky.env .env
out="$(bash check-connections.sh 2>&1; bash fan-out-env.sh 2>&1 || true)"
if printf '%s' "$out" | grep -q 'LEAK_'; then echo "FAIL secret sentinel appeared in output:"; printf '%s' "$out" | grep 'LEAK_'; exit 1; fi
if printf '%s' "$out" | grep -qE 'rb_mcp_|https?://'; then echo "FAIL URL leaked"; exit 1; fi
echo "ok   no secrets or URLs in checker/fan-out output"
