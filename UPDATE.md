# UPDATE.md: pulling a newer version of this kit

New versions normally install themselves: setup turns on automatic updates (Phase 0, step 6 of `CONNECTIONS.md`), and once a day, in the background, the kit moves to the latest published release. Follow this file when the attendee says "Update my connections", or opens with a link to it, to get the newest version right now. It also turns automatic updates on for a copy set up before they existed.

You run every command yourself, through your Bash tool. One step per message. Never touch anything already working: the updater never touches any `.env`, `.cache/`, a server Claude built for them, or anything registered in `~/.claude.json`.

## 1. Find the kit and unhook it from GitHub

```bash
[ -f "$PWD/CONNECTIONS.md" ] || cd str-secrets-connections
BUNDLE="$(pwd)"
cat "$BUNDLE/VERSION"
bash "$BUNDLE/lib/detach_from_github.sh"
```

Remember the old version; step 6 needs it. The detach line removes the GitHub link only from an untouched copy of the kit, never their `.env` or a working copy, and always exits 0. Relay its one line. Never commit or push anything in their folder.

## 2. Get the updater (only if this copy is older than 1.1.0)

```bash
if [ ! -f "$BUNDLE/scripts/update.py" ]; then
  TAG="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/Solnest-AI/str-secrets-connections/releases/latest | sed 's#.*/tag/##')"
  mkdir -p "$BUNDLE/scripts" && curl -fsSL -o "$BUNDLE/scripts/update.py" "https://raw.githubusercontent.com/Solnest-AI/str-secrets-connections/$TAG/scripts/update.py" && echo "updater ready ($TAG)"
fi
```

If the download fails, GitHub is unreachable right now; tell them to try again in a few minutes.

## 3. Update

```bash
uv run --no-project --python 3.13 python "$BUNDLE/scripts/update.py"
```

It downloads the latest published release and replaces only the kit's own files. Everything it replaces is backed up first. Relay what it prints in plain words. "Already on the latest release" means skip to step 5. If it says they had edited kit files, tell them where their versions were saved.

## 4. Rebuild what changed

```bash
uv run --no-project --python 3.13 python "$BUNDLE/scripts/update.py" --after
```

It rebuilds only the bundled servers this update changed that they already use, in place. It never re-registers anything: every register line points at a fixed path in this folder. If it says "Rebuilt", tell the attendee: "quit and reopen the Claude Code desktop app, open this same folder" so the rebuilt server picks up.

**Coming from 1.0.6 or older (the old `VERSION` from step 1), three things changed shape and do need a re-register:**
1. Run `bash "$BUNDLE/install-tools.sh"` once. It confirms uv, Python 3.13 and Node from inside the app; if it says `RESTART NEEDED`, do that restart before going on.
2. `supabase-revenue-manager` used to launch through `npx` (15 to 18 seconds per start, timing out beside the other servers). Run the Register block in `connectors/db-supabase.md` section 3: it installs the pinned server into `mcp-servers/supabase/` and re-registers it as a direct `node` launch, same name, same `--project-ref`, same token variable, so the Revenue Manager still finds it.
3. `turno` (only if their ops tool is Turno) used to be registered as a bare `uv`. Run the Register block in `connectors/ops-turno.md` section 3: precompiled, uv by its full path.
Both rows show 🔒 until the app is quit and reopened; the checker clears them itself afterwards.

## 5. Turn on automatic updates

```bash
uv run --no-project --python 3.13 python "$BUNDLE/scripts/solnest_autoupdate.py" register --name connections --folder "$BUNDLE" --update '{python} scripts/update.py' --after '{python} scripts/update.py --after' --undo '{python} scripts/update.py --undo'
```

Same line as setup. Running it again is safe and picks up a newer auto-updater if this release has one. Relay its one line.

## 6. Re-check

```bash
bash "$BUNDLE/check-connections.sh"
```

Everything that was green before this update should still be green. If a row that used to work now shows a problem, that's a real regression from the update, not something the attendee broke; open the matching `connectors/<file>.md` and work it like any other red row.

## 7. What changed

```bash
sed -n '/^## /,/^## /p' "$BUNDLE/CHANGELOG.md" | head -40
```

Summarize the entries between the attendee's old `VERSION` and the new one, in plain language, Solnest voice. Skip versions they already have. Then tell them they're updated, what changed in one or two lines, whether anything needs a restart (from step 4), and that new versions now install themselves.

## Going back, or stopping automatic updates

- Something broke after an update: `uv run --no-project --python 3.13 python "$BUNDLE/scripts/update.py" --undo`, then step 4 again.
- "Is it updating itself?": `uv run --no-project --python 3.13 python ~/.solnest/autoupdate.py status`.
- Stop all automatic updates: the same line with `pause`. `resume` turns them back on.
