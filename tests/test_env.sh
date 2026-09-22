#!/usr/bin/env bash
set -u; cd "$(dirname "$0")/.."
. lib/env.sh
fail=0; t(){ if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
tmp=$(mktemp -d)
printf 'A_KEY=secretvalue\nB_KEY=\n# comment\nC_KEY="quoted"\n' > "$tmp/.env"
t "missing file returns 1"   "! env_load $tmp/nope"
t "load returns 0"           "env_load $tmp/.env"
t "filled true"              "env_filled A_KEY"
t "blank false"              "! env_filled B_KEY"
t "unset false"              "! env_filled ZZZ"
t "quoted value stripped"    "[ \"\$C_KEY\" = quoted ]"
t "load prints nothing"      "[ -z \"\$(env_load $tmp/.env 2>&1)\" ]"
t "filled prints nothing"    "[ -z \"\$(env_filled A_KEY 2>&1)\" ]"
exit $fail
