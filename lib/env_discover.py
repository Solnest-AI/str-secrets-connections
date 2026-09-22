#!/usr/bin/env python3
"""Find keys the attendee already has on this computer and carry them into .env.

    python3 lib/env_discover.py [--env .env] [--apply] [--only VAR ...] [--extra-dir PATH ...]
    python3 lib/env_discover.py --env .env --no-discover     # demo mode: turn the search off
    python3 lib/env_discover.py --env .env --discover        # turn it back on

Demo mode (--no-discover) drops a marker at <env folder>/.cache/no-discover and every
later run of this helper stops right there with "discovery is off", searching nothing,
until --discover removes it. It exists for recordings and live walkthroughs on a machine
that already holds the keys (Ryan's, a coach's), where the search would find everything
and leave nothing to paste on camera. It only silences this helper: servers already in
~/.claude.json still show on the scoreboard.

Where it looks (read-only, never prints a value):
  * every KEY=VALUE .env-style file under the usual kit folders: Desktop,
    Documents, Downloads, the home folder itself (depth-limited), plus any
    SKILL_PATH_* folder already in .env and any --extra-dir
  * ~/.claude.json: env vars and auth headers of registered MCP servers,
    top-level and per-project
  * Claude Desktop's claude_desktop_config.json (Mac and Windows locations)

What it reports: one line per blank var in .env, either
  FOUND    VAR  <- <where>          (value carried over with --apply)
  not found VAR
Values never reach stdout. With --apply, a found value fills the blank line
in .env (only blank lines; a filled line is never overwritten). Claude then
runs that connector's WORKS probe, because a found key can be stale.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

VAR_RE = re.compile(r"^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$")

# other names the same secret goes by in other Solnest kits and vendor docs
ALIASES = {
    "HOSPITABLE_API_KEY": ["HOSPITABLE_TOKEN", "HOSPITABLE_PAT", "HOSPITABLE_ACCESS_TOKEN"],
    "PRICELABS_API_KEY": ["PRICELABS_KEY", "PRICELABS_TOKEN"],
    "AIRROI_API_KEY": ["AIRROI_KEY", "AIRROI_TOKEN"],
    "GEMINI_API_KEY": ["GOOGLE_API_KEY", "GOOGLE_GENAI_API_KEY", "GOOGLE_GEMINI_API_KEY"],
    "FIRECRAWL_API_KEY": ["FIRECRAWL_KEY"],
    "KIE_API_KEY": ["KIE_KEY", "KIEAI_API_KEY"],
    "SUPABASE_ACCESS_TOKEN": ["SUPABASE_PAT", "SUPABASE_MANAGEMENT_TOKEN"],
    "SUPABASE_PROJECT_REF": ["SUPABASE_REF", "SUPABASE_PROJECT_ID"],
    "TURNO_API_TOKEN": ["TURNO_TOKEN", "TURNO_SECRET_KEY", "TURNO_API_KEY"],
    "TURNO_PARTNER_ID": ["TURNO_PARTNER"],
    "RANKBREEZE_MCP_URL": ["RANKBREEZE_URL"],
    "HOSTAWAY_API_KEY": ["HOSTAWAY_SECRET", "HOSTAWAY_API_SECRET"],
    "HOSTAWAY_ACCOUNT_ID": ["HOSTAWAY_CLIENT_ID"],
    "OWNERREZ_TOKEN": ["OWNERREZ_API_TOKEN", "OWNERREZ_PAT"],
    "LODGIFY_API_KEY": ["LODGIFY_KEY", "LODGIFY_TOKEN"],
    "UPLISTING_API_KEY": ["UPLISTING_KEY", "UPLISTING_TOKEN"],
    "BEYOND_TOKEN": ["BEYOND_API_KEY", "BEYOND_PAT"],
    "SMOOBU_API_KEY": ["SMOOBU_KEY"],
    "GUESTY_CLIENT_ID": ["GUESTY_ID"],
    "GUESTY_CLIENT_SECRET": ["GUESTY_SECRET"],
    "BREEZEWAY_CLIENT_ID": ["BREEZEWAY_ID"],
    "BREEZEWAY_CLIENT_SECRET": ["BREEZEWAY_SECRET"],
}
# MCP server name -> how its secret is stored in ~/.claude.json
MCP_HINTS = {
    "firecrawl": [("header", "Authorization", "Bearer ", "FIRECRAWL_API_KEY")],
    "airroi-official": [("header", "X-API-KEY", "", "AIRROI_API_KEY")],
    "rankbreeze": [("url", "", "", "RANKBREEZE_MCP_URL")],
    "supabase-revenue-manager": [("arg", "--project-ref=", "", "SUPABASE_PROJECT_REF")],
}
SKIP_DIRS = {"node_modules", ".venv", "venv", ".git", "dist", "build", "__pycache__", "Library", ".Trash", "Applications", ".cache", ".npm", ".cargo", "site-packages",
             "tests", "test", "fixtures", "fixture", "examples", "example", "samples"}
# never a real key: templates, examples, samples
SKIP_FILE_WORDS = ("example", "template", "sample", "dist")
ENV_NAMES = {".env", ".env.local", ".env.production", "env", ".envrc"}
MAX_DEPTH = 4
MAX_FILES = 20000


def home_roots(env_path: str, extra: list[str]) -> list[Path]:
    home = Path.home()
    roots = [home / "Desktop", home / "Documents", home / "Downloads", home]
    for k, v in read_env(env_path).items():
        if k.startswith("SKILL_PATH_") and v:
            roots.append(Path(v).expanduser())
    roots.extend(Path(p).expanduser() for p in extra)
    seen, out = set(), []
    for r in roots:
        try:
            rp = r.resolve()
        except OSError:
            continue
        if rp.is_dir() and rp not in seen:
            seen.add(rp)
            out.append(rp)
    return out


def read_env(path: str | Path) -> dict[str, str]:
    out: dict[str, str] = {}
    try:
        with open(path, encoding="utf-8", errors="ignore") as fh:
            for line in fh:
                if line.lstrip().startswith("#"):
                    continue
                m = VAR_RE.match(line)
                if m:
                    v = m.group(2).strip().strip('"').strip("'")
                    if v:
                        out[m.group(1)] = v
    except OSError:
        pass
    return out


def walk_env_files(roots: list[Path], own_env: Path) -> list[Path]:
    found: list[Path] = []
    seen: set[Path] = set()
    count = 0
    for root in roots:
        base_depth = len(root.parts)
        for dirpath, dirnames, filenames in os.walk(root, topdown=True, onerror=lambda e: None):
            depth = len(Path(dirpath).parts) - base_depth
            dirnames[:] = [d for d in dirnames if d == ".claude" or (d not in SKIP_DIRS and not d.startswith("."))]
            if depth >= MAX_DEPTH:
                dirnames[:] = []
            for fn in filenames:
                count += 1
                if count > MAX_FILES:
                    return found
                if (fn in ENV_NAMES or fn.endswith(".env")) and not any(w in fn.lower() for w in SKIP_FILE_WORDS):
                    p = Path(dirpath) / fn
                    rp = p.resolve()
                    if rp != own_env.resolve() and rp not in seen:
                        seen.add(rp)
                        found.append(p)
    return found


def server_env_files(spec: dict, own_env: Path | None = None) -> list[Path]:
    """.env files a registered stdio server would read: beside its script, one and two
    levels up (dist/index.js -> repo root), and in its cwd.

    Only ABSOLUTE paths count. A package name like "@supabase/mcp-server-supabase@latest"
    has a slash in it but is not a path; treating it as one walked ".", ".." and "../.."
    relative to the current directory and read whatever .env sat there (found 2026-09-22:
    it picked up this kit's own .env and labelled it as the Supabase server's). The home
    folder is left out too: ~/.env is found by the ordinary walk and reported under its
    own path, not as some unrelated server's."""
    home = Path.home()
    dirs: list[Path] = []
    for a in spec.get("args") or []:
        if not isinstance(a, str):
            continue
        cand = Path(a).expanduser()
        if not cand.is_absolute():
            continue
        if a.endswith((".js", ".py", ".mjs", ".cjs")) or os.path.sep in a:
            d = cand.parent
            dirs += [d, d.parent, d.parent.parent]
        if cand.is_dir():
            dirs.append(cand)
    cwd = spec.get("cwd")
    if isinstance(cwd, str) and Path(cwd).expanduser().is_absolute():
        dirs.append(Path(cwd).expanduser())
    out, seen = [], set()
    for d in dirs:
        if d == home or d == Path("/"):
            continue
        for fn in (".env", ".env.local"):
            p = d / fn
            if own_env is not None and p.resolve() == own_env.resolve():
                continue
            if p.is_file() and p not in seen and not any(w in str(p).lower() for w in ("/tests/", "/fixtures/", "example", "template")):
                seen.add(p)
                out.append(p)
    return out


