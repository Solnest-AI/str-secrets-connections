# Build-from-research files: read this first (Claude)

These two files came from the Revenue Manager bundle. Three overrides apply here:
1. Wherever they say `revenue-manager-plugin/references/<platform>.md`, write to `$BUNDLE/build/references/<platform>.md` instead.
2. Wherever they say `<BUNDLE_ROOT>/mcp-servers/<platform>/`, `$BUNDLE/mcp-servers/<platform>/` is correct (same layout).
3. Guesty For Hosts is sunset (2026-01-15). Do not build it; route the operator to Guesty Pro or tell them Lite has no API.
Register every built server with `--scope user`, the server name from CONNECTIONS.md, and (Windows) `cygpath -w` paths.
