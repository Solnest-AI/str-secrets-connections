#!/usr/bin/env python3
"""Write a trimmed .env from .env.template and the four stack answers.

    python3 lib/env_make.py --pms hospitable --pricing pricelabs --ranking none --ops turno
        [--template .env.template] [--out .env]

The attendee never sees slots for vendors they do not use (Ryan, 2026-09-22:
"create a .env file with only the slots that pertain to the questions").
Rules:
  * STACK_* lines are written with the answers already filled in.
  * PMS, pricing, ranking and ops blocks: only the chosen vendor's lines.
    "none" for ranking or ops drops the whole section.
  * Required blocks (ads, market data, AI, web, database) always stay.
  * Optional fallback tokens (only used when a browser sign-in loops) are left
    out; Claude appends one with env_set_if_blank if that day ever comes.
  * Re-running never loses a value: anything already filled in the current
    .env is carried over, and a filled key for a vendor that is no longer
    chosen is kept at the bottom under "Kept from before".
  * Never prints a value. Writes atomically, chmod 600.
"""
from __future__ import annotations

import argparse
import os
import re
import sys
import tempfile

PMS = ["hospitable", "hostaway", "guesty", "hostfully", "ownerrez", "lodgify", "uplisting", "smoobu"]
PRICING = ["pricelabs", "beyond"]
RANKING = ["rankbreeze", "intellihost", "none"]
OPS = ["turno", "breezeway", "none"]

# var prefix -> vendor slug; anything not listed here is not a per-vendor line
VENDOR_PREFIX = {
    "HOSPITABLE_": "hospitable", "HOSTAWAY_": "hostaway", "GUESTY_": "guesty",
    "HOSTFULLY_": "hostfully", "OWNERREZ_": "ownerrez", "LODGIFY_": "lodgify",
    "UPLISTING_": "uplisting", "SMOOBU_": "smoobu",
    "PRICELABS_": "pricelabs", "BEYOND_": "beyond",
    "RANKBREEZE_": "rankbreeze", "INTELLIHOST_": "intellihost",
    "TURNO_": "turno", "BREEZEWAY_": "breezeway",
}
# browser sign-in fallbacks and admin-only extras: not in a first-time .env
FALLBACK_VARS = {
    "HOSPITABLE_OFFICIAL_TOKEN", "INTELLIHOST_MCP_TOKEN", "META_ADS_TOKEN",
    "PRICELABS_MCP_CLIENT_ID", "PRICELABS_MCP_CLIENT_SECRET",
}
STACK_VARS = ["STACK_PMS", "STACK_PRICING", "STACK_RANKING", "STACK_OPS"]
# Claude fills these itself; they sit in their own block at the bottom so the attendee's
# paste list is exactly the lines above it.
CLAUDE_FILLS = {"TURNO_ENV": "production for the summit", "SUPABASE_PROJECT_REF": "the shared project Claude creates", "SUPABASE_DB_PASSWORD": "set when the project is created"}
# The four summit skills arrive on summit morning; their folders get written then, not now.
NOT_YET = ("SKILL_PATH_",)
VAR_RE = re.compile(r"^([A-Z][A-Z0-9_]*)=(.*)$")
SECTION_RE = re.compile(r"^# ---- .* ----\s*$")


def read_values(path: str) -> dict[str, str]:
    """KEY -> value for every filled line in an existing .env (values never printed)."""
    out: dict[str, str] = {}
    if not os.path.isfile(path):
        return out
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            m = VAR_RE.match(line.rstrip("\n"))
            if m and m.group(2).strip():
                out[m.group(1)] = m.group(2).strip()
    return out


def keep_var(name: str, chosen: set[str]) -> bool:
    if name.startswith(NOT_YET):
        return False
    if name in STACK_VARS or name in FALLBACK_VARS:
        return name in STACK_VARS
    for prefix, vendor in VENDOR_PREFIX.items():
        if name.startswith(prefix):
            return vendor in chosen
    return True  # required blocks and Claude-filled paths


