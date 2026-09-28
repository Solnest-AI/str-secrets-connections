#!/usr/bin/env bash
# When did the Claude Code app we are running inside actually start?
#
# The scoreboard needs this to tell a real restart from a promised one. A registered server
# only loads when the app is quit and reopened, and an attendee's "ok, restarted" is not proof
# (2026-09-28 report: Turno and RankBreeze went green on the board while the app had never
# restarted). So lib/mcp_register.py stamps .cache/needs-restart with the time of the
# register, and lib/matrix.sh compares that stamp with the app's start time from here.
#
# app_boot_epoch: prints the Unix time the top-most Claude process above this shell started
# (the desktop app itself, or a `claude` CLI in a terminal), or nothing when no such process
# exists. SSC_APP_BOOT_EPOCH overrides it (tests). Computed once per run.
APP_BOOT_CACHE=""
APP_BOOT_DONE=""
APP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

app_boot_epoch() {
  case "${SSC_APP_BOOT_EPOCH:-}" in
    "")   ;;
    none) return 0 ;;                                   # tests: "no app process in sight"
    *)    printf '%s\n' "$SSC_APP_BOOT_EPOCH"; return 0 ;;
  esac
  if [ -z "$APP_BOOT_DONE" ]; then
    case "$(uname -s)" in
      MINGW*|MSYS*|CYGWIN*) APP_BOOT_CACHE="$(_app_boot_windows)" ;;
      *)                    APP_BOOT_CACHE="$(_app_boot_posix)" ;;
    esac
    APP_BOOT_DONE=1
  fi
  [ -n "$APP_BOOT_CACHE" ] && printf '%s\n' "$APP_BOOT_CACHE"
  return 0
}

# Where the walk starts. CLAUDE_PID is the session's own claude process, set in the Bash tool's
# environment by Claude Code; its parent is the app. Without it (a plain terminal) the walk starts
# at this shell, which on Windows only reaches the app from a top-level shell.
_app_start_pid() { case "${CLAUDE_PID:-}" in ''|*[!0-9]*) printf '0\n' ;; *) printf '%s\n' "$CLAUDE_PID" ;; esac; }

# Windows: lib/app-boot.ps1 does the walk with CIM and prints the start time of the top-most
# process named claude*. A -File script, not -Command: the inline form printed nothing when
# called from inside a function (2026-09-28).
_app_boot_windows() {
  command -v powershell.exe >/dev/null 2>&1 || return 0
  [ -f "$APP_LIB_DIR/app-boot.ps1" ] || return 0
  powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$(cygpath -w "$APP_LIB_DIR/app-boot.ps1")" -StartPid "$(_app_start_pid)" 2>/dev/null \
    | tr -d '\r' | grep -oE '[0-9]{9,11}' | head -1
}

# Mac/Linux: same walk with ps. The start time comes from etime ([[dd-]hh:]mm:ss) subtracted
# from now, which needs no date parsing and works with both BSD and GNU ps.
_app_boot_posix() {
  local pid top="" n=0 comm ppid
  pid="$(_app_start_pid)"; [ "$pid" = 0 ] && pid=$$
  while [ -n "$pid" ] && [ "$pid" -gt 1 ] 2>/dev/null && [ $n -lt 20 ]; do
    n=$((n+1))
    comm="$(ps -o comm= -p "$pid" 2>/dev/null)"
    ppid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')"
    case "$(printf '%s' "$comm" | tr 'A-Z' 'a-z')" in *claude*) top="$pid" ;; esac
    [ -z "$ppid" ] || [ "$ppid" = "$pid" ] && break
    pid="$ppid"
  done
  [ -n "$top" ] || return 0
  local et d=0 h=0 m=0 s=0 rest
  et="$(ps -o etime= -p "$top" 2>/dev/null | tr -d ' ')"
  [ -n "$et" ] || return 0
  rest="$et"
  case "$rest" in *-*) d="${rest%%-*}"; rest="${rest#*-}" ;; esac
  set -- $(printf '%s' "$rest" | tr ':' ' ')
  case $# in 3) h="$1"; m="$2"; s="$3" ;; 2) m="$1"; s="$2" ;; 1) s="$1" ;; *) return 0 ;; esac
  d=$((10#$d)); h=$((10#$h)); m=$((10#$m)); s=$((10#$s))
  echo $(( $(date +%s) - (d*86400 + h*3600 + m*60 + s) ))
}
