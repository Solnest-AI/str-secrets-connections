---
server: none
slot: system
required: yes
env: []
official_mcp: none
---

# Git: version control, and on Windows the Bash that Claude Code runs on

## 1. What it is
Git is the version-control tool the software world runs on. You will not have to learn it. It is in this kit for two reasons. On Windows, Git for Windows ships Git Bash, and Git Bash is what gives Claude Code its Bash tool: without it Claude falls back to PowerShell, tries Linux syntax first, and wastes tokens on every command. On Mac, Git is only needed for updates ("Update my connections") and for Claude Code desktop worktrees.

## 2. Required, cost, gate
Required on both. Free. No account, no plan gate, no email.

## 3. Path A: API key
_None for this connector._ Install instead:

**macOS (Terminal):**
```bash
xcode-select --install
```
A dialog pops up. Click Install. That downloads Apple's command-line tools, which include Git. If you already have Homebrew, `brew install git` works too.

**Windows (open "Windows PowerShell", not "(x86)", not CMD):**
```powershell
winget install --id Git.Git -e --source winget
```
If an installer window appears, keep every default. The page that matters is PATH: leave it on "Git from the command line and also from 3rd-party software". Open a NEW PowerShell window afterwards, then:
```powershell
where.exe git
```
It should print `C:\Program Files\Git\cmd\git.exe`.

**If Claude Code still cannot find Git Bash** (it keeps answering in PowerShell): create or edit `%USERPROFILE%\.claude\settings.json` so it contains:
```json
{"env":{"CLAUDE_CODE_GIT_BASH_PATH":"C:\\Program Files\\Git\\bin\\bash.exe"}}
```
It must point at `bash.exe`, not `git-bash.exe`. Restart Claude Code.

## 4. Path B: official MCP
_None for this connector._

## 5. Verify
In a NEW terminal window:
```bash
git --version
```
Prints `git version 2.x` or newer (2.50 on a fresh Mac, 2.55 on Windows today). That is the whole test.

## 6. Troubleshooting
- **`winget` finished but `git` is not recognized (Windows):** winget under PowerShell 5.1 sometimes needs the window reopened twice. Close every PowerShell window, open a fresh one, run `where.exe git` again.
- **`winget` itself is not recognized (Windows):** download the installer from https://git-scm.com/downloads/win and run it, keeping every default.
- **Claude Code on Windows keeps using PowerShell commands:** Git Bash is not being detected. Set `CLAUDE_CODE_GIT_BASH_PATH` as shown in section 3 and restart Claude Code.
- **Mac: `xcode-select --install` says the tools are already installed:** you are done. Run `git --version` to confirm.

## 7. Sources
git-scm.com/install/mac, git-scm.com/install/windows, code.claude.com/docs/en/setup (read 2026-09-21).
