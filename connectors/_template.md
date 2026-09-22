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
**Register:** exact `claude mcp add` line with `$BUNDLE` absolute path and `--scope user`, output to `/dev/null`, then `echo "<server>" >> .cache/needs-restart`.

## 4. Path B: official MCP
<Exact `claude mcp add --transport http ...` line. Auth: `/mcp` > server > Authenticate, or header. What to expect in the browser. Capability warning. Beta/waitlist status with date.>

## 5. Verify
<What the checker runs and what pass/fail look like, using the vendor's real codes.>

## 6. Troubleshooting
<Top failure modes with fixes, from docs/research.>

## 7. Sources
<Vendor URLs, dated.>
