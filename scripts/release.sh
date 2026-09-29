#!/usr/bin/env bash
# One-command kit release: the GitHub release and the guide web page, both built from the same tag.
#
#   scripts/release.sh                 check only. Runs every check, prints what --publish would do, changes nothing.
#   scripts/release.sh --publish       push main, tag vX, GitHub release with both zips, deploy the guide page,
#                                      then prove the download link and the live page both match the tag.
#   scripts/release.sh --rollback ID   put an earlier guide page deploy back live (every publish prints the ID to use).
#
# Before a release: bump VERSION, put "## X (YYYY-MM-DD)" at the top of CHANGELOG.md, set "Version X" in
# guide/connections-setup-guide.html, run guide/build-pdf.sh if the guide changed, and commit it all on main.
# Re-running after a failure is safe: steps already done (pushed, tagged, released) are detected and skipped,
# and the page deploy is atomic on Netlify's side (the live page only switches once the new one is complete).
#
# Publishing needs gh (logged in, push access) and the netlify CLI logged in (netlify login) as the Netlify account
# that owns the guide site. Every stored login is tried, so the CLI's active account never has to be switched. The
# token is read from the CLI's own config, handed only to the netlify commands below, and never printed.
set -euo pipefail

REPO="${RELEASE_REPO:-Solnest-AI/str-secrets-connections}"
SITE_ID="${RELEASE_SITE_ID:-0ee9a93a-e475-4520-be79-96c00d64dac3}"
SITE_URL="${RELEASE_SITE_URL:-https://str-secrets-connections.netlify.app}"
ZIP_NAME="str-secrets-connections"
GUIDE="guide/connections-setup-guide.html"
PDF="guide/Connections-Setup-Guide.pdf"
POLL="${RELEASE_POLL_SECONDS:-5}"   # seconds between live checks (the offline tests set 0)

say() { printf '%s\n' "$*"; }
ok()  { printf '  ok    %s\n' "$*"; }
die() { printf '\n❌ %s\n' "$*" >&2; exit 1; }

MODE=check; ROLLBACK_ID=""
case "${1:-}" in
  "") ;;
  --publish) MODE=publish ;;
  --rollback) MODE=rollback; ROLLBACK_ID="${2:-}"
              [ -n "$ROLLBACK_ID" ] || die "usage: scripts/release.sh --rollback <deploy_id>" ;;
  -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
  *) die "unknown option '$1'. Use nothing (check only), --publish, or --rollback <deploy_id>" ;;
esac

cd "$(dirname "$0")/.."
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ---------- helpers ----------

# json_get FILE a.b.c : print one field from a JSON file ("" when missing). Tolerates CLI noise before the JSON.
json_get() {
  python3 - "$1" "$2" <<'PY'
import json, sys
raw = open(sys.argv[1], encoding="utf-8", errors="replace").read()
i = raw.find("{")
d = json.JSONDecoder().raw_decode(raw[i:])[0] if i >= 0 else {}
for k in sys.argv[2].split("."):
    d = d.get(k) if isinstance(d, dict) else None
print("" if d is None else d)
PY
}

# live_version FILE : the "Version X.Y.Z" strings on a page, one line, sorted.
live_version() { grep -oE 'Version [0-9]+\.[0-9]+\.[0-9]+' "$1" 2>/dev/null | sort -u | tr '\n' ' ' | sed 's/ $//'; }

