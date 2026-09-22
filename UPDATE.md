# UPDATE.md: pulling a newer version of this kit

Follow this when the attendee says "Update my connections", or opens with a link to this file. You run every command yourself, through your Bash tool. One step per message. Never touch anything already working; this only adds or replaces files.

## 1. Check the version

```bash
BUNDLE="$(pwd)"
cat "$BUNDLE/VERSION"
```

Compare it to the latest release on GitHub. If they already match, tell them they're current and stop here; nothing else in this file needs to run.

## 2. Get a fresh copy

```bash
git clone --depth 1 https://github.com/Solnest-AI/str-secrets-connections.git /tmp/ssc-update
```

No `git` on this machine, or the clone fails: download the release zip from GitHub instead and unzip it to `/tmp/ssc-update`. Either way, the rest of this file assumes `/tmp/ssc-update` holds the fresh copy.

## 3. Check for a bundled server change BEFORE copying anything

Diff first, copy second; once the copy runs, the old and new mcp-servers folders look identical and there's nothing left to diff.

```bash
diff -rq --exclude=.env --exclude=node_modules --exclude=.venv --exclude=dist /tmp/ssc-update/mcp-servers "$BUNDLE/mcp-servers" 2>/dev/null | tee /tmp/ssc-changed-servers.txt
```

Empty output means no bundled server changed; keep that file around either way, step 6 reads it.

## 4. Copy over only what changes

```bash
cd /tmp/ssc-update
for item in CONNECTIONS.md connectors emails lib check-connections.sh fan-out-env.sh KEYS.md VERSION CHANGELOG.md build mcp-servers; do
  [ -e "$item" ] || continue
  rsync -a --exclude '.env' --exclude '.env.*' --exclude '.cache/' --exclude 'node_modules/' --exclude '.venv/' --exclude 'dist/' "$item" "$BUNDLE/"
done
```

No `rsync` on this machine: use `cp -R` per item instead, then manually delete any `.env`, `.env.*`, `.cache/`, `node_modules/`, `.venv/`, or `dist/` that a plain copy would have overwritten inside `mcp-servers/*/` and `build/`.

This never touches: the attendee's own `.env` (their keys), `.cache/` (restart and pending-vendor state), or anything already registered in `~/.claude.json`. A newer version of a bundled server's source gets copied in, but nothing re-registers it automatically; that only happens in step 6 if step 3 found it changed.

## 5. Re-check

```bash
bash "$BUNDLE/check-connections.sh"
```

Everything that was green before this update should still be green. If a row that used to work now shows a problem, that's a real regression from the update, not something the attendee broke; open the matching `connectors/<file>.md` and work it like any other red row.

## 6. Rebuild anything step 3 flagged

```bash
cat /tmp/ssc-changed-servers.txt
```

For each server named there, rebuild it the same way its connector file's Register block does (`npm ci && npm run build` for the Node servers, `uv venv` plus `uv pip install` for the Python ones), then tell the attendee: "quit and reopen the Claude Code desktop app, open this same folder" so the rebuilt server picks up. No need to re-register; the register helper already points at the same file path, and the rebuild replaces what's on disk there.

## 7. What changed

```bash
sed -n '/^## /,/^## /p' "$BUNDLE/CHANGELOG.md" | head -40
```

Summarize the entries between the attendee's old `VERSION` and the new one, in plain language, Solnest voice. Skip versions they already have; they don't need the whole history, just what's new to them.

## 8. Clean up

```bash
rm -rf /tmp/ssc-update
```

Then tell them they're updated, what changed in one or two lines, and whether anything needs a restart (from step 6).
