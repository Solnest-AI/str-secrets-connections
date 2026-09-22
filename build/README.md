# Build-from-research files: read this first (Claude)

These two files came from the Revenue Manager bundle. Three overrides apply here:
1. Wherever they say `revenue-manager-plugin/references/<platform>.md`, write to `$BUNDLE/build/references/<platform>.md` instead.
2. Wherever they say `<BUNDLE_ROOT>/mcp-servers/<platform>/`, `$BUNDLE/mcp-servers/<platform>/` is correct (same layout).
3. Guesty For Hosts is sunset (2026-01-15). Do not build it; route the operator to Guesty Pro or tell them Lite has no API.
Register every built server through `lib/mcp_register.py` (it always writes to the user-level `~/.claude.json`, no CLI or scope flag needed), the server name from CONNECTIONS.md, and (Windows) `cygpath -w` paths.

## What the connector file owns

These build docs (`build-pms-mcp.md`, `build-pricing-ops-mcp.md`) are written to stand alone, but inside this kit they do not run start to finish. Run only **Steps B1 to B3** from a build doc: research the vendor's live API, write the reference doc, write the server code into `$BUNDLE/mcp-servers/<name>/`. Stop there.

Everything past that belongs to the matching `connectors/<name>.md` file, not the build doc:
- **Step 2 (the credential walk)** and any "create `.env`, paste this in" instruction. The connector file already walked the attendee through getting the credential and it is already sitting in the root `.env`.
- **B4 (register).** The connector file has the exact register line for that server (`lib/mcp_register.py`, no `claude` CLI needed, and its Windows `cygpath -w` form), plus the fan-out step that copies the credential from the root `.env` into the server's own `.env`.
- **B5 (smoke test)** and any other post-build sanity check. The connector file's SAFE / FILLED / WORKS lines, and its Verify section, are the checks. Do not run a second credential paste or a second smoke test from the build doc; that just asks the attendee to do the same thing twice.

So: read the build doc for B1 to B3 only, then return to the connector file for credentials, registering, fan-out, verifying and the restart.