NF_TOKEN=""; NF_WHO=""
# netlify_auth : find a stored Netlify login that can see the site. Writes the site JSON to $TMP/site.json.
netlify_auth() {
  command -v netlify >/dev/null 2>&1 || die "the netlify CLI is not installed (npm i -g netlify-cli)"
  local uid email tok
  while IFS="$(printf '\t')" read -r uid email tok; do
    [ -n "$tok" ] || continue
    if NETLIFY_AUTH_TOKEN="$tok" netlify api getSite --data "{\"site_id\":\"$SITE_ID\"}" >"$TMP/site.json" 2>/dev/null; then
      NF_TOKEN="$tok"; NF_WHO="$email"; return 0
    fi
  done < <(
    if [ -n "${NETLIFY_AUTH_TOKEN:-}" ]; then
      printf 'env\tNETLIFY_AUTH_TOKEN\t%s\n' "$NETLIFY_AUTH_TOKEN"
    else
      python3 - <<'PY'
import json, os
try:
    d = json.load(open(os.path.expanduser("~/Library/Preferences/netlify/config.json")))
except Exception:
    d = {}
users = d.get("users") or {}
for uid in sorted(users, key=lambda u: u != d.get("userId")):   # active account first
    u = users[uid] or {}
    tok = (u.get("auth") or {}).get("token") or ""
    if tok:
        print(f"{uid}\t{u.get('email') or uid}\t{tok}")
PY
    fi
  )
  die "no Netlify login on this machine can see the guide site ($SITE_ID).
   Add the site owner's login: netlify login --new, open the link signed in as that account, click Authorize."
}
nf() { NETLIFY_AUTH_TOKEN="$NF_TOKEN" netlify "$@"; }

# fetch_live OUT : download the live guide page, bypassing caches.
fetch_live() { curl -fsS -H 'Cache-Control: no-cache' -o "$1" "$SITE_URL/?release-check=$(date +%s)$RANDOM"; }

