---
server: none
slot: system
required: yes
env: []
official_mcp: none
---

# Node.js: the runtime the JavaScript MCP servers run on

## 1. What it is
Node.js runs JavaScript outside a browser. The Supabase, Hospitable and PriceLabs MCP servers (and any PMS server Claude builds in TypeScript) are JavaScript, so they need Node to start. Claude installs it for you from inside the Claude Code desktop app; there is no separate window to open.

## 2. Required, cost, gate
Required. Free. No account, no email. Install the LTS release (24 today). Anything older than 20 will not run the servers.

## 3. Path A: API key
_None for this connector._ Claude runs the kit's installer in Phase 0 of `CONNECTIONS.md`:
```bash
bash "$BUNDLE/install-tools.sh"
```
On Windows it installs Node LTS through winget. Windows shows one permission prompt (User Account Control) because Node installs for the whole machine: click **Yes**. On a Mac it uses Homebrew when Homebrew is there. Either way the installer ends with `RESTART NEEDED`: the app only sees a new tool after it is quit and reopened, so Claude asks for that one restart and carries on from there.

By hand, if you ever need it, from Claude's Bash tool (Git Bash on Windows):
```bash
winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements
```
On a Mac without Homebrew: download the LTS `.pkg` from https://nodejs.org/en/download and run it. Skip `brew install node@24`; that formula is keg-only, so `node` never lands on your PATH.

## 4. Path B: official MCP
_None for this connector._

## 5. Verify
```bash
bash "$BUNDLE/install-tools.sh" --check
```
The Node.js line reads `✅ Node.js v24.x` (v20 or newer is fine). The scoreboard shows the same as its `Node.js` row.

## 6. Troubleshooting
- **`❌ Node.js` right after it was installed:** the app's PATH is fixed when the app starts. Quit the Claude Code desktop app fully (not just the window), open it again, say "Set up my connections". The installer says exactly this with its `RESTART NEEDED` line.
- **`winget` is not recognized (Windows):** rare on Windows 11. Install App Installer from the Microsoft Store, or download the Node LTS installer from https://nodejs.org/en/download, run it with every default, then restart the app.
- **`npm.ps1 cannot be loaded because running scripts is disabled`:** only happens in PowerShell, which Claude's Bash tool never uses. If you are in a PowerShell window of your own, run `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser` there, or call `npm.cmd` and `npx.cmd`.
- **A server launched through `npx` shows `Failed to connect` the first time:** `npx -y <package>` checks the npm registry on every start, 15 to 18 seconds even with a warm cache (measured 2026-09-28), and the desktop app gives a server 30 seconds. That is why the kit installs the Supabase server once into `mcp-servers/supabase/` and registers `node .../dist/cli.js` directly (under a second warm). If a build-from-research server of yours is registered through `npx`, do the same: `npm install` it into a folder and register the package's `bin` file through `node`.
- **`command not found: node` on Mac after a Homebrew install:** you ran `brew install node@24`. Run `brew install node` instead.
- **Which version is right:** v24 is the LTS today. v26 takes over as LTS on 2026-10-28. Either one works; the floor is v20.

## 7. Sources
nodejs.org/en/download, learn.microsoft.com/windows/package-manager/winget, code.claude.com/docs/en/troubleshoot-install, github.com/nodejs/Release schedule (read 2026-09-28).
