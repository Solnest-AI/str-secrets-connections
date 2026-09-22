---
server: <name or none>
slot: <system|pms|pricing|ranking|ops|market|ads|ai|web|db>
required: <yes|one-of|optional>
env: [VAR_ONE, VAR_TWO]
official_mcp: <https://... or none>
portal: <https://... the exact page in the vendor app where the key or sign-in lives; it becomes the "Get it at" link on the guide card>
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
Two shapes, depending on how the vendor's server authenticates.

**Key or header auth (URL carries the secret, or a header does):** still the bundled helper, same as Path A. `--http <url>` plus `--header "<Header-Name>: <PREFIX> <VAR>"` if there is one. No browser step. <What to expect. Capability warning. Beta/waitlist status with date.>

**Sign-in (browser OAuth):** Claude does NOT register this one; there is nothing to add to `~/.claude.json`, because the app delivers a connected connector straight to the chat session. The attendee adds it themselves:
"**Claude does not register this one. You add it in the app, it takes about a minute.**
1. In the Claude Code desktop app, click the **+** next to the message box, then **Connectors**, then **Manage connectors**. The Connectors settings page opens.
2. Click **+ Add** (top right), then **Add custom connector**.
3. Type a name (<Vendor> is fine) and paste `<URL>` into **MCP server URL**. Click **Continue**. <If a vendor needs a Client ID / Client Secret, say so here: "If the next screen asks for OAuth details, use ...">
4. A browser tab opens. Sign in to <Vendor> and approve.
5. Done, it is on automatically. Come back and tell Claude "connected"."
<Capability warning. Beta/waitlist status with date.>

## Live check
<Sign-in servers only. Claude runs this right after "connected": the one read tool call that proves the connection is real, e.g. "List my properties" or "List my ad accounts", named exactly if the vendor documents the tool. If it is not available in the session, say: "I don't see <Vendor> in my tools yet. Check it shows connected under + > Connectors, or that Connect finished in the browser." Nothing else.>

## 5. Verify
<What the checker runs and what pass/fail look like, using the vendor's real codes.>

## 6. Troubleshooting
<Top failure modes with fixes, from docs/research.>

## 7. Sources
<Vendor URLs, dated.>
