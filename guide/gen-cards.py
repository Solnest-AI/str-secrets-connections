#!/usr/bin/env python3
"""
gen-cards.py — builds the key cards and the MCP directory table for the
Connections Setup Guide, straight out of connectors/*.md, so the guide
can never drift from what the connectors actually say.

Stdlib only. Run from the guide/ folder (build-pdf.sh does this for you):
    python3 gen-cards.py

Writes:
  guide/_cards.html            one <article class="card"> per vendor connector
  guide/_mcp-directory.html    one <table> of every server the kit registers
and splices both into guide/connections-setup-guide.html between their
marker comments (<!-- CARDS --> ... <!-- /CARDS --> and
<!-- MCP-DIRECTORY --> ... <!-- /MCP-DIRECTORY -->).

Re-run any time a connector file changes; both fragments regenerate in
place between their markers, nothing else in the HTML is touched.
"""
from __future__ import annotations

import html
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
CONNECTORS = REPO / "connectors"
GUIDE_HTML = HERE / "connections-setup-guide.html"
CARDS_OUT = HERE / "_cards.html"
DIRECTORY_OUT = HERE / "_mcp-directory.html"

SLOT_ORDER = ["pms", "pricing", "ranking", "ops", "market", "ads", "ai", "web", "db"]
SLOT_LABEL = {
    "pms": "Your booking system (PMS): pick one",
    "pricing": "Your pricing tool: pick one",
    "ranking": "Search ranking (optional)",
    "ops": "Cleaning and ops (optional)",
    "market": "Market comps",
    "ads": "Ads",
    "ai": "AI models",
    "web": "Web research",
    "db": "Database",
}
BADGE = {
    "yes": ("REQUIRED", "badge-required"),
    "one-of": ("ONE OF", "badge-oneof"),
    "optional": ("OPTIONAL", "badge-optional"),
}
SKILLS = ["Revenue Manager", "Listing Optimizer", "Ad Spy", "Comping Agent"]


# ---------------------------------------------------------------- parsing --

