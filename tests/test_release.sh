#!/usr/bin/env bash
# Tests for scripts/release.sh, fully offline: a throwaway kit repo whose "GitHub" is a local bare repo, plus stub
# gh / netlify / curl that keep their state in files, so push, tag, release, deploy and rollback all really run.
# Auto-picked up by tests/run.sh.
set -u; cd "$(dirname "$0")/.."
. tests/_helpers.sh
if is_windows; then echo "ok   release tests skipped on Windows (releases run on the Mac)"; exit 0; fi
fail=0; t(){ if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; sed 's/^/     | /' "$W/out.txt" 2>/dev/null | tail -8; fi; }

KIT="$PWD"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
STATE="$W/state"; BIN="$W/bin"; ORIGIN="$W/origin.git"; R="$W/kit"
SITE_URL="https://kit.example.test"
mkdir -p "$STATE/assets" "$STATE/deploys" "$BIN" "$W/home"

# ---------- stubs ----------
cat > "$BIN/gh" <<'SH'
#!/usr/bin/env bash
echo "gh $*" >> "$STATE/calls.log"
case "$1 $2" in
  "api repos/"*) echo true ;;
  "release view") [ "$(cat "$STATE/release" 2>/dev/null)" = "$3" ] || exit 1
                  python3 -c 'import json,os,sys; print(json.dumps({"tagName":sys.argv[2],"isDraft":False,"assets":[{"name":n} for n in sorted(os.listdir(sys.argv[1]))]}))' "$STATE/assets" "$3" ;;
  "release list") cat "$STATE/latest" 2>/dev/null; true ;;
  "release create") tag="$3"; shift 3
                  for a in "$@"; do case "$a" in *.zip) cp "$a" "$STATE/assets/" ;; esac; done
                  echo "$tag" > "$STATE/release"; echo "$tag" > "$STATE/latest" ;;
  "release upload") shift 3; for a in "$@"; do case "$a" in *.zip) cp "$a" "$STATE/assets/" ;; esac; done ;;
  "release edit") echo "$3" > "$STATE/latest" ;;
  "release download") d=""; while [ $# -gt 0 ]; do [ "$1" = -D ] && d="$2"; shift; done; cp "$STATE"/assets/*.zip "$d/" ;;
  *) echo "gh stub: unhandled $*" >&2; exit 2 ;;
esac
SH
cat > "$BIN/netlify" <<'SH'
#!/usr/bin/env bash
echo "netlify $*" >> "$STATE/calls.log"
[ "${NETLIFY_AUTH_TOKEN:-}" = good-token ] || { echo "JSONHTTPError: Unauthorized" >&2; exit 1; }
case "$1 $2" in
  "api getSite") printf '{"name":"kit","published_deploy":{"id":"%s"}}\n' "$(cat "$STATE/deploy_id")" ;;
  "api restoreSiteDeploy") id="$(printf '%s' "$4" | python3 -c 'import json,sys; print(json.load(sys.stdin)["deploy_id"])')"
                  [ -d "$STATE/deploys/$id" ] || exit 1
                  echo "$id" > "$STATE/deploy_id"; rm -rf "$STATE/web"; cp -R "$STATE/deploys/$id" "$STATE/web"; echo '{}' ;;
  "deploy "*) dir=""; while [ $# -gt 0 ]; do [ "$1" = --dir ] && dir="$2"; shift; done
                  id="d$(( $(ls "$STATE/deploys" | wc -l) + 1 ))"
                  cp -R "$dir" "$STATE/deploys/$id"; rm -rf "$STATE/web"; cp -R "$dir" "$STATE/web"; echo "$id" > "$STATE/deploy_id"
                  echo "Deploy path: $dir"; printf '{"deploy_id":"%s","site_name":"kit"}\n' "$id" ;;
  *) echo "netlify stub: unhandled $*" >&2; exit 2 ;;
esac
SH
cat > "$BIN/curl" <<'SH'
#!/usr/bin/env bash
out=""; url=""
while [ $# -gt 0 ]; do case "$1" in -o) out="$2"; shift 2 ;; -H) shift 2 ;; http*) url="$1"; shift ;; *) shift ;; esac; done
echo "curl $url" >> "$STATE/calls.log"
emit() { if [ -n "$out" ]; then cat > "$out"; else cat; fi; }
case "$url" in
  https://github.com/*/releases/latest/download/*) f="$STATE/assets/${url##*/}"; [ -f "$f" ] || exit 22; emit < "$f" ;;
  "$SITE_URL/?"*|"$SITE_URL/")   # the live page, with the two things Netlify really injects (and optional damage)
    python3 - "$STATE/web/index.html" "$STATE/corrupt" <<'PY' | emit
import os, sys
lines = open(sys.argv[1]).read().split("\n")
lines.insert(1, "<!-- This site is hosted on Netlify. Anyone can build\n     like this one: https://netlify.new/\n     Netlify hosting facts. -->")
lines.insert(len(lines) - 1, '<script async src="/.netlify/scripts/hud?variant=public"></script>')
if os.path.exists(sys.argv[2]):
    lines.insert(3, "<p>half a page</p>")
