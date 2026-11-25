#!/usr/bin/env python3
"""Bring an attendee's copy of the connections kit to the latest release.

    uv run --no-project --python 3.13 python scripts/update.py          update to the latest release
    uv run --no-project --python 3.13 python scripts/update.py --after  rebuild only the bundled servers that changed
    uv run --no-project --python 3.13 python scripts/update.py --check  only say whether a newer release exists
    uv run --no-project --python 3.13 python scripts/update.py --undo   put back the version from before the last update

Ported from solnest-str-comping-agent/scripts/update.py (same mechanism). An
attendee's copy is a plain folder, not a git clone (Phase 0 runs
lib/detach_from_github.sh), so there is no `git pull`. The old UPDATE.md path
cloned main into /tmp and copied folders over, which shipped untagged work on
main and left behind every file a newer version deleted. This downloads the
latest published GitHub release (a tag) and replaces only the kit's own files.

What it never touches: every .env (the root one with the attendee's keys and
each mcp-servers/<name>/.env that fan-out-env.sh writes; .env.template and
.env.example are kit files), session.txt, .cache/, node_modules/, .venv/,
dist/, .claude/settings.local.json, and ~/.claude.json (it never opens it).
Only paths in the release are written, and only paths the previous release
shipped are removed (the manifest, .connections-files.txt), so a server Claude
built for this attendee (mcp-servers/guesty/, build/references/...) is never
touched. Every file it replaces or removes is copied to .update-backup/<time>/
first, so --undo is one step, and a failure halfway puts everything back before
it exits. A folder still linked to git is refused.

--after rebuilds, in place, only the bundled servers whose files this update
changed and that this attendee already built (dist/, node_modules/ or .venv/
present). It never re-registers anything: every register line points at a
fixed path inside the kit (dist/index.js, .venv/..., server.py), so the
rebuilt server is picked up the next time the app starts.

Standard library only.
"""

from __future__ import annotations

import argparse
import contextlib
import hashlib
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import urllib.error
import urllib.request
from datetime import datetime
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parent.parent
REPO = "Solnest-AI/str-secrets-connections"
# One "<git blob hash> <path>" line per file the kit shipped.
MANIFEST = ".connections-files.txt"
BACKUP_DIR = ".update-backup"
KEEP_BACKUPS = 3
CHANGED = Path(".cache") / "update-changed.txt"   # what the last update/undo changed, read by --after
UA = {"User-Agent": "str-secrets-connections-updater"}

# Never written, never removed, whatever a manifest or tarball says.
PROTECTED_PATHS = {".claude/settings.local.json", MANIFEST}
PROTECTED_NAMES = {".env", "session.txt"}
PROTECTED_DIRS = {".cache", "node_modules", ".venv", "venv", "dist", "__pycache__", ".pytest_cache",
                  ".git", BACKUP_DIR}


class UpdateError(RuntimeError):
    """The update could not run; the folder is unchanged (or was put back)."""


def _protected(rel: str) -> bool:
    parts = PurePosixPath(rel).parts
    if not parts:
        return True
    name = parts[-1]
    return (rel in PROTECTED_PATHS or name in PROTECTED_NAMES
            or (name.startswith(".env.") and name not in (".env.example", ".env.template"))
            or any(p in PROTECTED_DIRS for p in parts[:-1]))


def parse_version(text) -> tuple[int, ...] | None:
    m = re.fullmatch(r"\s*v?(\d+)\.(\d+)\.(\d+)\s*", str(text or ""))
    return tuple(int(x) for x in m.groups()) if m else None


def current_version(root: Path) -> str | None:
    try:
        v = (root / "VERSION").read_text(encoding="utf-8").strip()
    except OSError:
        return None
    return v if parse_version(v) else None


# ── GitHub ─────────────────────────────────────────────────────────────
def latest_tag(timeout: float = 20) -> str:
    """The latest release's tag. github.com redirects /releases/latest to
    /releases/tag/<tag>; unlike the API, that is not limited to 60 requests an
    hour per network, and a summit room shares one network."""
    req = urllib.request.Request(f"https://github.com/{REPO}/releases/latest", headers=UA, method="HEAD")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            final = r.geturl()
    except (urllib.error.URLError, OSError) as e:
        raise UpdateError(f"could not reach GitHub ({type(e).__name__})") from e
    m = re.search(r"/releases/tag/([^/?#]+)$", final)
    if not m or not parse_version(m.group(1)):
        raise UpdateError("GitHub has no published release of the connections kit yet")
    return m.group(1)


