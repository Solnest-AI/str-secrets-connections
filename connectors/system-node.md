---
server: none
slot: system
required: yes
env: []
official_mcp: none
---

# Node.js: the runtime the JavaScript MCP servers run on

## 1. What it is
Node.js runs JavaScript outside a browser. The Firecrawl, Supabase, Hospitable and PriceLabs MCP servers are JavaScript, so they need Node to start. `npx`, which ships with Node, is what Claude Code uses to download and launch them.

## 2. Required, cost, gate
Required. Free. No account, no email. Install the LTS release (24 today). Anything older than 20 will not run the servers.

## 3. Path A: API key
_None for this connector._ Install instead:

**macOS:** download the LTS `.pkg` from https://nodejs.org/en/download and run it. If you already have Homebrew, this works too:
```bash
brew install node
```
Skip `brew install node@24`. That formula is keg-only, which means `node` never lands on your PATH and nothing can find it.

**Windows (open "Windows PowerShell", not "(x86)", not CMD):**
```powershell
winget install OpenJS.NodeJS.LTS
```
Open a NEW PowerShell window afterwards. If the first `npm` or `npx` command says `npm.ps1 cannot be loaded because running scripts is disabled`:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
Then try again in the same window.

## 4. Path B: official MCP
_None for this connector._

## 5. Verify
In a NEW terminal window:
```bash
node -v
npx -v
```
`node -v` prints `v20` or newer (`v24.x` is what installs today). `npx -v` prints a version number. Both must work; the servers are launched through `npx`.

## 6. Troubleshooting
- **`npm.ps1 cannot be loaded because running scripts is disabled` (Windows):** run the `Set-ExecutionPolicy` line in section 3, or call `npm.cmd` and `npx.cmd` instead of `npm` and `npx`.
- **A server shows `Failed to connect` the first time:** the first `npx` start downloads the package and can run past the 30 second startup timeout. Wait a moment and run `claude mcp list` again; it usually connects on the second try.
- **`command not found: node` on Mac after a Homebrew install:** you ran `brew install node@24`. Run `brew install node` instead.
- **`node -v` still prints the old version after installing:** you are in the window you had open before the install. Open a NEW one.
- **Which version is right:** v24 is the LTS today. v26 takes over as LTS on 2026-10-28. Either one works; the floor is v20.

## 7. Sources
nodejs.org/en/download, code.claude.com/docs/en/troubleshoot-install, github.com/nodejs/Release schedule (read 2026-09-21).
