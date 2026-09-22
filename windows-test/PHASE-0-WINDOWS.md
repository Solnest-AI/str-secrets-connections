# Windows Phase-0 test (Ryan, 2026-09-21)

Run top to bottom in a NEW "Windows PowerShell" window (not "(x86)", not CMD). Paste each block, then record what you saw in the RESULT line. Open a NEW window wherever it says so; PATH changes never reach an open window.

## 0. Baseline
```powershell
$PSVersionTable.PSVersion
git --version; node -v; uv --version; claude --version
```
RESULT: (paste output; "not recognized" lines are expected on a fresh machine)

## 1. Git for Windows
```powershell
winget install --id Git.Git -e --source winget
```
Close PowerShell. Open a NEW one.
```powershell
git --version
where.exe git
```
RESULT:

## 2. Claude Code (native installer, ~300 MB, looks frozen for minutes)
```powershell
irm https://claude.ai/install.ps1 | iex
```
Read the "Setup notes" it prints. Close PowerShell. Open a NEW one.
```powershell
claude --version
claude doctor
```
If `'claude' is not recognized`:
```powershell
$currentPath = [Environment]::GetEnvironmentVariable('PATH','User')
[Environment]::SetEnvironmentVariable('PATH', "$currentPath;$env:USERPROFILE\.local\bin", 'User')
```
then NEW window and retry.
RESULT (version, and whether PATH needed the fix):

## 3. Node.js 24 LTS
```powershell
winget install OpenJS.NodeJS.LTS
```
NEW window.
```powershell
node -v; npm -v; npx -v
```
If `npm.ps1 cannot be loaded because running scripts is disabled`:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
RESULT (versions, and whether the policy fix was needed):

## 4. uv + Python 3.13
```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```
NEW window.
```powershell
uv --version
uv python install 3.13
uv run --python 3.13 python -c "import sys; print(sys.version)"
```
RESULT:

## 5. Does Claude Code use Git Bash? (the load-bearing assumption)
```powershell
cd $env:USERPROFILE
claude
```
Inside Claude Code type: `run this in bash: echo "shell=$0 bash=$BASH_VERSION uname=$(uname -s)"` and press Enter. Approve the command.
RESULT (paste the echo line Claude reports; we need to see `bash=5.x` and `uname=MINGW64_NT...`):

## 6. `claude mcp add` under PowerShell 5.1 (the `--` bug)
Exit Claude Code (`/exit`). In the same PowerShell window:
```powershell
claude mcp add --transport stdio zz-test --scope user -- npx -y firecrawl-mcp
```
RESULT (either `Added stdio MCP server zz-test...` or `error: missing required argument 'commandOrUrl'`):

Now the same line from Git Bash. Open Git Bash (Start menu > Git Bash):
```bash
claude mcp add --transport stdio zz-test2 --scope user -- npx -y firecrawl-mcp
claude mcp list
claude mcp remove zz-test -s user; claude mcp remove zz-test2 -s user
```
RESULT (did the Git Bash add work; what status did `claude mcp list` show for zz-test2, "Connected" or "Failed"):

## 7. Path conversion and line endings (Git Bash)
Still in Git Bash:
```bash
mkdir -p "$HOME/Desktop/ssc path test" && printf 'console.log("ok")\n' > "$HOME/Desktop/ssc path test/x.js"
claude mcp add --transport stdio zz-path --scope user -- node "$HOME/Desktop/ssc path test/x.js"
claude mcp list | grep zz-path
cygpath -w "$HOME/Desktop/ssc path test/x.js"
claude mcp remove zz-path -s user
printf 'A=1\r\nB=2\r\n' > "$HOME/crlf.env"; file "$HOME/crlf.env"; rm "$HOME/crlf.env"
```
RESULT (paste the `claude mcp list` line for zz-path exactly: we need to see whether the path shows as `C:\Users\...` or `/c/Users/...`, and whether its status is Connected or Failed; also paste the `cygpath -w` line):

## 8. Send me
Paste the whole file back with every RESULT filled in. Screenshots welcome for anything weird.