def build(template_lines: list[str], answers: dict[str, str], existing: dict[str, str]) -> tuple[list[str], int]:
    chosen = {v for v in answers.values() if v and v != "none"}
    out: list[str] = []
    pending_comments: list[str] = []   # comment lines waiting for their var line
    section_header: str | None = None  # last section header, emitted lazily
    section_emitted = False
    written_vars: set[str] = set()
    claude_filled: list[tuple[str, str]] = []
    key_lines = 0

    def emit_section():
        nonlocal section_emitted
        if section_header is not None and not section_emitted:
            if out and out[-1] != "":
                out.append("")
            out.append(section_header)
            section_emitted = True

    in_header = True
    for raw in template_lines:
        line = raw.rstrip("\n")
        if in_header:
            # the banner at the top of the template, copied verbatim up to the first blank line
            if line.strip() == "":
                in_header = False
                out.append("")
            else:
                out.append(line)
            continue
        if SECTION_RE.match(line):
            section_header = line
            section_emitted = False
            pending_comments = []
            continue
        if line.startswith("#"):
            pending_comments.append(line)
            continue
        m = VAR_RE.match(line)
        if not m:
            pending_comments = []
            continue
        name = m.group(1)
        if not keep_var(name, chosen):
            pending_comments = []
            continue
        if name in CLAUDE_FILLS:
            # deferred to the bottom block; the template comment for it is dropped
            claude_filled.append((name, existing.get(name, "")))
            pending_comments = []
            written_vars.add(name)
            continue
        emit_section()
        out.extend(pending_comments)
        pending_comments = []
        if name in STACK_VARS:
            value = answers.get(name.replace("STACK_", "").lower(), "") or existing.get(name, "")
        else:
            value = existing.get(name, "")
            if not value:
                key_lines += 1
        out.append(f"{name}={value}")
        written_vars.add(name)

    if claude_filled:
        out.append("")
        out.append("# ---- Claude fills these. Leave them alone. ----")
        for name, value in claude_filled:
            out.append(f"# {name}: {CLAUDE_FILLS[name]}")
            out.append(f"{name}={value}")
    leftovers = [k for k in existing if k not in written_vars and k not in STACK_VARS and not k.startswith(NOT_YET)]
    if leftovers:
        out.append("")
        out.append("# ---- Kept from before (a vendor you no longer chose; safe to delete) ----")
        for k in leftovers:
            out.append(f"{k}={existing[k]}")
    while out and out[-1] == "":
        out.pop()
    return out, key_lines


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--pms", choices=PMS, required=True)
    ap.add_argument("--pricing", choices=PRICING, required=True)
    ap.add_argument("--ranking", choices=RANKING, default="none")
    ap.add_argument("--ops", choices=OPS, default="none")
    ap.add_argument("--template", default=".env.template")
    ap.add_argument("--out", default=".env")
    a = ap.parse_args()

    if not os.path.isfile(a.template):
        print(f"template not found: {a.template}", file=sys.stderr)
        return 2
    with open(a.template, encoding="utf-8") as fh:
        template_lines = fh.readlines()
    existing = read_values(a.out)
    answers = {"pms": a.pms, "pricing": a.pricing, "ranking": a.ranking, "ops": a.ops}
    lines, key_lines = build(template_lines, answers, existing)

    out_dir = os.path.dirname(os.path.abspath(a.out)) or "."
    fd, tmp = tempfile.mkstemp(prefix=".env.", dir=out_dir)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write("\n".join(lines) + "\n")
        os.chmod(tmp, 0o600)
        os.replace(tmp, a.out)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)
    chosen = ", ".join(v for v in answers.values() if v != "none")
    carried = len([k for k in existing if k not in STACK_VARS])
    print(f"wrote {a.out}: {key_lines} key(s) for you to paste ({chosen}); {carried} value(s) carried over; the Claude-filled lines sit at the bottom")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
