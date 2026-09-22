---
server: none
slot: system
required: yes
env: []
official_mcp: none
---

# Claude Code: the app everything runs in

## 1. What it is
Anthropic's command-line coding agent. Every summit skill runs inside it. You are reading this inside it right now if setup started, which means it is installed; this file exists for the PDF and for re-installs.

## 2. Required, cost, gate
Required. Needs a paid claude.ai plan (Pro, Max, Team or Enterprise). The free plan does not include Claude Code. The installer downloads about 300 MB: do it at home, not at the venue.

## 3. Path A: API key
_None for this connector._ Install instead:

**macOS (Terminal):**
```bash
curl -fsSL https://claude.ai/install.sh | bash
```
Then open a NEW Terminal window and run `claude --version`. If you see `command not found: claude`:
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
```

**Windows (open "Windows PowerShell", not "(x86)", not CMD):**
```powershell
irm https://claude.ai/install.ps1 | iex
```
It looks frozen for a few minutes; that is the download. Read the "Setup notes" it prints. Then open a NEW PowerShell window and run `claude --version`. If you see `'claude' is not recognized`:
```powershell
$currentPath = [Environment]::GetEnvironmentVariable('PATH','User')
[Environment]::SetEnvironmentVariable('PATH', "$currentPath;$env:USERPROFILE\.local\bin", 'User')
```
Close and reopen PowerShell.

Wrong-window decoder: `'irm' is not recognized` means you are in CMD, not PowerShell. `A parameter cannot be found that matches parameter name 'fsSL'` means you pasted the Mac command into PowerShell.

**Sign in:** run `claude`, a browser opens, log in with your claude.ai account. If the browser does not open, press `c` to copy the link. If you get a 403 after logging in, your subscription is not active at claude.ai/settings.

**Desktop app users:** the Claude Code desktop app does not put `claude` on your PATH. Install the CLI with the command above anyway; both read the same config, so everything set up here shows up in the app.

## 4. Path B: official MCP
_None for this connector._

## 5. Verify
`claude --version` prints `2.1.x (Claude Code)` or newer. `claude doctor` runs clean.

## 6. Troubleshooting
- **Installer says success but `claude` is not found:** PATH was not updated (known issue #86999). Run the PATH fix above, then a new window.
- **Hangs at startup on a work laptop (Windows 10, domain-joined):** open issue #91881; `claude --version` works but `claude` hangs. Use a personal laptop for the summit.
- **`Illegal instruction` on launch:** CPU without AVX (very old AMD, some VMs). No fix; use another machine.
- **Windows: typing `claude` opens the Claude chat app instead:** an old Claude Desktop registered `Claude.exe` ahead on PATH. Update Claude Desktop.
- **Skip WSL, npm, or any tutorial that mentions `setx SHELL`.** Those are 2025 instructions. The one-liners above are the only supported path.

## 7. Sources
code.claude.com/docs/en/setup, /terminal-guide, /troubleshoot-install, /authentication, /desktop-quickstart (read 2026-09-21). GitHub anthropics/claude-code #86999, #91881, #87060, #66041.
