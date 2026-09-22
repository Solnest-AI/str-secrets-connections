---
server: <name or none>
slot: <system|pms|pricing|ranking|ops|market|ads|ai|web|db>
required: <yes|one-of|optional>
env: [VAR_ONE, VAR_TWO]
official_mcp: <https://... or none>
---

# <Vendor>: <one-line what it is>

## 1. What it is
<One paragraph. Which summit skill uses it and for what.>

## 2. Required, cost, gate
<Required/optional. Any cost. Any plan gate. Any email needed, with the emails/ file.>

## 3. Path A: API key
<Click path with direct URL. What the value looks like. Shown once? Exact .env line(s). Then:>
**SAFE:** `if [ -d "$BUNDLE/.git" ]; then git -C "$BUNDLE" check-ignore -q .env && echo "protected ✅" || echo "add .env to $BUNDLE/.gitignore first"; else echo "protected ✅ (not a git folder, nothing can commit it)"; fi`
**FILLED:** `grep -q '^VAR=.\+' .env && echo "present ✅" || echo "still blank"`
**WORKS:** `bash -c '. lib/env.sh; . lib/probes.sh; env_load .env; probe_<vendor>; echo rc=$?'` (0 works, 1 rejected, 2 blank, 3 unreachable)
**Register:** no `claude` CLI needed. Source `.env`, then call the bundled helper with `$BUNDLE` absolute paths, and hand it credential variable NAMES, never values:
  - stdio (built or bundled server): `uv run --python 3.13 python "$BUNDLE/lib/mcp_register.py" <server> --stdio <command> <args...> --env <VAR> && echo "<server> registered ✅" || echo "<server> register failed ❌"`
  - http with a key in a header: `uv run --python 3.13 python "$BUNDLE/lib/mcp_register.py" <server> --http <url> --header "<Header-Name>: <PREFIX> <VAR>" && echo "<server> registered ✅" || echo "<server> register failed ❌"`
  Then `echo "<server>" >> "$BUNDLE/.cache/needs-restart"`. Re-running the same line any time (a new key, a rebuilt server) is always safe; it overwrites the old entry, nothing to remove first.

## 4. Path B: official MCP
<Same helper, `--http <url>` with no `--env`/`--header` if auth is a browser sign-in. Auth: type `/mcp` in the chat > server > Authenticate (or the Connectors (+) button if the app shows that instead), or a header if the vendor supports one. What to expect in the browser. Capability warning. Beta/waitlist status with date. Restart instruction: "quit and reopen the Claude Code desktop app.">

## 5. Verify
<What the checker runs and what pass/fail look like, using the vendor's real codes.>

## 6. Troubleshooting
<Top failure modes with fixes, from docs/research.>

## 7. Sources
<Vendor URLs, dated.>