def download(tag: str, timeout: float = 60) -> bytes:
    url = f"https://github.com/{REPO}/archive/refs/tags/{tag}.tar.gz"
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=timeout) as r:
            return r.read()
    except (urllib.error.URLError, OSError) as e:
        raise UpdateError(f"could not download {tag} from GitHub ({type(e).__name__})") from e


def read_tarball(blob: bytes) -> dict[str, bytes]:
    """{relative path: content} from a GitHub source tarball. Anything that is
    not a plain file or folder inside the one top folder (a link, an absolute
    path, a ..) refuses the whole release: nothing is written."""
    files: dict[str, bytes] = {}
    meta = (tarfile.XGLTYPE, tarfile.XHDTYPE)  # GitHub's pax_global_header is metadata, not a path
    try:
        with tarfile.open(fileobj=io.BytesIO(blob), mode="r:gz") as tar:
            members = tar.getmembers()
            tops = {PurePosixPath(m.name).parts[0] for m in members
                    if m.name and not m.name.startswith("/") and m.type not in meta}
            for m in members:
                p = PurePosixPath(m.name)
                if m.name.startswith(("/", "\\")) or ".." in p.parts or len(tops) != 1:
                    raise UpdateError(f"the release contains an unsafe path ({m.name}); nothing was changed")
                if m.isdir() or m.type in meta:
                    continue
                if not m.isfile():
                    raise UpdateError(f"the release contains a link or device ({m.name}); nothing was changed")
                rel = "/".join(p.parts[1:])
                if rel:
                    files[rel] = tar.extractfile(m).read()
    except (tarfile.TarError, OSError, EOFError) as e:
        raise UpdateError(f"the downloaded release is not a valid archive ({type(e).__name__})") from e
    if "VERSION" not in files or not parse_version(files["VERSION"].decode("utf-8", "replace")):
        raise UpdateError("the downloaded release has no VERSION file; nothing was changed")
    return files


# ── Manifest ───────────────────────────────────────────────────────────
def file_hash(data: bytes) -> str:
    """Git's blob hash of the bytes (what `git hash-object --no-filters` prints)."""
    return hashlib.sha1(b"blob %d\0" % len(data) + data).hexdigest()


def load_manifest(root: Path) -> dict[str, str]:
    """{path: hash} of the files the installed release shipped; {} when there
    is none or it is damaged (then nothing is removed on that evidence)."""
    try:
        text = (root / MANIFEST).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return {}
    files = {}
    for line in text.splitlines():
        if not line or line.startswith("#"):
            continue
        digest, sep, rel = line.partition(" ")
        if not (sep and re.fullmatch(r"[0-9a-f]{40}", digest) and rel) or "\0" in rel:
            return {}
        if not _protected(rel):
            files[rel] = digest
    return files


def write_manifest(root: Path, paths) -> None:
    lines = ["# Files the connections kit shipped (scripts/update.py). Do not edit."]
    for rel in sorted(set(paths)):
        p = root / rel
        if not _protected(rel) and p.is_file():
            lines.append(f"{file_hash(p.read_bytes())} {rel}")
    _write(root / MANIFEST, ("\n".join(lines) + "\n").encode("utf-8"))


def _write(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".update-tmp")
    tmp.write_bytes(data)
    os.replace(tmp, path)


def _remove(root: Path, rel: str) -> None:
    """Delete one file, then any folder that leaves empty (up to the root)."""
    (root / rel).unlink(missing_ok=True)
    parent = (root / rel).parent
    while parent != root and parent.is_dir() and not any(parent.iterdir()):
        parent.rmdir()
        parent = parent.parent


def _record_changed(root: Path, rels) -> None:
    """Add to the list --after reads (it clears it once the rebuild worked)."""
    have = set()
    with contextlib.suppress(OSError):
        have = set((root / CHANGED).read_text(encoding="utf-8").split("\n"))
    _write(root / CHANGED, ("\n".join(sorted((have | set(rels)) - {""})) + "\n").encode("utf-8"))