def spotlight_env_files() -> list[Path]:
    """macOS only: every indexed .env file in the home folder, instantly, including
    folders the walker cannot list (Downloads under TCC)."""
    if sys.platform != "darwin":
        return []
    import subprocess
    try:
        res = subprocess.run(["mdfind", "-onlyin", str(Path.home()), "kMDItemFSName == '.env'"],
                             capture_output=True, text=True, timeout=20)
    except (OSError, subprocess.SubprocessError):
        return []
    out = []
    for line in res.stdout.splitlines():
        p = Path(line.strip())
        low = str(p).lower()
        if not p.is_file():
            continue
        if any(f"/{d}/" in low for d in SKIP_DIRS) or any(w in p.name.lower() for w in SKIP_FILE_WORDS):
            continue
        out.append(p)
    return out


def claude_json_candidates(own_env: Path | None = None) -> dict[str, tuple[str, str]]:
    """VAR -> (value, where) pulled from registered MCP servers."""
    out: dict[str, tuple[str, str]] = {}
    paths = [Path.home() / ".claude.json"]
    cfg_mac = Path.home() / "Library" / "Application Support" / "Claude" / "claude_desktop_config.json"
    cfg_win = Path(os.environ.get("APPDATA", "")) / "Claude" / "claude_desktop_config.json" if os.environ.get("APPDATA") else None
    paths += [p for p in (cfg_mac, cfg_win) if p and p.is_file()]
    for path in paths:
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        servers: dict[str, dict] = {}
        servers.update(data.get("mcpServers") or {})
        for proj in (data.get("projects") or {}).values():
            if isinstance(proj, dict):
                servers.update(proj.get("mcpServers") or {})
        where = f"{path.name} (registered MCP servers)"
        for name, spec in servers.items():
            if not isinstance(spec, dict):
                continue
            for k, v in (spec.get("env") or {}).items():
                if isinstance(v, str) and v and k not in out:
                    out[k] = (v, f"{where}: {name}")
            for kind, key, prefix, var in MCP_HINTS.get(name, []):
                if kind == "header":
                    hv = (spec.get("headers") or {}).get(key, "")
                    if isinstance(hv, str) and hv.startswith(prefix) and hv[len(prefix):]:
                        out.setdefault(var, (hv[len(prefix):], f"{where}: {name}"))
                elif kind == "url":
                    u = spec.get("url", "")
                    if isinstance(u, str) and u:
                        out.setdefault(var, (u, f"{where}: {name}"))
                elif kind == "arg":
                    for a in spec.get("args") or []:
                        if isinstance(a, str) and a.startswith(key) and a[len(key):]:
                            out.setdefault(var, (a[len(key):], f"{where}: {name}"))
            # stdio servers usually keep their key in a .env beside the script (or one level up)
            for cand in server_env_files(spec, own_env):
                for k, v in read_env(cand).items():
                    out.setdefault(k, (v, f"{where}: {name} -> {cand.parent.name}/{cand.name}"))
            kie_env = (spec.get("env") or {}).get("KIE_ENV_PATH")
            if isinstance(kie_env, str) and os.path.isfile(kie_env):
                for k, v in read_env(kie_env).items():
                    out.setdefault(k, (v, f"{where}: {name} -> {Path(kie_env).name}"))
    return out