def read_connector(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    fm_match = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    frontmatter = {}
    if fm_match:
        for line in fm_match.group(1).splitlines():
            if ":" not in line:
                continue
            key, val = line.split(":", 1)
            key = key.strip()
            val = val.strip()
            if val.startswith("[") and val.endswith("]"):
                inner = val[1:-1].strip()
                items = [v.strip() for v in inner.split(",") if v.strip()]
                frontmatter[key] = items
            else:
                frontmatter[key] = val
    body = text[fm_match.end():] if fm_match else text

    h1 = re.search(r"^#\s+(.+)$", body, re.M)
    title = h1.group(1).strip() if h1 else path.stem
    vendor = title.split(":", 1)[0].strip()

    sections = {}
    heads = list(re.finditer(r"^##\s+(\d+)\.\s+(.+)$", body, re.M))
    for i, m in enumerate(heads):
        num = int(m.group(1))
        start = m.end()
        end = heads[i + 1].start() if i + 1 < len(heads) else len(body)
        sections[num] = body[start:end].strip("\n")

    return {
        "path": path,
        "frontmatter": frontmatter,
        "title": title,
        "vendor": vendor,
        "body": body,
        "sections": sections,
    }


def first_paragraph(text: str) -> str:
    if not text:
        return ""
    parts = re.split(r"\n\s*\n", text.strip(), maxsplit=1)
    return parts[0].strip()


def gate_text(section2: str) -> str:
    """The first paragraph of section 2, but if it just introduces a list
    (ends with ':') pull the next chunk in too so the card note isn't a
    dangling colon with nothing after it."""
    para = first_paragraph(section2)
    if not para.endswith(":"):
        return para
    rest = section2.strip()[len(para):].strip()
    nxt = re.split(r"\n\s*\n", rest, maxsplit=1)[0] if rest else ""
    nxt = re.sub(r"^[-*]\s*", "", nxt.strip())
    nxt = re.sub(r"\n[-*]\s*", " ", nxt)
    return f"{para} {nxt}".strip()


def clickpath_steps(section3: str) -> list[str]:
    if not section3 or section3.strip().startswith("_None"):
        return []
    safe_idx = section3.find("**SAFE:**")
    scope = section3[:safe_idx] if safe_idx != -1 else section3
    numbered = re.findall(r"^\s*\d+\.\s+(.+)$", scope, re.M)
    if numbered:
        return [n.strip() for n in numbered]
    # fallback: vendor steps quoted inline on one line, e.g. "1. Log in ... 2. Click ... 3. ..."
    for line in scope.splitlines():
        inline = re.split(r"\s(?=\d+\.\s)", line.strip().strip('"'))
        inline = [re.sub(r"^\d+\.\s*", "", x).strip().strip('"') for x in inline if re.match(r"^\d+\.\s", x.strip())]
        if len(inline) >= 2:
            return inline
    # fallback: an arrow-separated recap line, e.g. "**Account Settings** > **API Details** > ..."
    for line in scope.splitlines():
        if line.count(" > ") >= 2:
            return [s.strip() for s in line.split(">") if s.strip()]
    return []


def direct_link(section3: str) -> str | None:
    m = re.search(r"Direct link:\s*(\S+)", section3 or "")
    return m.group(1).rstrip(".,") if m else None


def skills_for(entry: dict) -> str:
    sec1 = entry["sections"].get(1, "")
    found = [s for s in SKILLS if s in sec1]
    if not found:
        found = [s for s in SKILLS if s in entry["body"]]
    if not found:
        return "the summit skills"
    return ", ".join(found)


# ------------------------------------------------------------- inline md --

def _linkify(m: re.Match) -> str:
    url = m.group(1)
    trail = ""
    while url and url[-1] in ".,;:)]\"'":
        trail = url[-1] + trail
        url = url[:-1]
    if not url:
        return m.group(1)
    return f'<a href="{url}" target="_blank" rel="noopener">{url}</a>{trail}'


def inline_html(text: str) -> str:
    """Minimal, safe inline markdown -> HTML: escape first, then link bare
    https:// URLs (stopping short of backticks/angle brackets so it can
    never eat into markup added by the later passes), then restore
    **bold** and `code`."""
    text = html.escape(text, quote=False)
    text = re.sub(r"(https?://[^\s\)\]\"'`<]+)", _linkify, text)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    return text


def trim(text: str, max_chars: int) -> str:
    """Cut at a sentence boundary, never mid-sentence and never with an
    ellipsis (cards looked unfinished, Ryan 2026-09-22). Keeps whole
    sentences up to max_chars; if the first sentence alone is longer than
    that, it is kept whole anyway."""
    text = re.sub(r"\s+", " ", text).strip()
    if len(text) <= max_chars:
        return text
    sentences = re.split(r"(?<=[.!?])\s+(?=[A-Z0-9\"'(])|(?<=[.!?][\"')\]])\s+(?=[A-Z0-9\"'(])", text)
    out = ""
    for sent in sentences:
        candidate = (out + " " + sent).strip()
        if out and len(candidate) > max_chars:
            break
        out = candidate
    return out


# ------------------------------------------------------------------ cards --

def build_card(entry: dict) -> str:
    fm = entry["frontmatter"]
    required = fm.get("required", "optional")
    badge_text, badge_class = BADGE.get(required, BADGE["optional"])
    vendor = html.escape(entry["vendor"])
    what = trim(first_paragraph(entry["sections"].get(1, "")), 420)
    gate = trim(gate_text(entry["sections"].get(2, "")), 600)
    skills = html.escape(skills_for(entry))
    steps = clickpath_steps(entry["sections"].get(3, ""))
    link = direct_link(entry["sections"].get(3, ""))
    env_vars = fm.get("env", [])
    official = fm.get("official_mcp", "none")
    has_official = (
        bool(official)
        and official.strip().lower() != "none"
        and "does not register" not in official
        and "reference only" not in official
    )

    parts = [f'<article class="card">']
    parts.append('  <div class="card-top">')
    parts.append(f'    <h3>{vendor}</h3>')
    parts.append(f'    <span class="badge {badge_class}">{badge_text}</span>')
    parts.append('  </div>')
    parts.append(f'  <p class="login">Needs: {skills}</p>')
    if what:
        parts.append(f'  <p>{inline_html(what)}</p>')
    if link:
        parts.append(f'  <p class="login">Get it at <a href="{html.escape(link)}" target="_blank" rel="noopener">{html.escape(link)}</a></p>')
    if steps:
        parts.append('  <ol>')
        for s in steps[:8]:
            parts.append(f'    <li>{inline_html(trim(s, 360))}</li>')
        parts.append('  </ol>')
    if env_vars:
        chips = " ".join(f"<code>{html.escape(v)}</code>" for v in env_vars)
        parts.append(f'  <p class="grab"><b>Goes in .env as</b> {chips}</p>')
    if gate:
        parts.append(f'  <p class="note">{inline_html(gate)}</p>')
    if has_official:
        parts.append('  <p class="note">An official vendor MCP exists too. Claude registers whichever path it needs.</p>')
    parts.append('</article>')
    return "\n".join(parts)


def build_cards_fragment(entries: list[dict]) -> str:
    by_slot: dict[str, list[dict]] = {}
    for e in entries:
        slot = e["frontmatter"].get("slot", "other")
        by_slot.setdefault(slot, []).append(e)

    out = []
    for slot in SLOT_ORDER:
        group = by_slot.get(slot)
        if not group:
            continue
        group.sort(key=lambda e: e["vendor"])
        label = SLOT_LABEL.get(slot, slot.title())
        out.append(f'<h3 class="group-head">{html.escape(label)}</h3>')
        out.append('<div class="cards">')
        for e in group:
            out.append(build_card(e))
        out.append('</div>')
    return "\n".join(out)


# -------------------------------------------------------- MCP directory --

REGISTER_RE = re.compile(
    r'mcp_register\.py"?\s+([a-zA-Z0-9_-]+)\s+(--stdio|--http)\s+(.+)'
)
# The one connector (PriceLabs' admin-only OAuth custom client) that has no
# file-based register helper and falls back to the `claude` CLI directly.
# Matched here only so its URL reaches the directory table too; the raw
# `claude mcp add` text is never shown to the attendee (classify_stdio /
# directory_row only ever emit the extracted name + URL).
CLAUDE_MCP_ADD_RE = re.compile(
    r'claude\s+mcp\s+add\b.*?\s([a-zA-Z0-9_-]+)\s+(https?://\S+)'
)


def find_register_lines(entry: dict) -> list[tuple[str, str, str]]:
    """Returns [(server_name, transport, rest)] in document order, first
    occurrence per server name only (the canonical / primary form)."""
    found = []
    seen = set()
    for block in re.findall(r"```bash\n(.*?)\n```", entry["body"], re.S):
        for line in block.splitlines():
            m = REGISTER_RE.search(line)
            if m:
                name, transport, rest = m.group(1), m.group(2), m.group(3)
                rest = rest.split(" && ", 1)[0].strip()
            else:
                m2 = CLAUDE_MCP_ADD_RE.search(line)
                if not m2:
                    continue
                name, transport, rest = m2.group(1), "--http", m2.group(2)
            if name in seen:
                continue
            seen.add(name)
            found.append((name, transport, rest))
    return found


def classify_stdio(rest: str) -> str:
    if re.search(r"\bnpx\b", rest):
        m = re.search(r"npx\s+-y\s+(\S+)", rest)
        if m:
            return m.group(1).strip('"')
        return "npm package"
    if "uv " in rest or "uv --directory" in rest:
        return "Bundled (Python, uv)"
    if ".venv" in rest or "python" in rest.lower():
        return "Bundled (Python)"
    if re.search(r"\bnode\b", rest):
        return "Bundled (Node)"
    return "Bundled"


def directory_row(entry: dict, name: str, transport: str, rest: str) -> dict:
    vendor = entry["vendor"]
    if transport == "--http":
        url_m = re.match(r'"?(\S+?)"?(?:\s|$)', rest)
        token = url_m.group(1) if url_m else rest
        has_header = "--header" in rest
        if token.startswith("$"):
            # secret lives in a shell variable (e.g. RankBreeze's own MCP URL);
            # show the documented URL shape from frontmatter instead of the var name.
            official = entry["frontmatter"].get("official_mcp", "")
            shape = re.sub(r"\s*\(.*\)\s*$", "", official).strip()
            value = shape or token
            auth = "key in .env"
            linkable = False
        else:
            value = token
            auth = "key in .env (header)" if has_header else "OAuth sign-in"
            linkable = value.startswith("http") and "<" not in value
        kind = "url"
    else:
        value = classify_stdio(rest)
        auth = "key in .env" if entry["frontmatter"].get("env") else "bundled"
        kind = "package" if value.startswith("@") or "/" in value and " " not in value else "text"
        linkable = False

    return {
        "name": name,
        "vendor": vendor,
        "value": value,
        "auth": auth,
        "kind": kind,
        "linkable": linkable,
        "slot": entry["frontmatter"].get("slot", "other"),
    }


# Servers Claude registers itself from a key in .env (URL in ~/.claude.json).
# Every other URL server is a sign-in connector the attendee adds in the app.
CLAUDE_ADDS = {"Firecrawl": "key", "AirROI": "key", "RankBreeze": "url"}


def build_directory_rows(entries: list[dict]) -> list[dict]:
    """One row per connector whose frontmatter `official_mcp` is a real URL.
    Built from frontmatter, not from register lines, because sign-in servers
    no longer have a register line (they are added in the app's Connectors
    screen, 2026-09-22)."""
    rows = []
    for e in entries:
        official = (e["frontmatter"].get("official_mcp") or "").strip()
        if not official.startswith("http") or "reference only" in official:
            continue
        url = re.sub(r"\s*\(.*\)\s*$", "", official).strip()
        vendor = e["vendor"]
        if vendor in CLAUDE_ADDS:
            auth = "key in .env (header)" if CLAUDE_ADDS[vendor] == "key" else "key in .env"
        else:
            auth = "OAuth sign-in"
        rows.append({
            "name": e["frontmatter"].get("server", ""),
            "vendor": vendor,
            "value": url,
            "auth": auth,
            "kind": "url",
            "linkable": url.startswith("http") and "<" not in url,
            "slot": e["frontmatter"].get("slot", "other"),
        })
    order = {s: i for i, s in enumerate(SLOT_ORDER)}
    rows.sort(key=lambda r: (order.get(r["slot"], 99), r["vendor"]))
    return rows


def how_it_connects(r: dict) -> str:
    if r["auth"] == "OAuth sign-in":
        return "You add it: + > Connectors > Manage connectors > + Add > Add custom connector, paste the URL, Continue, sign in"
    if r["auth"] == "key in .env (header)":
        return "Claude adds it for you once the key is in your .env"
    return "Claude adds it for you once the URL is in your .env"


def build_directory_fragment(rows: list[dict]) -> str:
    """Only servers with a real URL. Bundled and npm-package servers are
    Claude's business and only confused people in the table (Ryan, 2026-09-22)."""
    out = ['<table class="mcp-directory">']
    out.append("  <thead><tr><th>Vendor</th><th>URL</th><th>How it gets connected</th></tr></thead>")
    out.append("  <tbody>")
    for r in rows:
        if r["kind"] != "url":
            continue
        vendor = html.escape(r["vendor"])
        value = html.escape(r["value"])
        if r["linkable"]:
            value_html = f'<a href="{value}" target="_blank" rel="noopener">{value}</a>'
        else:
            value_html = f"<code>{value}</code>"
        out.append(f"    <tr><td>{vendor}</td><td>{value_html}</td><td>{html.escape(how_it_connects(r))}</td></tr>")
    out.append("  </tbody>")
    out.append("</table>")
    return "\n".join(out)


# ------------------------------------------------------------------ main --

def splice(html_text: str, marker: str, fragment: str) -> str:
    start = f"<!-- {marker} -->"
    end = f"<!-- /{marker} -->"
    pattern = re.compile(re.escape(start) + r".*?" + re.escape(end), re.S)
    replacement = f"{start}\n{fragment}\n{end}"
    if not pattern.search(html_text):
        raise SystemExit(f"marker {marker} not found in {GUIDE_HTML}")
    # a function replacement bypasses re's backslash/backreference expansion,
    # so the fragment (which may contain literal backslashes) is safe as-is.
    return pattern.sub(lambda _m: replacement, html_text, count=1)


def main() -> int:
    files = sorted(CONNECTORS.glob("*.md"))
    entries = []
    for f in files:
        if f.name == "_template.md" or f.name.startswith("system-"):
            continue
        entries.append(read_connector(f))

    if not entries:
        print("no connectors found", file=sys.stderr)
        return 1

    cards_fragment = build_cards_fragment(entries)
    CARDS_OUT.write_text(cards_fragment + "\n", encoding="utf-8")

    rows = build_directory_rows(entries)
    directory_fragment = build_directory_fragment(rows)
    DIRECTORY_OUT.write_text(directory_fragment + "\n", encoding="utf-8")

    if not GUIDE_HTML.exists():
        print(f"{GUIDE_HTML} does not exist yet; wrote fragments only", file=sys.stderr)
        return 0

    page = GUIDE_HTML.read_text(encoding="utf-8")
    page = splice(page, "CARDS", cards_fragment)
    page = splice(page, "MCP-DIRECTORY", directory_fragment)
    GUIDE_HTML.write_text(page, encoding="utf-8")

    print(f"wrote {len(entries)} connector cards and {len(rows)} directory rows")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
