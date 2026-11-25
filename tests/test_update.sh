#!/usr/bin/env bash
# scripts/update.py: installs a release over an attendee's copy without touching their keys, state, built
# servers or anything Claude built for them; --undo puts the old version back; --after rebuilds only what changed.
# Offline: two fake releases are built as tarballs in a temp dir and handed to the updater instead of GitHub.
set -u; cd "$(dirname "$0")/.."
. tests/_helpers.sh
fail=0; t(){ if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
PY="$(command -v python3 || command -v python)"
root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT

t "update.py exists"          "[ -f scripts/update.py ]"
t "auto-updater shipped"      "[ -f scripts/solnest_autoupdate.py ]"
t "update.py is stdlib only"  "! grep -qE '^(import|from) (requests|dotenv|httpx)' scripts/update.py"

cat > "$root/drive.py" <<'PY'
import importlib.util, io, json, sys, tarfile
from pathlib import Path
spec = importlib.util.spec_from_file_location("upd", sys.argv[1]); u = importlib.util.module_from_spec(spec); spec.loader.exec_module(u)
root = Path(sys.argv[2])

def tarball(tag, files):
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tar:
        for rel, text in files.items():
            data = text.encode(); ti = tarfile.TarInfo(f"str-secrets-connections-{tag}/{rel}"); ti.size = len(data)
            tar.addfile(ti, io.BytesIO(data))
    return buf.getvalue()

v1 = {"VERSION": "1.0.0\n", "CONNECTIONS.md": "old\n", "OLD-ONLY.md": "gone soon\n", ".env.template": "A=\n",
      "lib/x.py": "x = 1\n", "mcp-servers/hospitable/package.json": '{"scripts":{"build":"tsc"}}',
      "mcp-servers/hospitable/src/index.ts": "old\n", "mcp-servers/airroi/requirements.txt": "httpx\n",
      "mcp-servers/airroi/server.py": "old\n", "mcp-servers/kie/requirements.txt": "mcp\n"}
v2 = dict(v1, **{"VERSION": "1.1.0\n", "CONNECTIONS.md": "new\n", "NEW.md": "hi\n", ".env": "EVIL=1\n",
                 "mcp-servers/hospitable/.env": "EVIL=1\n", "mcp-servers/hospitable/src/index.ts": "new\n",
                 "mcp-servers/airroi/requirements.txt": "httpx\nmcp\n", "mcp-servers/kie/requirements.txt": "mcp>=1\n"})
del v2["OLD-ONLY.md"]
blobs = {"v1.0.0": tarball("v1.0.0", v1), "v1.1.0": tarball("v1.1.0", v2)}
u.latest_tag = lambda timeout=20: "v1.1.0"
u.download = lambda tag, timeout=60: blobs[tag]

kit = root / "kit"
for rel, text in v1.items():
    (kit / rel).parent.mkdir(parents=True, exist_ok=True); (kit / rel).write_text(text)
# The attendee's own things.
(kit / ".env").write_text("PRICELABS_API_KEY=mine\n")
(kit / "mcp-servers/hospitable/.env").write_text("HOSPITABLE_API_KEY=mine\n")
(kit / ".cache").mkdir(); (kit / ".cache/needs-restart").write_text("1\n")
(kit / "mcp-servers/hospitable/dist").mkdir(); (kit / "mcp-servers/hospitable/dist/index.js").write_text("built\n")
(kit / "mcp-servers/hospitable/node_modules").mkdir()
(kit / "mcp-servers/airroi/.venv").mkdir()
(kit / "mcp-servers/guesty").mkdir(); (kit / "mcp-servers/guesty/server.py").write_text("claude built this\n")
(kit / "lib/x.py").write_text("x = 2  # edited\n")

r = u.update(kit)
chk = {
 "updated": r["status"] == "updated" and r["to"] == "1.1.0",
 "new file in": (kit / "NEW.md").read_text() == "hi\n",
 "changed file replaced": (kit / "CONNECTIONS.md").read_text() == "new\n",
 "dropped file removed": not (kit / "OLD-ONLY.md").exists(),
 "root .env kept": (kit / ".env").read_text() == "PRICELABS_API_KEY=mine\n",
 "server .env kept": (kit / "mcp-servers/hospitable/.env").read_text() == "HOSPITABLE_API_KEY=mine\n",
 ".cache kept": (kit / ".cache/needs-restart").exists(),
 "dist kept": (kit / "mcp-servers/hospitable/dist/index.js").read_text() == "built\n",
 "claude-built server kept": (kit / "mcp-servers/guesty/server.py").exists(),
 "edited file reported": "lib/x.py" in r["edited"],
 "manifest written": (kit / u.MANIFEST).is_file(),
 "plan: hospitable build, airroi pip, kie untouched (never built)":
     [(n, [c[0:2] for c in cmds]) for n, cmds in u.rebuild_plan(kit, (kit / u.CHANGED).read_text().split())]
     == [("airroi", [["uv", "pip"]]), ("hospitable", [["npm", "run"]])],
 "current second time": u.update(kit)["status"] == "current",
}
u.undo(kit)
chk.update({
 "undo: version back": (kit / "VERSION").read_text() == "1.0.0\n",
 "undo: old file back": (kit / "OLD-ONLY.md").read_text() == "gone soon\n",
 "undo: new file gone": not (kit / "NEW.md").exists(),
 "undo: edit back": (kit / "lib/x.py").read_text() == "x = 2  # edited\n",
 "undo: keys still there": (kit / ".env").read_text() == "PRICELABS_API_KEY=mine\n",
 "undo: rebuild queued": "mcp-servers/hospitable/src/index.ts" in (kit / u.CHANGED).read_text(),
})
(kit / ".git").mkdir()
try:
    u.update(kit); chk["git copy refused"] = False
except u.UpdateError:
    chk["git copy refused"] = True
prot = {".env": True, "mcp-servers/x/.env": True, "a/.env.local": True, ".env.template": False,
        "mcp-servers/x/.env.example": False, "mcp-servers/x/node_modules/a.js": True, "mcp-servers/x/dist/i.js": True,
        "mcp-servers/rankbreeze/session.txt": True, ".cache/x": True, "build/README.md": False}
chk["protected paths"] = all(u._protected(k) == v for k, v in prot.items())
for k, v in chk.items():
    print(("ok   " if v else "FAIL ") + k)
PY
out="$("$PY" "$root/drive.py" "$PWD/scripts/update.py" "$root" 2>&1)"
printf '%s\n' "$out"
printf '%s' "$out" | grep -q '^FAIL\|Traceback' && fail=1
n_ok="$(printf '%s\n' "$out" | grep -c '^ok ')"
t "every updater check ran ($n_ok)" "[ $n_ok -ge 21 ]"

# The register line is the same in setup and UPDATE.md, and names this tool's commands.
cat > "$root/reg.txt" <<'TXT'
register --name connections --folder "$BUNDLE" --update '{python} scripts/update.py' --after '{python} scripts/update.py --after' --undo '{python} scripts/update.py --undo'
TXT
t "setup registers auto-updates"  "grep -qF -f '$root/reg.txt' CONNECTIONS.md"
t "UPDATE.md registers too"       "grep -qF -f '$root/reg.txt' UPDATE.md"
t "UPDATE.md runs the updater, no clone of main" "grep -qF 'scripts/update.py' UPDATE.md && ! grep -q 'git clone' UPDATE.md"
for f in CLAUDE.md .claude/skills/str-secrets-connections/SKILL.md CONNECTIONS.md; do
  t "own-changes block in $f" "grep -qF '.solnest/connections/my-instructions.md' '$f'"
done
t "no em-dash in UPDATE.md, SKILL.md, CLAUDE.md" "! grep -q '—' UPDATE.md .claude/skills/str-secrets-connections/SKILL.md CLAUDE.md"
exit $fail
