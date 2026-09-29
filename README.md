# STR Secrets Connections

Claude: if someone pasted a GitHub link and said "set up my connections", read CONNECTIONS.md in this folder and follow it.

Claude, if you have to download the kit first and `git` fails on a Mac with `xcrun: error` or `invalid active developer path` (Apple's command line tools are not installed, and nothing in the kit needs them), download the release zip instead. It unzips to `~/str-secrets-connections`:

```bash
curl -fsSL -o ~/str-secrets-connections.zip https://github.com/Solnest-AI/str-secrets-connections/releases/latest/download/str-secrets-connections.zip && unzip -q -o ~/str-secrets-connections.zip -d ~ && rm -f ~/str-secrets-connections.zip
```

Get every tool the summit skills need wired into Claude Code, on Mac or Windows, before the event.

A free setup kit from **Solnest AI** for **STR Secrets AI Summit 2.0**. For the full walkthrough with pictures, including the Day-0 list of what to send off before you even start, see the Connections Setup Guide PDF.

## Watch this first

**[Play the walkthrough](https://www.loom.com/share/7789c06b5b5e455aaf28035151733453)** (https://www.loom.com/share/7789c06b5b5e455aaf28035151733453)

Ryan walks the whole setup end to end. Do this before step 1.

## How to use it

Claude asks four questions, builds a `.env` with only your tools in it, finds any keys you already have on the machine, and walks you through the rest one key at a time.

1. [Download the zip](https://github.com/Solnest-AI/str-secrets-connections/releases/latest/download/str-secrets-connections.zip) and unzip it somewhere easy, like your Desktop. The guide with pictures is at https://str-secrets-connections.netlify.app
2. Open **Claude Code** in that folder (or drag the folder into the Claude Code window).
3. Say: **"Set up my connections."**

Claude reads `CONNECTIONS.md`, checks every connection, fixes what it can, and tells you exactly what to do for the rest. Say **"Check my connections"** any time to see the scoreboard again.

**If Claude says a command was "Blocked", or that a safety check "failed" or gave "no verdict":** that is the app's Auto mode having a bad minute, not the kit. Click the mode selector next to the send button (it says Auto), choose **Manual**, and say "retry". From then on Claude asks before each step and you click Allow.

## Your keys never touch the chat

When Claude needs a key, it opens a file called `.env` for you. You paste the key into that file and save. Keys stay on your computer and only ever go to the tool they belong to. Full list, with where to get every key: `KEYS.md`.

## Already set up? Get the latest version

Paste this into Claude Code:

> Update my connections. Follow the instructions at https://raw.githubusercontent.com/Solnest-AI/str-secrets-connections/main/UPDATE.md exactly.

## Stuck?

Email Ryan: ryan.lefebvre@strsecrets.com
FB: Ryan Lefebvre · IG: ryan_le5