sys.stdout.write("\n".join(lines))
PY
    ;;
  "$SITE_URL/"*) f="$STATE/web/${url#$SITE_URL/}"; [ -f "$f" ] || exit 22; emit < "$f" ;;
  *) exit 6 ;;
esac
SH
chmod +x "$BIN"/*

# ---------- fixture kit repo ----------
git init -q --bare "$ORIGIN"
git init -q -b main "$R"
g() { git -C "$R" "$@"; }
g config user.name t; g config user.email t@example.test; g config commit.gpgsign false; g config tag.gpgsign false
mkdir -p "$R/guide/assets" "$R/scripts" "$R/tests"
cp "$KIT/scripts/release.sh" "$R/scripts/"
printf '#!/usr/bin/env bash\necho "✅ prepublish clean"\n' > "$R/scripts/prepublish.sh"
printf '#!/usr/bin/env bash\necho "ok fake suite"\n' > "$R/tests/run.sh"
printf 'PNG-logo' > "$R/guide/assets/logo.png"; printf 'PNG-fav' > "$R/guide/assets/fav.png"
set_version() {
  echo "$1" > "$R/VERSION"
  printf '# Changelog\n\n## %s (2026-09-26)\n- notes for %s\n\n## 1.0.0 (2026-01-01)\n- first\n' "$1" "$1" > "$R/CHANGELOG.md"
  printf '<html>\n<head><link rel="icon" href="assets/fav.png"></head>\n<body><img src="assets/logo.png"> <a href="https://example.com/x">x</a> <a href="mailto:a@b.test">m</a> <a href="#top">t</a>\n<p class="version">Version %s</p>\n</body>\n</html>\n' "$1" > "$R/guide/connections-setup-guide.html"
  printf 'PDF %s' "$1" > "$R/guide/Connections-Setup-Guide.pdf"
}
commit_at() { g add -A; GIT_AUTHOR_DATE="@$1 +0000" GIT_COMMITTER_DATE="@$1 +0000" g commit -qm "$2"; }
run() {
  ( cd "$R" && iso_home "$W/home" && env PATH="$BIN:$PATH" STATE="$STATE" SITE_URL="$SITE_URL" \
      RELEASE_REPO=test/kit RELEASE_SITE_ID=site-1 RELEASE_SITE_URL="$SITE_URL" NETLIFY_AUTH_TOKEN="${TOKEN:-good-token}" \
      bash scripts/release.sh "$@" ) > "$W/out.txt" 2>&1
}
calls() { grep -c "$1" "$STATE/calls.log" 2>/dev/null || true; }

# v1.0.8 already released and live, exactly as GitHub + Netlify would hold it
set_version 1.0.8; commit_at 1790000000 "release: v1.0.8"
g remote add origin "$ORIGIN"; g push -q origin main
g tag -a v1.0.8 -m v1.0.8; g push -q origin v1.0.8
g archive --format=zip --prefix=str-secrets-connections/ v1.0.8 -o "$STATE/assets/str-secrets-connections-v1.0.8.zip"
echo v1.0.8 > "$STATE/latest"
mkdir -p "$STATE/deploys/d1/assets"; cp "$R/guide/connections-setup-guide.html" "$STATE/deploys/d1/index.html"
cp "$R"/guide/assets/*.png "$STATE/deploys/d1/assets/"; cp -R "$STATE/deploys/d1" "$STATE/web"; echo d1 > "$STATE/deploy_id"

# the next release, committed but not pushed
set_version 1.0.9; commit_at 1790000100 "release: v1.0.9"
GOOD="$(g rev-parse HEAD)"

# ---------- check mode ----------
: > "$STATE/calls.log"
t "check passes on a ready release"              "run"
t "check plans the push, tag and release"        "grep -q '1 new commit' '$W/out.txt' && grep -q 'create v1.0.9' '$W/out.txt' && grep -q 'create v1.0.9 with both zips' '$W/out.txt'"
t "check shows what is live now"                 "grep -q 'live now: Version 1.0.8' '$W/out.txt'"
t "check changes nothing"                        "[ \$(calls 'release create') = 0 ] && [ \$(calls 'netlify deploy') = 0 ] && ! git -C '$ORIGIN' rev-parse -q --verify refs/tags/v1.0.9 >/dev/null && [ \"\$(git -C '$ORIGIN' rev-parse main)\" != '$GOOD' ]"

# ---------- publish ----------
: > "$STATE/calls.log"
t "publish succeeds"                             "run --publish"
t "main pushed to GitHub"                        "[ \"\$(git -C '$ORIGIN' rev-parse main)\" = '$GOOD' ]"
t "tag v1.0.9 on GitHub at the release commit"   "[ \"\$(git -C '$ORIGIN' rev-parse 'v1.0.9^{commit}')\" = '$GOOD' ]"
t "release created once with both zips"          "[ \$(calls 'gh release create v1.0.9') = 1 ] && [ -f '$STATE/assets/str-secrets-connections-v1.0.9.zip' ] && [ -f '$STATE/assets/str-secrets-connections.zip' ]"
t "zips are git archive of the tag"              "g archive --format=zip --prefix=str-secrets-connections/ v1.0.9 | cmp -s - '$STATE/assets/str-secrets-connections.zip'"
t "release notes come from the changelog"        "grep -q 'gh release create v1.0.9 .*--notes-file' '$STATE/calls.log'"
t "live page is the committed guide"             "cmp -s '$STATE/web/index.html' '$R/guide/connections-setup-guide.html'"
t "linked files deployed, nothing else"          "cmp -s '$STATE/web/assets/logo.png' '$R/guide/assets/logo.png' && cmp -s '$STATE/web/assets/fav.png' '$R/guide/assets/fav.png' && [ \$(find '$STATE/web' -type f | wc -l) = 3 ]"
t "deploy is --prod and never builds"            "grep -q 'netlify deploy --prod --no-build --dir site --site site-1' '$STATE/calls.log'"
t "prints the rollback to the previous page"     "grep -q 'rollback d1' '$W/out.txt' && grep -q '✅ v1.0.9 released' '$W/out.txt'"

# ---------- re-run is safe ----------
: > "$STATE/calls.log"
t "publish again succeeds"                       "run --publish"
t "re-run skips push, tag and release"           "grep -q 'already on GitHub, skip' '$W/out.txt' && grep -q 'already at this commit, skip' '$W/out.txt' && [ \$(calls 'release create') = 0 ]"

# ---------- rollback ----------
t "rollback to the old page"                     "run --rollback d1 && [ \"\$(cat '$STATE/deploy_id')\" = d1 ] && grep -q 'Version 1.0.8' '$W/out.txt'"
t "rollback to an unknown deploy fails"          "! run --rollback nope"

# ---------- a site that has never been deployed ----------
: > "$STATE/deploy_id"
t "first deploy says there is nothing to roll back to" "run --publish && grep -q \"site's first deploy\" '$W/out.txt' && ! grep -qE 'rollback *\$' '$W/out.txt'"

# ---------- a damaged live page is caught ----------
touch "$STATE/corrupt"
t "damaged live page fails the publish"          "! run --publish && grep -q 'differs from v1.0.9' '$W/out.txt' && grep -q 'rollback' '$W/out.txt'"
rm -f "$STATE/corrupt"

# ---------- refusals ----------
TOKEN=bad t "no Netlify login that sees the site"   "! run && grep -q 'no Netlify login' '$W/out.txt'"
back() { g checkout -q main; g reset -q --hard "$GOOD"; g clean -qfd; }

sed -i.bak 's/Version 1.0.9/Version 1.0.7/' "$R/guide/connections-setup-guide.html"; rm "$R"/guide/*.bak; commit_at 1790000200 x
t "guide version must match VERSION"            "! run && grep -q 'the guide says' '$W/out.txt'"; back

printf '# Changelog\n\n## 1.0.8 (x)\n- n\n' > "$R/CHANGELOG.md"; commit_at 1790000200 x
t "changelog top entry must match VERSION"      "! run && grep -q 'CHANGELOG.md' '$W/out.txt'"; back

echo dirty >> "$R/VERSION"
t "uncommitted changes refused"                 "! run && grep -q 'uncommitted' '$W/out.txt'"; back

echo '<!-- edit -->' >> "$R/guide/connections-setup-guide.html"; commit_at 1790000300 "guide edit, no pdf"
t "stale PDF refused"                           "! run && grep -q 'PDF is older' '$W/out.txt'"; back

echo more > "$R/NOTES"; commit_at 1790000300 "no version bump"
t "released version not reused"                 "! run && grep -q 'already released' '$W/out.txt'"; back

set_version 1.0.5; commit_at 1790000300 "going backwards"
t "older than the latest release refused"       "! run && grep -q 'not newer' '$W/out.txt'"; back

sed -i.bak 's#assets/logo.png#/assets/logo.png#' "$R/guide/connections-setup-guide.html"; rm "$R"/guide/*.bak
echo 1.0.10 > "$R/VERSION"; sed -i.bak 's/1\.0\.9/1.0.10/g' "$R/CHANGELOG.md" "$R/guide/connections-setup-guide.html"; rm "$R"/*.bak "$R"/guide/*.bak
printf 'PDF' >> "$R/guide/Connections-Setup-Guide.pdf"; commit_at 1790000300 x
t "root-relative link refused"                  "! run && grep -q 'from the site root' '$W/out.txt'"; back

sed -i.bak 's#assets/logo.png#assets/missing.png#' "$R/guide/connections-setup-guide.html"; rm "$R"/guide/*.bak
echo 1.0.10 > "$R/VERSION"; sed -i.bak 's/1\.0\.9/1.0.10/g' "$R/CHANGELOG.md" "$R/guide/connections-setup-guide.html"; rm "$R"/*.bak "$R"/guide/*.bak
printf 'PDF' >> "$R/guide/Connections-Setup-Guide.pdf"; commit_at 1790000300 x
t "link to an uncommitted file refused"         "! run && grep -q 'is not committed' '$W/out.txt'"; back

g checkout -q -b side
t "only releases from main"                     "! run && grep -q \"on branch 'side'\" '$W/out.txt'"; back

exit $fail
