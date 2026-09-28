---
server: none
slot: system
required: yes
env: []
official_mcp: none
---

# Python via uv: the runtime the Python MCP servers run on

## 1. What it is
The Turno, AirROI and Kie MCP servers are written in Python. uv is a small tool from Astral that installs Python for you and runs each server in its own clean environment, so you never fight with whatever Python your computer already has (or does not have). Everything in this kit runs Python through `uv run`; nothing ever calls a bare `python` or `python3`.

Claude installs both for you from inside the Claude Code desktop app. There is no separate PowerShell or Terminal window and nothing to type.

## 2. Required, cost, gate
Required. Free. No account, no email. Python 3.11 is the floor; the kit installs 3.13.

## 3. Path A: API key
_None for this connector._ Claude runs the kit's installer in Phase 0 of `CONNECTIONS.md`:
```bash
bash "$BUNDLE/install-tools.sh"
```
It prints one line per tool (Git, Node.js, uv, Python 3.13), installs whatever is missing, and ends with one of three things: `All set`, `RESTART NEEDED` (it installed something, or found uv or Node already on disk from a by-hand install this app has not seen yet; either way the app only sees a tool after it is quit and reopened, so Claude asks for that one restart and then picks up where it left off), or a ❌ line that names the file to open.

What it does for uv and Python, in case you are curious or want to do it by hand. Every line runs in Claude's Bash tool; on Windows that is Git Bash, never PowerShell and never CMD.

**Windows (Git Bash):**
```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "irm https://astral.sh/uv/install.ps1 | iex"
UV_PYTHON_INSTALL_DIR="$USERPROFILE\.uv\python" "$HOME/.local/bin/uv.exe" python install 3.13
setx UV_PYTHON_INSTALL_DIR "$USERPROFILE\.uv\python"
```
uv lands in `%USERPROFILE%\.local\bin`. Python lands under `%USERPROFILE%\.uv\python`, on purpose: see section 6 for why the default location does not work inside the desktop app. `setx` makes that location stick for every later launch; it takes effect after the app restarts.

**macOS:**
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
"$HOME/.local/bin/uv" python install 3.13
```

**Skip typing `python` on Windows.** On a fresh Windows machine `python` and `python3` are Microsoft Store shims that open the Store instead of running anything. Nothing in the summit kit needs them; every Python call is `uv run --no-project --python 3.13 python ...`.

## 4. Path B: official MCP
_None for this connector._

## 5. Verify
```bash
bash "$BUNDLE/install-tools.sh" --check
```
Four ✅ lines and `All set`. The scoreboard shows the same as two rows, `uv (Python)` and `Python 3.13 (uv)`; either one ❌ means run the installer again (without `--check`). The `Python 3.13 (uv)` row asks uv whether it can find 3.13 from where the scoreboard runs; it never downloads anything.

## 6. Troubleshooting
- **`error: Missing expected target directory for Python minor version link at C:\Users\<you>\AppData\Roaming\uv\python\cpython-3.13...` (Windows):** the reason the kit puts Python under the profile. The Claude Code desktop app is a Microsoft Store (MSIX) app, and Windows silently redirects anything such an app writes under `AppData\Roaming` (and `AppData\Local`) into the app's own sandbox folder. uv's default Python home is `AppData\Roaming\uv\python`, and uv 0.11.17 and newer trip over the redirect when they create the version link (astral-sh/uv issue 19622; reproduced with 0.12.19 on 2026-09-28, while the same install under `%USERPROFILE%\.uv\python` works). `install-tools.sh` already sets `UV_PYTHON_INSTALL_DIR` there. If you installed uv yourself and hit this, run the three Windows lines in section 3, then quit and reopen the app.
- **`❌ uv` on the scoreboard right after uv was installed, or `uv: command not found` in the next command (Windows):** the app's PATH is fixed when the app starts, so a tool installed mid-session stays invisible until the app is quit and reopened. That is the `RESTART NEEDED` line from the installer; do that restart, then say "Set up my connections" again.
- **`Python was not found; run without arguments to install from the Microsoft Store` (Windows):** something called the Store shim. Nothing in the kit does; if you were testing by hand, use `uv run --no-project --python 3.13 python` instead. To get rid of the shim entirely: Settings > Apps > Advanced app settings > App execution aliases > turn `python.exe` and `python3.exe` off.
- **Windows install fails with an execution policy error:** the line in section 3 carries `-ExecutionPolicy Bypass` for exactly this; an older tutorial's `powershell -c "irm ..."` form does not.
- **You installed uv with winget instead:** fine. It lives in `%LOCALAPPDATA%\Microsoft\WinGet\Links` and the installer finds it there. The Python location rule in the first bullet still applies.
- **Updating later:** `uv self update`. To see which Pythons uv has: `uv python list`.

## 7. Sources
docs.astral.sh/uv/getting-started/installation, docs.astral.sh/uv/guides/install-python, docs.astral.sh/uv/configuration/environment (UV_PYTHON_INSTALL_DIR, UV_PYTHON_DOWNLOADS), github.com/astral-sh/uv/issues/19622, learn.microsoft.com "Understanding how packaged desktop apps run on Windows" (file system virtualization), docs.python.org/3/using/windows.html. Read 2026-09-28; the MSIX failure and the profile-folder fix reproduced the same day on the Windows laptop.
