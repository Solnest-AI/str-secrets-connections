#!/usr/bin/env bash
# Shared cross-platform helpers for the test suite (macOS + Windows Git Bash).
# Not a test itself: run.sh only executes tests/test_*.sh, so this leading-underscore
# file is sourced, never run on its own.

# is_windows: succeeds on Windows Git Bash / MSYS / Cygwin, fails elsewhere.
is_windows() { case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) return 0 ;; *) return 1 ;; esac; }

# native_path DIR: DIR in the form native tools (including a native Windows Python)
# can open. Windows -> C:/Users/... (forward slashes, safe to embed in JSON). POSIX -> unchanged.
native_path() { if is_windows; then cygpath -m "$1"; else printf '%s\n' "$1"; fi; }

# iso_home DIR: point "home" at DIR for the code under test. On POSIX, HOME is enough.
# On Windows a native Python resolves ~ from USERPROFILE and ignores HOME, so set that
# too, in the native form Python can open. Without this a test's throwaway HOME is
# silently bypassed and the real ~/.claude.json is read and written.
iso_home() {
  export HOME="$1"
  if is_windows; then export USERPROFILE="$(native_path "$1")"; fi
}

# mode_is_600 FILE: true when FILE is chmod 600. POSIX only. Windows/NTFS has no POSIX
# mode bits (the kit chmods best-effort with `|| true`), so treat it as satisfied there
# rather than asserting a number the platform cannot produce.
mode_is_600() {
  is_windows && return 0
  case "$(stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1" 2>/dev/null)" in
    600) return 0 ;;
    *) return 1 ;;
  esac
}

# python_dir: directory holding a real python3 (or python). Tests that build a
# restricted PATH to simulate "no claude CLI" still need an interpreter to read
# ~/.claude.json; Git Bash's /usr/bin has no python, so inject this dir explicitly.
python_dir() {
  local p
  p="$(command -v python3 2>/dev/null || command -v python 2>/dev/null || true)"
  [ -n "$p" ] && dirname "$p"
}
