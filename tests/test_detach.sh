#!/usr/bin/env bash
# lib/detach_from_github.sh (S2-002): a student's copy of the kit is never linked to Solnest-AI's GitHub,
# and a working copy (edits, branches, commits, stashes, another origin, a worktree) is never touched.
# Real git repos in a temp dir; nothing here touches this checkout's own .git.
set -u; cd "$(dirname "$0")/.."
. tests/_helpers.sh
fail=0; t(){ if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
KIT="$PWD"
root="$(mktemp -d)"
trap 'chmod -R u+w "$root" 2>/dev/null; rm -rf "$root"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
unset STR_KEEP_GIT

# A bare "GitHub" with one commit on main, standing in for the public repo.
seed="$root/seed"; mkdir -p "$seed/lib"
cp "$KIT/lib/detach_from_github.sh" "$seed/lib/" 2>/dev/null || true
printf 'kit\n' > "$seed/CONNECTIONS.md"; printf '.env\n.cache/\n' > "$seed/.gitignore"
git -C "$seed" init -q -b main && git -C "$seed" add -A && git -C "$seed" commit -qm seed
git clone -q --bare "$seed" "$root/github.git"

# copy NAME [ORIGIN_URL]: a clone of the bare repo whose origin then reads as ORIGIN_URL (no network needed:
# the remote-tracking refs from the real clone stay, so "not on GitHub" checks still work).
copy() {
  git clone -q "$root/github.git" "$root/$1"
  git -C "$root/$1" remote set-url origin "${2:-https://github.com/Solnest-AI/str-secrets-connections.git}"
  cp "$KIT/lib/detach_from_github.sh" "$root/$1/lib/" 2>/dev/null || true
}
run() { bash "$root/$1/lib/detach_from_github.sh"; }

t "script exists" "[ -f '$KIT/lib/detach_from_github.sh' ]"

copy fresh; printf 'PRICELABS_API_KEY=x\n' > "$root/fresh/.env"
out="$(run fresh)"; rc=$?
t "fresh clone: exits 0"                     "[ $rc -eq 0 ]"
t "fresh clone: .git removed"                "[ ! -e '$root/fresh/.git' ]"
t "fresh clone: says it is detached"         "printf '%s' \"\$out\" | grep -q 'detached'"
t "fresh clone: says how to update"          "printf '%s' \"\$out\" | grep -q 'Update my connections'"
t "fresh clone: the student's .env survives" "grep -q '^PRICELABS_API_KEY=x$' '$root/fresh/.env'"
t "fresh clone: kit files survive"           "[ -f '$root/fresh/CONNECTIONS.md' ]"

copy ssh git@github.com:solnest-ai/STR-Secrets-Connections
run ssh >/dev/null
t "ssh, mixed-case origin: detached"         "[ ! -e '$root/ssh/.git' ]"

copy other https://github.com/someone-else/str-secrets-connections.git
out="$(run other)"
t "another origin: kept"                     "[ -d '$root/other/.git' ] && printf '%s' \"\$out\" | grep -q 'kept'"

copy edited; printf 'changed\n' >> "$root/edited/CONNECTIONS.md"
run edited >/dev/null
t "edited tracked file: kept"                "[ -d '$root/edited/.git' ]"

copy branch; git -C "$root/branch" branch -q my-work
run branch >/dev/null
t "extra branch: kept"                       "[ -d '$root/branch/.git' ]"

copy commit; printf 'x\n' > "$root/commit/mine.md"; git -C "$root/commit" add mine.md; git -C "$root/commit" commit -qm mine
run commit >/dev/null
t "unpushed commit: kept"                    "[ -d '$root/commit/.git' ]"

copy stash; printf 'y\n' >> "$root/stash/CONNECTIONS.md"; git -C "$root/stash" stash -q
run stash >/dev/null
t "stash: kept"                              "[ -d '$root/stash/.git' ]"

copy optenv; STR_KEEP_GIT=1 run optenv >/dev/null
t "STR_KEEP_GIT=1: kept"                     "[ -d '$root/optenv/.git' ]"

copy optfile; touch "$root/optfile/.git/str-keep-attached"; run optfile >/dev/null
t ".git/str-keep-attached: kept"             "[ -d '$root/optfile/.git' ]"

copy wt; git -C "$root/wt" worktree add -q "$root/wt-linked" -b wt-branch 2>/dev/null
cp "$KIT/lib/detach_from_github.sh" "$root/wt-linked/lib/" 2>/dev/null || true
run wt-linked >/dev/null; rc=$?
t "worktree (.git is a file): kept, exits 0" "[ -f '$root/wt-linked/.git' ] && [ $rc -eq 0 ]"

mkdir -p "$root/plain/lib"; cp "$KIT/lib/detach_from_github.sh" "$root/plain/lib/" 2>/dev/null || true
out="$(run plain)"; rc=$?
t "plain folder (the zip): exits 0, says not attached" "[ $rc -eq 0 ] && printf '%s' \"\$out\" | grep -q 'not attached'"

# Docs: setup runs it before anything reads .git, and nothing tells a student or Claude to clone the kit.
p0="$(awk '/^## Phase 0/,/^## Phase 1/' "$KIT/CONNECTIONS.md")"
t "CONNECTIONS.md Phase 0 runs the detach"   "printf '%s' \"\$p0\" | grep -q 'lib/detach_from_github.sh'"
t "detach runs before the SAFE step"         "[ \"\$(printf '%s\n' \"\$p0\" | grep -n -m1 'detach_from_github' | cut -d: -f1)\" -lt \"\$(printf '%s\n' \"\$p0\" | grep -n -m1 'check-ignore' | cut -d: -f1)\" ]"
t "CONNECTIONS.md: never push the kit"       "grep -qi 'never commit, push' '$KIT/CONNECTIONS.md'"
t "CLAUDE.md: never push the kit"            "grep -qi 'never commit, push' '$KIT/CLAUDE.md'"
t "UPDATE.md runs the detach"                "grep -q 'lib/detach_from_github.sh' '$KIT/UPDATE.md'"
t "README tells Claude not to clone"         "sed 's/\*\*//g' '$KIT/README.md' | grep -qi 'do not .*git clone'"
t "guide paste line no longer says Clone"    "! grep -q 'Clone https://github.com/Solnest-AI/str-secrets-connections' '$KIT/guide/connections-setup-guide.html'"
exit $fail