# build_site REV OUT : the guide page exactly as committed at REV: index.html plus every local file it links.
build_site() {
  local rev="$1" out="$2" ref
  mkdir -p "$out"
  git show "$rev:$GUIDE" > "$out/index.html"
  python3 - "$out/index.html" > "$TMP/refs.txt" <<'PY'
import re, sys
html = open(sys.argv[1], encoding="utf-8").read()
refs = set()
for m in re.finditer(r'''(?:src|href)\s*=\s*["']([^"'#?]*)''', html):
    r = m.group(1).strip()
    if not r or re.match(r'^(?:[a-z][a-z0-9+.-]*:|//)', r, re.I):
        continue                      # https:, mailto:, data:, protocol-relative: not ours to ship
    refs.add(r)
for r in sorted(refs):
    print(r)
PY
  while IFS= read -r ref; do
    ref="${ref%$'\r'}"   # Python on Windows prints CRLF; a trailing CR makes every asset look missing
    case "$ref" in
      /*)    die "the guide links '$ref' from the site root; use a path relative to guide/ so it ships with the page" ;;
      *..*)  die "the guide links '$ref', outside guide/" ;;
    esac
    mkdir -p "$out/$(dirname "$ref")"
    git show "$rev:guide/$ref" > "$out/$ref" 2>/dev/null \
      || die "the guide links '$ref' but guide/$ref is not committed at ${rev:0:12}"
  done < "$TMP/refs.txt"
}

# same_as_built LIVE BUILT : the live page equals the built one, apart from lines Netlify injects
# (every extra line must mention netlify). Prints the first unexpected lines on mismatch.
same_as_built() {
  python3 - "$1" "$2" <<'PY'
import difflib, sys
live = open(sys.argv[1], encoding="utf-8", errors="replace").read().splitlines()
built = open(sys.argv[2], encoding="utf-8", errors="replace").read().splitlines()
bad = []
for op, a1, a2, b1, b2 in difflib.SequenceMatcher(None, built, live, autojunk=False).get_opcodes():
    if op == "equal":
        continue
    if op == "insert" and all("netlify" in l.lower() for l in live[b1:b2]):
        continue
    bad.append((op, built[a1:a2][:3], live[b1:b2][:3]))
for op, want, got in bad[:5]:
    print(f"    {op}: built {want!r} vs live {got!r}")
sys.exit(1 if bad else 0)
PY
}

# live_matches DIR : 0 when the live page and every file it links are the same as DIR's (Netlify's own injected
# lines aside). On a mismatch, sets MISMATCH to what differs.
MISMATCH=""
live_matches() {
  local dir="$1" f
  MISMATCH=""
  fetch_live "$TMP/live.html" 2>/dev/null || { MISMATCH="the live page did not load"; return 1; }
  [ "$(live_version "$TMP/live.html")" = "$(live_version "$dir/index.html")" ] \
    || { MISMATCH="the live page shows '$(live_version "$TMP/live.html")'"; return 1; }
  same_as_built "$TMP/live.html" "$dir/index.html" > "$TMP/mismatch.txt" \
    || { MISMATCH="the live page's content differs:
$(cat "$TMP/mismatch.txt")"; return 1; }
  while IFS= read -r f; do
    f="${f#./}"
    [ "$f" = index.html ] && continue
    curl -fsS -o "$TMP/live-file" "$SITE_URL/$f" 2>/dev/null && cmp -s "$TMP/live-file" "$dir/$f" \
      || { MISMATCH="the live $f is missing or different"; return 1; }
  done < <(cd "$dir" && find . -type f)
  return 0
}

# netlify_credits : on Netlify's credit plans a production deploy costs 15 credits, and when a team runs out,
# Netlify pauses EVERY site on that team (this page included) until the next billing period. Counts this period's
# production deploys across the whole team; sets NF_CREDIT_LINE, and NF_CREDIT_BLOCK when one more deploy would
# leave less than a traffic reserve (page views and bandwidth also cost credits and are not visible in the API).
# Netlify has no API for credits actually used, so this counts deploys: deploys on a site that has since been
# deleted are not visible and still cost credits, so the count can run low until the period resets.
NF_CREDIT_LINE=""; NF_CREDIT_BLOCK=""
netlify_credits() {
  local acct out
  acct="$(json_get "$TMP/site.json" account_id)"
  [ -n "$acct" ] || return 0
  nf api getAccount --data "{\"account_id\":\"$acct\"}" > "$TMP/account.json" 2>/dev/null || return 0
  nf api listSites --data '{"filter":"all","per_page":100}' > "$TMP/sites.json" 2>/dev/null || return 0
  out="$(NETLIFY_AUTH_TOKEN="$NF_TOKEN" python3 - "$TMP/account.json" "$TMP/sites.json" "$acct" <<'PY'
import json, subprocess, sys
from datetime import datetime
acct = json.load(open(sys.argv[1])); sites = json.load(open(sys.argv[2])); acct_id = sys.argv[3]
plan = acct.get("plan_credits") or ((acct.get("capabilities") or {}).get("credits") or {}).get("included")
start = acct.get("current_billing_period_start") or acct.get("current_usage_period_start")
nxt = (acct.get("next_billing_period_start") or acct.get("next_usage_period_start") or "")[:10]
if not plan or not start:
    sys.exit(0)                                    # not a credit plan: nothing to guard
start = datetime.fromisoformat(start.replace("Z", "+00:00"))
count = 0
for s in sites:
    if s.get("account_id") != acct_id:
        continue
    for page in range(1, 11):
        r = subprocess.run(["netlify", "api", "listSiteDeploys", "--data",
                            json.dumps({"site_id": s["id"], "page": page, "per_page": 100})],
                           capture_output=True, text=True)
        try:
            ds = json.loads(r.stdout)
        except Exception:
            print("ERR"); sys.exit(0)
        recent = [d for d in ds if datetime.fromisoformat(d["created_at"].replace("Z", "+00:00")) >= start]
        count += sum(1 for d in recent if d.get("context") == "production" and d.get("state") == "ready")
        if len(ds) < 100 or len(recent) < len(ds):
            break
used = count * 15
reserve = max(45, int(plan * 0.15))
line = (f"{count} production deploys on this Netlify team since {start.date()} = {used} of {plan} credits "
        f"(resets {nxt}; page traffic uses credits too and is not counted)")
block = used + 15 > plan - reserve
print(("BLOCK\t" if block else "OK\t") + line + f"\t{nxt}\t{reserve}")
PY
)"
  case "$out" in
    ERR*|"") NF_CREDIT_LINE="Netlify credit count unavailable" ;;
    *) NF_CREDIT_LINE="$(printf '%s' "$out" | cut -f2)"
       if [ "$(printf '%s' "$out" | cut -f1)" = BLOCK ]; then
         NF_CREDIT_BLOCK="Netlify: $NF_CREDIT_LINE.
   One more production deploy would leave under $(printf '%s' "$out" | cut -f4) credits for page traffic. When the team runs
   out, Netlify pauses EVERY site on it, this guide page included, until $(printf '%s' "$out" | cut -f3).
   Wait until then, or move the team to a plan with more credits. Nothing was changed."
       fi ;;
  esac
}

# ---------- rollback ----------

if [ "$MODE" = rollback ]; then
  netlify_auth
  say "Putting guide page deploy $ROLLBACK_ID back live (Netlify login: $NF_WHO)"
  nf api restoreSiteDeploy --data "{\"site_id\":\"$SITE_ID\",\"deploy_id\":\"$ROLLBACK_ID\"}" > "$TMP/restore.json" 2>&1 \
    || { tail -3 "$TMP/restore.json" >&2; die "Netlify refused the rollback. Deploy IDs: netlify api listSiteDeploys --data '{\"site_id\":\"$SITE_ID\"}'"; }
  sleep "$POLL"
  nf api getSite --data "{\"site_id\":\"$SITE_ID\"}" > "$TMP/site.json"
  now="$(json_get "$TMP/site.json" published_deploy.id)"
  [ "$now" = "$ROLLBACK_ID" ] || die "Netlify still reports deploy $now as live, not $ROLLBACK_ID"
  fetch_live "$TMP/live.html" || die "the live page did not load after the rollback"
  say "✅ live page is deploy $now and shows: $(live_version "$TMP/live.html")"
  exit 0
fi

# ---------- checks (both modes; nothing below changes anything until the publish section) ----------

[ -f VERSION ] && [ -f CHANGELOG.md ] && [ -f "$GUIDE" ] && git rev-parse --git-dir >/dev/null 2>&1 \
  || die "run this inside the kit repo"
say "Checks"

branch="$(git rev-parse --abbrev-ref HEAD)"
[ "$branch" = main ] || die "on branch '$branch'. Releases go from main"
if [ -n "$(git status --porcelain)" ]; then
  git status --short | head -10 >&2
  die "uncommitted changes. A release ships only what is committed, so commit (or stash) them first"
fi
ok "on main, nothing uncommitted"

V="$(tr -d ' \r\n' < VERSION)"
case "$V" in *[!0-9.]*|"") die "VERSION is '$V', expected X.Y.Z" ;; esac
printf '%s' "$V" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' || die "VERSION is '$V', expected X.Y.Z"
TAG="v$V"

top="$(grep -m1 '^## ' CHANGELOG.md || true)"
case "$top" in "## $V ("*|"## $V") ;; *) die "CHANGELOG.md's top entry is '$top', expected '## $V (date)'" ;; esac
awk 'BEGIN{n=0} /^## /{n++; next} n==1' CHANGELOG.md > "$TMP/notes.md"
[ -n "$(tr -d ' \n' < "$TMP/notes.md")" ] || die "the CHANGELOG.md entry for $V has no notes"
ok "VERSION $V, CHANGELOG top entry $V"

gv="$(live_version "$GUIDE")"
[ "$gv" = "Version $V" ] || die "the guide says '${gv:-no version}', VERSION says $V. Fix the <p class=\"version\"> line in $GUIDE"
ok "guide says Version $V"

t_pdf="$(git log -1 --format=%ct -- "$PDF")"
t_src="$(git log -1 --format=%ct -- "$GUIDE" guide/assets)"
[ -n "$t_pdf" ] || die "$PDF is not committed"
[ "$t_pdf" -ge "${t_src:-0}" ] \
  || die "the PDF is older than the guide it is printed from. Run guide/build-pdf.sh, commit the PDF, run this again"
ok "PDF is at least as new as the guide"

build_site HEAD "$TMP/check-site"
n_files="$(cd "$TMP/check-site" && find . -type f | wc -l | tr -d ' ')"
ok "guide page builds from the commit: index.html + $((n_files - 1)) linked file(s)"

if bash tests/run.sh > "$TMP/tests.log" 2>&1; then
  ok "tests pass ($(grep -c '^ok' "$TMP/tests.log" || true) checks)"
else
  grep -E '^(== |FAIL)' "$TMP/tests.log" | grep -B1 '^FAIL' | head -20 >&2 || true
  die "tests failed. Full output: bash tests/run.sh"
fi
if [ -n "$(git status --porcelain)" ]; then
  git status --short | head -10 >&2
  die "the tests changed tracked files (usually the guide's generated cards). Commit them and run this again"
fi
bash scripts/prepublish.sh > "$TMP/prepublish.log" 2>&1 || { cat "$TMP/prepublish.log" >&2; die "prepublish found a problem"; }
ok "prepublish clean (no keys, no .env, no em dashes)"

git fetch --quiet origin main || die "could not reach GitHub (git fetch origin main)"
HEAD_SHA="$(git rev-parse HEAD)"; ORIGIN_SHA="$(git rev-parse origin/main)"
if [ "$HEAD_SHA" = "$ORIGIN_SHA" ]; then
  push_n=0
elif git merge-base --is-ancestor "$ORIGIN_SHA" "$HEAD_SHA"; then
  push_n="$(git rev-list --count "$ORIGIN_SHA..$HEAD_SHA")"
else
  die "local main and GitHub main have diverged, or GitHub is ahead. Pull first"
fi

rt="$(git ls-remote origin "refs/tags/$TAG" "refs/tags/$TAG^{}" || true)"
remote_tag="$(printf '%s\n' "$rt" | awk '$2 ~ /\^\{\}$/ {print $1}')"
[ -n "$remote_tag" ] || remote_tag="$(printf '%s\n' "$rt" | awk 'NF {print $1; exit}')"
local_tag="$(git rev-parse -q --verify "refs/tags/$TAG^{commit}" 2>/dev/null || true)"
for c in "$local_tag" "$remote_tag"; do
  [ -z "$c" ] || [ "$c" = "$HEAD_SHA" ] \
    || die "$TAG already exists at ${c:0:7}, not at this commit (${HEAD_SHA:0:7}). $V is already released: bump VERSION"
done

[ "$(gh api "repos/$REPO" --jq .permissions.push 2>/dev/null || true)" = true ] \
  || die "gh cannot push to $REPO. Check: gh auth status"
rel_exists=0
gh release view "$TAG" -R "$REPO" --json tagName,isDraft,assets > "$TMP/rel.json" 2>/dev/null && rel_exists=1
latest="$(gh release list -R "$REPO" -L 50 --json tagName,isLatest --jq '.[] | select(.isLatest) | .tagName' 2>/dev/null || true)"
if [ -n "$latest" ] && [ "$latest" != "$TAG" ]; then
  python3 -c 'import sys
v = lambda s: tuple(int(x) for x in s.lstrip("v").split("."))
sys.exit(0 if v(sys.argv[1]) > v(sys.argv[2]) else 1)' "$TAG" "$latest" \
    || die "$latest is already the latest release, and $TAG is not newer. Bump VERSION"
fi
ok "GitHub reachable, push access, $TAG is new or already at this commit"

netlify_auth
prev_deploy="$(json_get "$TMP/site.json" published_deploy.id)"
live_now="unreachable"
fetch_live "$TMP/live-before.html" 2>/dev/null && live_now="$(live_version "$TMP/live-before.html")"
ok "Netlify login $NF_WHO can deploy the guide site (live now: ${live_now:-no version shown})"
nf api listSiteSnippets --data "{\"site_id\":\"$SITE_ID\"}" > "$TMP/snips.json" 2>/dev/null || echo '[]' > "$TMP/snips.json"
SNIPS="$(python3 -c 'import json,sys
s = json.load(open(sys.argv[1])) or []
print(", ".join(str(x.get("title") or x.get("id")) for x in s))' "$TMP/snips.json" 2>/dev/null || true)"
[ -z "$SNIPS" ] || ok "note: Netlify injects snippet(s) into every page of this site: $SNIPS"
SNIP_HINT=""
[ -z "$SNIPS" ] || SNIP_HINT="
   This site has Netlify snippet injection(s) that change every page: $SNIPS. List or remove them with:
   netlify api listSiteSnippets --data '{\"site_id\":\"$SITE_ID\"}'"
DEPLOY_TITLE="$TAG (${HEAD_SHA:0:7})"
need_deploy=1
if live_matches "$TMP/check-site"; then
  need_deploy=0
elif [ "$(json_get "$TMP/site.json" published_deploy.title)" = "$DEPLOY_TITLE" ] && [ "$MISMATCH" = "the live page did not load" ]; then
  die "Netlify says the $TAG deploy is live, but $SITE_URL does not load. Deploying again cannot fix that.
   If the team ran out of Netlify credits, Netlify pauses its sites until the next billing period.
   Otherwise wait a minute and run this again. Nothing was changed."
elif [ "$(json_get "$TMP/site.json" published_deploy.title)" = "$DEPLOY_TITLE" ]; then
  die "Netlify is already serving the $TAG deploy, but the live page differs from it: $MISMATCH
   Something outside the deploy is changing the page, so deploying again cannot fix it and would only
   spend 15 Netlify credits. Nothing was changed.$SNIP_HINT"
fi
netlify_credits
[ -n "$NF_CREDIT_LINE" ] && ok "$NF_CREDIT_LINE"
if [ "$need_deploy" = 1 ] && [ -n "$NF_CREDIT_BLOCK" ]; then die "$NF_CREDIT_BLOCK"; fi

# ---------- plan ----------

say ""
say "Release $TAG from ${HEAD_SHA:0:7} \"$(git log -1 --format=%s)\""
if [ "$push_n" -gt 0 ]; then say "  1. push main       $push_n new commit(s) to GitHub"; else say "  1. push main       already on GitHub, skip"; fi
if [ -n "$remote_tag" ]; then say "  2. tag            $TAG already at this commit, skip"; else say "  2. tag            create $TAG at ${HEAD_SHA:0:7}"; fi
if [ "$rel_exists" = 1 ]; then say "  3. GitHub release $TAG exists, re-check its zips"; else say "  3. GitHub release create $TAG with both zips, mark it Latest"; fi
if [ "$need_deploy" = 1 ]; then say "  4. guide page     deploy index.html + $((n_files - 1)) linked file(s) from $TAG (live now: ${live_now:-?})"
else say "  4. guide page     live page already matches $TAG, skip (no Netlify credits used)"; fi
say "  5. verify         the download link and the live page both match $TAG"

if [ "$MODE" = check ]; then
  say ""
  say "Check only: nothing was changed. To do it: scripts/release.sh --publish"
  exit 0
fi

# ---------- publish ----------

say ""
say "Publishing"
if [ "$push_n" -gt 0 ]; then git push --quiet origin main || die "git push failed; nothing else was changed"; ok "pushed main"; fi
if [ -z "$local_tag" ]; then
  if [ -n "$remote_tag" ]; then git fetch --quiet origin "refs/tags/$TAG:refs/tags/$TAG"
  else git tag -a "$TAG" -m "$TAG" "$HEAD_SHA"; fi
fi
if [ -z "$remote_tag" ]; then git push --quiet origin "refs/tags/$TAG" || die "could not push tag $TAG"; ok "tagged $TAG"; fi

mkdir -p "$TMP/zip" "$TMP/dl"
Z1="$TMP/zip/$ZIP_NAME-$TAG.zip"; Z2="$TMP/zip/$ZIP_NAME.zip"
git archive --format=zip --prefix="$ZIP_NAME/" "$HEAD_SHA" -o "$Z1"
cp "$Z1" "$Z2"
if [ "$rel_exists" = 0 ]; then
  gh release create "$TAG" -R "$REPO" --verify-tag --title "$TAG" --notes-file "$TMP/notes.md" --latest "$Z1" "$Z2" >/dev/null \
    || die "gh release create failed. The tag is pushed; run this again to retry"
  ok "GitHub release $TAG created"
else
  for z in "$Z1" "$Z2"; do
    n="$(basename "$z")"
    python3 -c 'import json,sys; sys.exit(0 if any(a.get("name")==sys.argv[2] for a in json.load(open(sys.argv[1])).get("assets",[])) else 1)' "$TMP/rel.json" "$n" \
      || { gh release upload "$TAG" "$z" -R "$REPO" >/dev/null || die "could not attach $n"; ok "attached missing $n"; }
  done
  # Always set it explicitly: GitHub's releases/latest download link can lag minutes behind an automatic Latest.
  gh release edit "$TAG" -R "$REPO" --latest >/dev/null || die "could not mark $TAG as the Latest release"
  ok "$TAG marked Latest"
fi

gh release download "$TAG" -R "$REPO" -D "$TMP/dl" -p "$ZIP_NAME-$TAG.zip" -p "$ZIP_NAME.zip" --clobber >/dev/null \
  || die "could not download the zips back from the $TAG release"
cmp -s "$TMP/dl/$ZIP_NAME-$TAG.zip" "$Z1" && cmp -s "$TMP/dl/$ZIP_NAME.zip" "$Z1" \
  || die "the zips on the $TAG release are not git archive of $TAG. Replace them:
   git archive --format=zip --prefix=$ZIP_NAME/ $TAG -o $ZIP_NAME.zip && cp $ZIP_NAME.zip $ZIP_NAME-$TAG.zip
   gh release upload $TAG $ZIP_NAME.zip $ZIP_NAME-$TAG.zip --clobber -R $REPO"
latest_ok=0; waited=0
for i in $(seq 1 36); do
  if curl -fsSL -o "$TMP/dl/latest.zip" "https://github.com/$REPO/releases/latest/download/$ZIP_NAME.zip" 2>/dev/null \
     && cmp -s "$TMP/dl/latest.zip" "$Z1"; then latest_ok=1; break; fi
  [ "$waited" = 1 ] || { say "  ..    waiting for GitHub's download link to switch to $TAG (can take a minute or two)"; waited=1; }
  sleep "$POLL"
done
[ "$latest_ok" = 1 ] || die "after 3 minutes the README's download link (releases/latest) still does not serve $TAG.
   The page was NOT deployed. Run this again in a few minutes (it skips what is already done)"
ok "download link serves $TAG, byte-identical to the tag"

mkdir -p "$TMP/web"
build_site "$HEAD_SHA" "$TMP/web/site"
if [ -n "$prev_deploy" ]; then undo="   Undo the page: scripts/release.sh --rollback $prev_deploy"
else undo="   This was the site's first deploy, so there is no earlier page to roll back to."; fi
if live_matches "$TMP/web/site"; then
  new_deploy="$prev_deploy"
  undo="   The page was not redeployed, so there is nothing to undo."
  ok "the live page already matches $TAG, no deploy needed (no Netlify credits used)"
else
  ( cd "$TMP/web" && nf deploy --prod --no-build --dir site --site "$SITE_ID" --message "$DEPLOY_TITLE" --json ) \
    > "$TMP/deploy.json" 2> "$TMP/deploy.err" || {
      tail -5 "$TMP/deploy.err" >&2
      if grep -q 'Forbidden' "$TMP/deploy.err"; then
        die "Netlify refused the deploy (403 Forbidden). On Netlify's free credit plan that means the team's monthly
   credits are (nearly) used up. ${NF_CREDIT_LINE:-}. The live page is unchanged. GitHub already has $TAG, so
   re-run this after the credits reset (it skips what is already done)"
      fi
      die "netlify deploy failed. Netlify only switches the live page once a deploy completes, so it should still be ${live_now:-the previous version}"
    }
  new_deploy="$(json_get "$TMP/deploy.json" deploy_id)"
  [ -n "$new_deploy" ] || die "netlify deploy returned no deploy id; check the site before re-running"
  ok "deployed the guide page (deploy $new_deploy)"
  ok_live=0
  for i in $(seq 1 12); do
    if live_matches "$TMP/web/site"; then ok_live=1; break; fi
    sleep "$POLL"
  done
  [ "$ok_live" = 1 ] || die "after $((12 * POLL))s, $MISMATCH$SNIP_HINT
$undo"
  nf api getSite --data "{\"site_id\":\"$SITE_ID\"}" > "$TMP/site-after.json"
  [ "$(json_get "$TMP/site-after.json" published_deploy.id)" = "$new_deploy" ] \
    || die "Netlify reports a different deploy as live than the one just made.
$undo"
fi
ok "live page shows Version $V and matches $TAG byte for byte (apart from Netlify's own tags)"

say ""
say "✅ $TAG released"
say "   GitHub: https://github.com/$REPO/releases/tag/$TAG"
say "   Guide:  $SITE_URL (deploy ${new_deploy:-unknown})"
say "$undo"