# ── Update / undo ──────────────────────────────────────────────────────
def update(root: Path = ROOT) -> dict:
    if (root / ".git").exists():
        raise UpdateError("this folder is still linked to git: run `bash lib/detach_from_github.sh` "
                          "(it unlinks an untouched copy), or update a developer's clone with `git pull --ff-only`")
    have = current_version(root)
    tag = latest_tag()
    want = tag.lstrip("v")
    if have and parse_version(have) >= parse_version(want):
        return {"status": "current", "from": have, "to": have}
    release = read_tarball(download(tag))
    labelled = release["VERSION"].decode("utf-8", "replace").strip()
    if parse_version(labelled) != parse_version(want):
        raise UpdateError(f"the {tag} release is labelled {labelled} inside, so installing it would never "
                          f"finish; nothing was changed. Tell Solnest AI")
    new = {rel: data for rel, data in release.items() if not _protected(rel)}

    old = load_manifest(root)
    if not old and have:
        # A zip install (or a detached clone) never had a manifest. Its VERSION
        # names the release it came from, which lists what it shipped.
        with contextlib.suppress(UpdateError):
            old = {rel: file_hash(data) for rel, data in read_tarball(download(f"v{have}")).items()
                   if not _protected(rel)}
    gone = sorted(rel for rel in set(old) - set(new) if (root / rel).is_file())
    edited = sorted(rel for rel, h in old.items()
                    if (root / rel).is_file() and file_hash((root / rel).read_bytes()) != h)
    changed = sorted([rel for rel, data in new.items()
                      if not (root / rel).is_file() or (root / rel).read_bytes() != data] + gone)

    backup = root / BACKUP_DIR / datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    existed, added = [], []
    for rel in sorted(set(new) | set(gone)):
        src = root / rel
        if src.is_file():
            _write(backup / rel, src.read_bytes())
            existed.append(rel)
        else:
            added.append(rel)
    had_manifest = (root / MANIFEST).is_file()
    if had_manifest:
        _write(backup / MANIFEST, (root / MANIFEST).read_bytes())
    _write(backup / "undo.json", json.dumps({"from": have, "to": want, "existed": existed, "added": added,
                                             "had_manifest": had_manifest}, indent=1).encode())
    try:
        for rel, data in new.items():
            _write(root / rel, data)
        for rel in gone:
            _remove(root, rel)
        write_manifest(root, new)
        _record_changed(root, changed)
    except OSError as e:
        undo(root, backup)
        raise UpdateError(f"the update stopped halfway ({type(e).__name__}: {e}) and the previous version "
                          f"was put back; close other programs using this folder and try again") from e
    _prune(root / BACKUP_DIR)
    return {"status": "updated", "from": have or "unknown", "to": want, "added": added, "removed": gone,
            "changed": changed, "edited": [rel for rel in edited if rel in new or rel in gone],
            "backup": str(backup)}


def undo(root: Path = ROOT, backup: Path | None = None) -> dict:
    """Put back the files from before the last update (or the given backup)."""
    if backup is None:
        found = sorted(p for p in (root / BACKUP_DIR).glob("*") if (p / "undo.json").is_file()) \
            if (root / BACKUP_DIR).is_dir() else []
        if not found:
            raise UpdateError("there is no earlier version to go back to")
        backup = found[-1]
    meta = json.loads((backup / "undo.json").read_text(encoding="utf-8"))
    for rel in meta.get("added") or []:
        if not _protected(rel):
            _remove(root, rel)
    for rel in meta.get("existed") or []:
        if not _protected(rel):
            _write(root / rel, (backup / rel).read_bytes())
    if meta.get("had_manifest") and (backup / MANIFEST).is_file():
        _write(root / MANIFEST, (backup / MANIFEST).read_bytes())
    else:
        (root / MANIFEST).unlink(missing_ok=True)
    # The servers those files belong to need the same rebuild back.
    _record_changed(root, (meta.get("added") or []) + (meta.get("existed") or []))
    shutil.rmtree(backup, ignore_errors=True)
    if (root / BACKUP_DIR).is_dir() and not any((root / BACKUP_DIR).iterdir()):
        (root / BACKUP_DIR).rmdir()
    return {"status": "undone", "to": meta.get("from") or "unknown", "from": meta.get("to")}


def _prune(folder: Path) -> None:
    for old in sorted(p for p in folder.glob("*") if p.is_dir())[:-KEEP_BACKUPS]:
        shutil.rmtree(old, ignore_errors=True)


# ── After an update: rebuild what changed ──────────────────────────────
def _run(cmd: list[str], cwd: Path) -> None:
    tool = shutil.which(cmd[0])
    if not tool:
        raise UpdateError(f"{cmd[0]} is not on this computer's PATH, so {cwd.name} could not be rebuilt")
    p = subprocess.run([tool] + cmd[1:], cwd=str(cwd), capture_output=True, text=True,
                       encoding="utf-8", errors="replace", stdin=subprocess.DEVNULL, timeout=600)
    if p.returncode != 0:
        last = [ln for ln in ((p.stdout or "") + (p.stderr or "")).splitlines() if ln.strip()]
        raise UpdateError(f"{' '.join(cmd)} failed in mcp-servers/{cwd.name}: {(last[-1] if last else '')[:200]}")


