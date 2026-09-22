---
server: none
slot: system
required: yes
env: []
official_mcp: none
---

# Python via uv: the runtime the Python MCP servers run on

## 1. What it is
The Turno, AirROI and Kie MCP servers are written in Python. uv is a small tool from Astral that installs Python for you and runs each server in its own clean environment, so you never fight with whatever Python your computer already has (or does not have). Everything in this kit runs Python through `uv run`.

## 2. Required, cost, gate
Required. Free. No account, no email. Python 3.11 is the floor; we install 3.13.

## 3. Path A: API key
_None for this connector._ Install uv, then let uv install Python:

**macOS (Terminal):**
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```
Open a NEW Terminal window afterwards.

**Windows (open "Windows PowerShell", not "(x86)", not CMD):**
```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```
Open a NEW PowerShell window afterwards.

**Then, on both:**
```bash
uv python install 3.13
```

**Skip typing `python` on Windows.** On a fresh Windows machine that opens the Microsoft Store instead of Python. Nothing in the summit kit needs it; every Python server runs with `uv run`.

## 4. Path B: official MCP
_None for this connector._

## 5. Verify
In a NEW terminal window:
```bash
uv --version
uv run --python 3.13 python -c "import sys; print(sys.version)"
```
The first prints `uv 0.x.y`. The second prints a line starting with `3.13.`. If both do, you are done.

## 6. Troubleshooting
- **`Python was not found; run without arguments to install from the Microsoft Store` (Windows):** ignore it. That is the Store stub, and we use `uv run`, which never touches it. If you want a plain `python` command anyway: Settings > Manage App Execution Aliases > turn `python.exe` and `python3.exe` off.
- **`uv: command not found` or `'uv' is not recognized` right after installing:** the installer updates your shell profile, and the window you had open does not know yet. Open a NEW window.
- **Windows install fails with an execution policy error:** you used an older tutorial's `powershell -c "irm ..."` form, which fails on the default Restricted policy. Use the `-ExecutionPolicy ByPass` line in section 3.
- **Prefer a package manager:** `brew install uv` on Mac, `winget install --id=astral-sh.uv -e` on Windows. Same result.
- **Updating later:** `uv self update`. To see which Pythons uv has: `uv python list`.

## 7. Sources
docs.astral.sh/uv/getting-started/installation, docs.astral.sh/uv/guides/install-python, docs.python.org/3/using/windows.html (read 2026-09-21).
