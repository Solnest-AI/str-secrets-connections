#!/usr/bin/env python3
"""
Register or remove one MCP server entry in $HOME/.claude.json (top-level
"mcpServers" key). Stdlib only, Python 3.11+. Never prints a secret value.

This exists so the kit never depends on the `claude` CLI being on PATH. The
Claude Code desktop app reads its server list straight out of this file, so
writing the entry here is the same thing `claude mcp add` used to do.

Usage:
  mcp_register.py NAME --stdio COMMAND [ARGS...] [--env VAR]...
  mcp_register.py NAME --http URL [--header "Name: [PREFIX] VAR"]
  mcp_register.py NAME --remove
  mcp_register.py --list

--stdio takes everything after it literally, as the command and its
arguments, EXCEPT one or more trailing "--env VAR" pairs, which are stripped
off the end and used to build the server's "env" block. Each VAR is read
from this process's environment (never from the command line), so put every
"--env VAR" pair at the very end of the line, after the real command args.
A blank or unset VAR exits 2 with "VAR is blank" on stderr and nothing is
written.

--header takes "Name: value", where the LAST whitespace-separated token of
value is an environment variable name and everything before it is a literal
prefix (may be empty). "X-API-KEY: AIRROI_API_KEY" -> header X-API-KEY is
the value of $AIRROI_API_KEY. "Authorization: Bearer FIRECRAWL_API_KEY" ->
header Authorization is "Bearer " followed by the value of
$FIRECRAWL_API_KEY. Same blank-var rule as --env.

--list prints "name<TAB>type" lines only. Never a url, env, header or arg.

A successful register prints nothing (exit 0); the caller's own "&& echo" is
the one confirmation line. --remove prints "NAME removed".
"""
import argparse
import json
import os
import sys
import tempfile
import time


def config_path():
    return os.path.join(os.path.expanduser("~"), ".claude.json")


def _backup_and_reset(path, reason):
    ts = time.strftime("%Y%m%d-%H%M%S")
    backup = "%s.bak-%s" % (path, ts)
    try:
        os.replace(path, backup)
        print("existing ~/.claude.json %s; backed it up to ~/.claude.json.bak-%s and started fresh" % (reason, ts))
    except OSError:
        print("existing ~/.claude.json %s and could not be backed up; starting fresh in memory (nothing on disk touched yet)" % reason)
    return {"mcpServers": {}}


def load_config():
    """Read ~/.claude.json. Missing file -> fresh config. Malformed file ->
    back it up and start fresh, rather than crash (it has to stay easy and
    forgiving for a non-technical attendee)."""
    path = config_path()
    if not os.path.isfile(path):
        return {"mcpServers": {}}
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError):
        return _backup_and_reset(path, "was not valid JSON")
    if not isinstance(data, dict):
        return _backup_and_reset(path, "was not a JSON object")
    if not isinstance(data.get("mcpServers"), dict):
        data["mcpServers"] = {}
    return data


def save_config(data):
    """Atomic write: temp file in the same directory, chmod 600, then
    os.replace over the real file. Every other top-level key round-trips
    unchanged."""
    path = config_path()
    directory = os.path.dirname(path) or "."
    os.makedirs(directory, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(prefix=".claude.json.", dir=directory)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, sort_keys=False)
            f.write("\n")
        try:
            os.chmod(tmp_path, 0o600)
        except OSError:
            pass
        os.replace(tmp_path, path)
    except Exception:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass


def env_value(var):
    val = os.environ.get(var, "")
    if not val:
        print("%s is blank" % var, file=sys.stderr)
        sys.exit(2)
    return val


def split_stdio_tail(tokens):
    """Strip zero or more trailing ['--env', VAR] pairs off the end of
    tokens. Returns (remaining_tokens, [VAR, ...]) with VARs in the order
    they appeared on the command line."""
    tokens = list(tokens)
    env_vars = []
    while len(tokens) >= 2 and tokens[-2] == "--env":
        env_vars.insert(0, tokens[-1])
        tokens = tokens[:-2]
    return tokens, env_vars


def parse_header(spec):
    if ":" not in spec:
        print("--header must look like 'Name: VALUE', got: %r" % spec, file=sys.stderr)
        sys.exit(2)
    name, _, value = spec.partition(":")
    name = name.strip()
    value = value.strip()
    parts = value.split()
    if not name or not parts:
        print("--header must look like 'Name: VALUE', got: %r" % spec, file=sys.stderr)
        sys.exit(2)
    var = parts[-1]
    prefix = " ".join(parts[:-1])
    return name, prefix, var


def cmd_list():
    data = load_config()
    servers = data.get("mcpServers", {})
    if isinstance(servers, dict):
        for name, entry in servers.items():
            server_type = entry.get("type", "unknown") if isinstance(entry, dict) else "unknown"
            print("%s\t%s" % (name, server_type))
    return 0


def cmd_remove(name):
    data = load_config()
    data.setdefault("mcpServers", {}).pop(name, None)
    save_config(data)
    print("%s removed" % name)
    return 0


def cmd_register(name, entry):
    data = load_config()
    data.setdefault("mcpServers", {})[name] = entry
    save_config(data)
    # Silent on success. Every register line in the connector files already echoes
    # "<name> registered ✅" on exit 0, and printing here too showed it twice.
    return 0


def build_parser():
    parser = argparse.ArgumentParser(
        prog="mcp_register.py",
        description="Register or remove one MCP server in ~/.claude.json (see module docstring for the full usage).",
    )
    parser.add_argument("name")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--remove", action="store_true", help="delete this server's entry")
    group.add_argument("--http", metavar="URL", help="register an http server at URL")
    group.add_argument("--stdio", nargs=argparse.REMAINDER, metavar="COMMAND ...", help="register a stdio server; everything after this is COMMAND ARGS, plus optional trailing --env VAR pairs")
    parser.add_argument("--header", action="append", default=[], metavar="Name: [PREFIX] VAR", help="with --http only; repeatable")
    return parser


def main(argv):
    if argv and argv[0] == "--list":
        return cmd_list()

    parser = build_parser()
    args = parser.parse_args(argv)

    if args.header and args.stdio is not None:
        parser.error("--header only applies to --http")

    if args.remove:
        return cmd_remove(args.name)

    if args.stdio is not None:
        tokens, env_names = split_stdio_tail(args.stdio)
        if not tokens:
            parser.error("--stdio needs a command")
        command, rest_args = tokens[0], tokens[1:]
        entry = {"type": "stdio", "command": command, "args": rest_args}
        if env_names:
            entry["env"] = {var: env_value(var) for var in env_names}
        return cmd_register(args.name, entry)

    # args.http is not None (mutually exclusive group is required=True)
    entry = {"type": "http", "url": args.http}
    if args.header:
        headers = {}
        for spec in args.header:
            header_name, prefix, var = parse_header(spec)
            value = env_value(var)
            headers[header_name] = ("%s %s" % (prefix, value)).strip() if prefix else value
        entry["headers"] = headers
    return cmd_register(args.name, entry)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
