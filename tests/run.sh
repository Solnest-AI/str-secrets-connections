#!/usr/bin/env bash
# Runs every tests/test_*.sh with stubs first on PATH. Exit 1 if any fails.
cd "$(dirname "$0")/.."
export PATH="$PWD/tests/stubs:$PATH"
rc=0
for t in tests/test_*.sh; do
  echo "== $t"; bash "$t" || rc=1
done
exit $rc