def rebuild_plan(root: Path, changed) -> list[tuple[str, list[list[str]]]]:
    """[(server, [commands])] for bundled servers this update changed AND this
    attendee already built. A server they never set up is left for setup."""
    by_server: dict[str, set[str]] = {}
    for rel in changed:
        parts = PurePosixPath(rel).parts
        if len(parts) > 2 and parts[0] == "mcp-servers":
            by_server.setdefault(parts[1], set()).add("/".join(parts[2:]))
    plan = []
    for name, files in sorted(by_server.items()):
        d = root / "mcp-servers" / name
        cmds: list[list[str]] = []
        if (d / "package.json").is_file() and ((d / "node_modules").is_dir() or (d / "dist").is_dir()):
            if {"package.json", "package-lock.json"} & files or not (d / "node_modules").is_dir():
                cmds.append(["npm", "ci", "--silent", "--no-audit", "--no-fund"])
            with contextlib.suppress(Exception):
                if "build" in json.loads((d / "package.json").read_text(encoding="utf-8")).get("scripts", {}):
                    cmds.append(["npm", "run", "build", "--silent"])
        elif (d / "pyproject.toml").is_file() and (d / ".venv").is_dir():
            if {"pyproject.toml", "uv.lock"} & files:
                cmds.append(["uv", "sync", "--quiet", "--compile-bytecode", "--python", "3.13"])
        elif (d / "requirements.txt").is_file() and (d / ".venv").is_dir():
            if "requirements.txt" in files:
                cmds.append(["uv", "pip", "install", "--quiet", "--compile-bytecode", "-r", "requirements.txt",
                             "--python", ".venv"])
        if cmds:
            plan.append((name, cmds))
    return plan


def _syntax_check(root: Path) -> None:
    """A release whose helpers do not even parse must not stay installed."""
    for py in sorted(list((root / "lib").glob("*.py")) + list((root / "scripts").glob("*.py"))):
        try:
            compile(py.read_bytes(), str(py), "exec")
        except (SyntaxError, ValueError) as e:
            raise UpdateError(f"{py.relative_to(root).as_posix()} does not parse ({e})") from e
    bash = shutil.which("bash")
    if bash:
        for sh in sorted(list(root.glob("*.sh")) + list((root / "lib").glob("*.sh"))):
            p = subprocess.run([bash, "-n", str(sh)], capture_output=True, text=True, stdin=subprocess.DEVNULL)
            if p.returncode != 0:
                raise UpdateError(f"{sh.relative_to(root).as_posix()} does not parse")


def after(root: Path = ROOT) -> list[str]:
    try:
        changed = [ln for ln in (root / CHANGED).read_text(encoding="utf-8").splitlines() if ln.strip()]
    except OSError:
        changed = []
    _syntax_check(root)
    done = []
    for name, cmds in rebuild_plan(root, changed):
        for cmd in cmds:
            _run(cmd, root / "mcp-servers" / name)
        done.append(name)
    (root / CHANGED).unlink(missing_ok=True)
    return done


def main() -> int:
    for stream in (sys.stdout, sys.stderr):
        with contextlib.suppress(AttributeError, ValueError):
            stream.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description="Update this copy to the latest connections kit release.")
    ap.add_argument("--check", action="store_true", help="only say whether a newer release exists")
    ap.add_argument("--undo", action="store_true", help="put back the version from before the last update")
    ap.add_argument("--after", action="store_true", help="rebuild the bundled servers the last update changed")
    args = ap.parse_args()
    try:
        if args.undo:
            r = undo()
            print(f"[update] Put back version {r['to']} (was {r['from']}). Run scripts/update.py --after next.")
        elif args.after:
            done = after()
            print("[update] Rebuilt: " + ", ".join(done) + ". Quit and reopen the Claude Code app to use them."
                  if done else "[update] Nothing to rebuild.")
        elif args.check:
            tag, have = latest_tag(), current_version(ROOT)
            newer = not have or parse_version(have) < parse_version(tag)
            print(f"[update] Latest release: {tag.lstrip('v')}; this copy: {have or 'unknown'}"
                  + (". An update is available." if newer else ". Up to date."))
        else:
            r = update()
            if r["status"] == "current":
                print(f"[update] Already on the latest release ({r['to']}). Nothing to do.")
            else:
                print(f"[update] Updated {r['from']} -> {r['to']}: {len(r['added'])} new file(s), "
                      f"{len(r['removed'])} removed. Kept: every .env, .cache/, built servers and "
                      f"everything registered in Claude Code.")
                if r["edited"]:
                    print(f"[update] You had edited {len(r['edited'])} kit file(s); your versions are saved in "
                          f"{r['backup']}: {', '.join(r['edited'][:10])}")
                print("[update] Next: scripts/update.py --after (rebuilds any bundled server that changed). "
                      "To go back: scripts/update.py --undo")
    except UpdateError as e:
        print(f"[update] {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
