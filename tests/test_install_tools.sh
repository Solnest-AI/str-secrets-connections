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
  # Only uv's PATH changes in this case; uv's own Python stays where it really is, or the throwaway home
  # hides it, Python reads ❌ and the run exits 1 for a reason this case is not about.
  PYDIR="$("$UVDIR"/uv python dir 2>/dev/null || "$UVDIR"/uv.exe python dir 2>/dev/null)"
  out3="$(HOME="$OFFHOME" USERPROFILE="$OFFHOME" LOCALAPPDATA="$OFFHOME" UV_PYTHON_INSTALL_DIR="$PYDIR" PATH="/usr/bin:/bin" bash install-tools.sh --check 2>&1)"; rc3=$?
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
# Git counts only when `git --version` answers. A Mac's /usr/bin/git is a stub until Apple's command
# line tools are installed: it prints no version and exits 1, and `command -v git` used to pass it
# (2026-09-28). The Git block runs alone with stub git and xcode-select, so nothing is installed.
gitblock() {  # gitblock <git stub body> <WIN> <CHECK> -> the block's lines, BROKEN=..., and XCODE if the installer was asked for
  local d; d="$(mktemp -d)"
  printf '#!/bin/sh\n%s\n' "$1" > "$d/git"; printf '#!/bin/sh\ntouch "%s/xcode"\n' "$d" > "$d/xcode-select"; chmod +x "$d/git" "$d/xcode-select"
  local body; body="$(awk '/^# -+ git --$/{f=1} /^# -+ node --$/{f=0} f' install-tools.sh)"
  PATH="$d:/usr/bin:/bin" bash -c "WIN=$2; CHECK=$3; BROKEN=0; ok(){ echo \"OK \$1\"; }; bad(){ echo \"BAD \$1\"; BROKEN=1; }; warn(){ echo \"WARN \$1\"; }; $body
echo BROKEN=\$BROKEN"
  [ -e "$d/xcode" ] && echo XCODE; rm -rf "$d"
}
APPLE='echo "xcrun: error: invalid active developer path (/Library/Developer/CommandLineTools)" >&2; exit 1'
g1="$(gitblock 'echo "git version 2.50.1"' 0 0)"
t "Git: a working git passes with its version"            "printf '%s' \"\$g1\" | grep -q '^OK Git 2.50.1' && ! printf '%s' \"\$g1\" | grep -q XCODE"
g2="$(gitblock "$APPLE" 0 0)"
t "Git: Apple's stub on a Mac is not a pass"              "! printf '%s' \"\$g2\" | grep -q '^OK Git'"
t "Git: Apple's stub warns, opens the installer, no stop" "printf '%s' \"\$g2\" | grep -q '^WARN Git' && printf '%s' \"\$g2\" | grep -q XCODE && printf '%s' \"\$g2\" | grep -q BROKEN=0"
g3="$(gitblock "$APPLE" 0 1)"
t "Git: --check never opens Apple's installer"            "printf '%s' \"\$g3\" | grep -q '^WARN Git' && ! printf '%s' \"\$g3\" | grep -q XCODE"
g4="$(gitblock 'exit 127' 1 0)"
t "Git: Windows with no git still stops"                   "printf '%s' \"\$g4\" | grep -q '^BAD Git' && printf '%s' \"\$g4\" | grep -q BROKEN=1"
t "winget names its source and says why it failed"        "grep -q 'winget install --id OpenJS.NodeJS.LTS -e --source winget' install-tools.sh && grep -q 'winget said:' install-tools.sh"
exit $fail
