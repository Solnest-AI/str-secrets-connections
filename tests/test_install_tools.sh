#!/usr/bin/env bash
# install-tools.sh: the in-app installer for uv, Python 3.13 and Node. --check must report and never install.
set -u; cd "$(dirname "$0")/.."
. tests/_helpers.sh
fail=0; t(){ if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
t "install-tools.sh parses"                 "bash -n install-tools.sh"
t "install-tools.sh has no em-dash"         "! grep -q '—' install-tools.sh"
# python/python3 must never start a command (uv's `python install` and `... --python 3.13 python -c` are fine)
t "install-tools.sh never calls python3"    "! grep -qE '(^[[:space:]]*|[;&|][[:space:]]*)python3? ' install-tools.sh"
out="$(bash install-tools.sh --check 2>&1)"; rc=$?
t "--check reports Git, Node.js, uv and Python" "printf '%s' \"\$out\" | grep -q 'Git' && printf '%s' \"\$out\" | grep -q 'Node.js' && printf '%s' \"\$out\" | grep -q ' uv' && printf '%s' \"\$out\" | grep -q 'Python'"
t "--check exits 0, 1 or 3"                 "[ $rc -eq 0 ] || [ $rc -eq 1 ] || [ $rc -eq 3 ]"
t "--check never installs (no 'installing' line)" "! printf '%s' \"\$out\" | grep -q 'installing'"
# a tool that is on disk but not on this shell's PATH (a by-hand winget install mid-session) must ask
# for the app restart, since every later kit command calls it by bare name
UVDIR="$(dirname "$(command -v uv 2>/dev/null || echo /nonexistent/uv)")"
if [ -x "$UVDIR/uv" ] || [ -x "$UVDIR/uv.exe" ]; then
  OFFHOME="$(mktemp -d)"; mkdir -p "$OFFHOME/.local/bin"; cp "$UVDIR"/uv* "$OFFHOME/.local/bin/" 2>/dev/null
  out3="$(HOME="$OFFHOME" USERPROFILE="$OFFHOME" LOCALAPPDATA="$OFFHOME" PATH="/usr/bin:/bin" bash install-tools.sh --check 2>&1)"; rc3=$?
  t "uv on disk but off PATH: reported as installed" "printf '%s' \"\$out3\" | grep -q '✅ uv .*restart needed'"
  t "uv on disk but off PATH: asks for the app restart (exit 3)" "[ $rc3 -eq 3 ] && printf '%s' \"\$out3\" | grep -q 'RESTART NEEDED: installed but not visible'"
  rm -rf "$OFFHOME"
fi
# a machine with nothing on it: every fallback location is empty, --check says ❌ and exits 1
EMPTY="$(mktemp -d)"
out2="$(HOME="$EMPTY" USERPROFILE="$EMPTY" LOCALAPPDATA="$EMPTY" PATH="/usr/bin:/bin" bash install-tools.sh --check 2>&1)"; rc2=$?
t "--check with no uv anywhere: uv ❌"      "printf '%s' \"\$out2\" | grep -q '❌ uv'"
t "--check with no uv anywhere: Python ❌"  "printf '%s' \"\$out2\" | grep -q '❌ Python'"
t "--check with nothing installed exits 1"  "[ $rc2 -eq 1 ]"
t "--check installed nothing into the empty home" "[ ! -e \"$EMPTY/.local\" ] && [ ! -e \"$EMPTY/.uv\" ]"
rm -rf "$EMPTY"
exit $fail