def marker_path(env_path: str) -> Path:
    """<env folder>/.cache/no-discover: present means the search is off for this kit folder."""
    return Path(env_path).resolve().parent / ".cache" / "no-discover"


def set_discovery(env_path: str, on: bool) -> str:
    """Create or remove the marker. Returns the one-line status Claude prints."""
    m = marker_path(env_path)
    if on:
        try:
            m.unlink()
        except FileNotFoundError:
            pass
        return "discovery ON: the search for keys already on this computer runs again from here"
    m.parent.mkdir(parents=True, exist_ok=True)
    try:
        os.chmod(m.parent, 0o700)
    except OSError:
        pass
    m.write_text("demo mode: env_discover.py searches nothing while this file exists\n", encoding="utf-8")
    return "discovery OFF (demo mode): this computer is not searched for keys; every key gets pasted by hand. --discover turns it back on"


def fill_blank(env_path: str, var: str, value: str) -> bool:
    """Replace `VAR=` with `VAR=value` (blank line only). Returns True if written."""
    p = Path(env_path)
    lines = p.read_text(encoding="utf-8").splitlines()
    for i, line in enumerate(lines):
        if line == f"{var}=":
            lines[i] = f"{var}={value}"
            p.write_text("\n".join(lines) + "\n", encoding="utf-8")
            try:
                os.chmod(p, 0o600)
            except OSError:
                pass
            return True
    return False


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--env", default=".env")
    ap.add_argument("--apply", action="store_true", help="write found values into blank lines of .env")
    ap.add_argument("--only", nargs="*", default=None, help="limit to these var names")
    ap.add_argument("--extra-dir", nargs="*", default=[], help="more folders to search")
    sw = ap.add_mutually_exclusive_group()
    sw.add_argument("--no-discover", action="store_true", help="demo mode: turn the search off for this kit folder and exit")
    sw.add_argument("--discover", action="store_true", help="turn the search back on and exit")
    a = ap.parse_args()

    # the switch works before .env exists (Phase 0), so it comes ahead of the file check
    if a.no_discover or a.discover:
        print(set_discovery(a.env, on=a.discover))
        return 0
    if marker_path(a.env).is_file():
        print("discovery is off for this folder (demo mode): nothing searched, nothing copied. Run with --discover to turn it back on")
        return 0

    if not os.path.isfile(a.env):
        print(f"no {a.env} yet; generate it first (lib/env_make.py)", file=sys.stderr)
        return 2
    own = Path(a.env)
    blank = []
    for line in own.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^([A-Z][A-Z0-9_]*)=$", line)
        # STACK_* are answers, SKILL_PATH_* come on summit morning, and two Supabase/Turno lines are Claude's to fill
        if m and not m.group(1).startswith(("STACK_", "SKILL_PATH_")) and m.group(1) not in ("TURNO_ENV", "SUPABASE_DB_PASSWORD"):
            blank.append(m.group(1))
    if a.only:
        blank = [v for v in blank if v in set(a.only)]
    if not blank:
        print("nothing blank to look for")
        return 0

    # 1. registered MCP servers
    cands: dict[str, tuple[str, str]] = {}
    for k, (v, where) in claude_json_candidates(own).items():
        cands.setdefault(k, (v, where))
    # 2. .env files around the machine
    files = walk_env_files(home_roots(a.env, a.extra_dir), own)
    seen = {f.resolve() for f in files}
    for f in spotlight_env_files():
        if f.resolve() not in seen and f.resolve() != own.resolve():
            files.append(f)
            seen.add(f.resolve())
    for f in files:
        vals = read_env(f)
        for k, v in vals.items():
            cands.setdefault(k, (v, str(f)))

    found = 0
    for var in blank:
        names = [var] + ALIASES.get(var, [])
        hit = next(((cands[n][0], cands[n][1], n) for n in names if n in cands), None)
        if hit:
            value, where, as_name = hit
            note = "" if as_name == var else f" (stored there as {as_name})"
            if a.apply and fill_blank(a.env, var, value):
                print(f"FOUND     {var}  <- {where}{note}  (copied into .env, Claude will test it)")
            else:
                print(f"FOUND     {var}  <- {where}{note}")
            found += 1
        else:
            print(f"not found {var}")
    print(f"searched {len(files)} env file(s) and the registered MCP servers; {found} of {len(blank)} found")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
