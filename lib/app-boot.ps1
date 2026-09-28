# Prints the Unix time the top-most Claude process above a given process started (the Claude
# Code desktop app, or a `claude` CLI in a terminal). Nothing when no such ancestor exists.
# Called by lib/app.sh on Windows. The walk starts from StartPid, which app.sh sets to
# $CLAUDE_PID (the session's own claude.exe; its parent is the app itself) when the
# environment has it. Starting from this PowerShell's own pid only works from a top-level
# shell: from a nested bash the chain runs into an MSYS process that has already exited and
# the walk stops short (2026-09-28). Git Bash's $$ is an MSYS pid, never usable here.
param([int]$StartPid = 0)
if ($StartPid -le 0) { $StartPid = $PID }
$p = Get-CimInstance Win32_Process -Filter "ProcessId=$StartPid"; $top = $null; $n = 0
while ($p -and $n -lt 20) {
  $n++
  if ($p.Name -match "^claude") { $top = $p }
  $pp = $p.ParentProcessId
  if (-not $pp -or $pp -eq $p.ProcessId) { break }
  $p = Get-CimInstance Win32_Process -Filter "ProcessId=$pp"
}
if ($top) { [DateTimeOffset]::new($top.CreationDate).ToUnixTimeSeconds() }
