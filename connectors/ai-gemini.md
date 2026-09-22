---
server: none
slot: ai
required: yes
env: [GEMINI_API_KEY]
official_mcp: none
---

# Gemini: Google's vision model, used to score your listing photos

## 1. What it is
Gemini is Google's AI model. The Listing Optimizer sends your listing photos to it and gets back a score and notes per photo: what is working, what is dark, what is cluttered, what to reshoot. That is the only job it has in the summit kit. Photo scoring, nothing else. There is no server to build and no MCP to register. You make one free key in Google AI Studio, it goes in `.env`, and `fan-out-env.sh` copies it into the Listing Optimizer's own `.env`.

## 2. Required, cost, gate
Required. The Listing Optimizer will not score photos without it.

Free. Google's tier table says the Free tier needs an "Active project or free trial" and Tier 1 needs you to "Set up and link an active billing account." Stay on Free. **Do not link a billing account.** Photo scoring runs fine on the free tier, and linking billing is how you end up paying for something you did not need.

No email, no waitlist, no approval. Any Google account works, and a personal Gmail is the easiest: a company Google Workspace account can be locked down by its admin (see section 6).

## 3. Path A: API key
Direct link: https://aistudio.google.com/apikey

**New to Google AI Studio?** Sign in with your Google account and accept the Terms of Service. Google's words: "If you are a new user, Google AI Studio automatically creates a default Google Cloud project and API key after you accept the Terms of Service." So a project already exists by the time you land on the API Keys page.

**Already have a Google Cloud account?** AI Studio does not make a default project for you, and it hides your existing ones until you import one. Google's steps:
1. Go to Google AI Studio.
2. Open the Dashboard from the left panel and select Projects.
3. Click the Import projects button.
4. Search for and select the Google Cloud project you want to import, then click Import.
5. Once imported, navigate to the API Keys page in the dashboard to create a key in that project.

**Make the key** (Google's steps, either way):
1. Go to the AI Studio API Keys page (the link above).
2. Check the Key Type column to identify any keys listed as Standard.
3. Click Create API key to generate a new key. "All new keys created in AI Studio are automatically created as auth keys."
4. Copy the new auth API key.

Why the Key Type column matters: Google is retiring the old key type. Their page says "On September 2026: the Gemini API will reject requests from standard keys." Only keys marked **Standard** are affected. "Starting May 28, 2026, all new API keys created in Google AI Studio are automatically created as auth keys," so anything you made on or after that date is already fine, and a key you create today is fine. The simplest move is to make a new one right now and use that. If you already have a key and its Key Type is not Standard, that one works too.

Copy the key right away. Google's page does not say whether it shows the value again later, so do not bet on it.

What you are copying: one string that starts with `AIza` and is 39 characters long, letters, digits, `-` and `_` only, no spaces. If what you copied does not start with `AIza`, you grabbed the key name or the project number, not the key. Go back and use the copy icon next to the key itself.

One key, one line in `.env`. Claude opens the file for you; put the key after the equals sign, save, close. The file is the only place it goes. Never the chat window.
```
GEMINI_API_KEY=
```

**SAFE:** `git check-ignore -q .env && echo "protected ✅"`
**FILLED:** `grep -q '^GEMINI_API_KEY=.\+' .env && echo "present ✅" || echo "still blank"`
**WORKS:** `bash -c '. lib/env.sh; . lib/probes.sh; env_load .env; probe_gemini; echo rc=$?'` (0 works, 1 rejected, 2 blank, 3 unreachable)

**Register:** nothing. There is no `claude mcp add` for Gemini, no server name, and no restart marker for this row. The Listing Optimizer reads the key from its own `.env`, and the fan-out script fills that from the root `.env`. Fan-out can only find the Listing Optimizer if the line `SKILL_PATH_LISTING_OPTIMIZER=` in the root `.env` holds the absolute path of the Listing Optimizer folder: the one that contains its `README.md`, `scripts/` and `.env.example`, not a folder above it (Claude fills it in Phase 0; if it is blank, fill it now). Then run it after any `.env` change:
```bash
cd "$BUNDLE" && bash fan-out-env.sh
```
It prints a ✅ per folder it touched and never prints the values. You must see a line ending in `(skill)` for the Listing Optimizer; if that line is missing, the key did not reach it. Fan-out skips the folder silently when the path is blank, does not exist, or is not the folder that holds the Listing Optimizer's `.env.example`. Ignore the closing "Restart Claude Code fully" line for this row; it is for MCP servers, and Gemini has none. Proof the key landed (prints yes or no, never the value):
```bash
set -a; . "$BUNDLE/.env"; set +a; grep -q '^GEMINI_API_KEY=.\+' "$SKILL_PATH_LISTING_OPTIMIZER/.env" && echo "Listing Optimizer has the key ✅" || echo "not there yet: SKILL_PATH_LISTING_OPTIMIZER must point at the folder that holds the Listing Optimizer's .env.example; fix it in .env, then re-run fan-out"
```

**Windows note:** run the lines above in Git Bash (Claude's Bash tool). Nothing on this card is a file path handed to `claude mcp add`, so there is no `cygpath -w` and no `.venv/Scripts/python.exe` here.

## 4. Path B: official MCP
_None for this connector._ The Listing Optimizer calls the Gemini API directly with the key. There is no MCP server to register and nothing to authenticate in `/mcp`.

## 5. Verify
The checker runs `probe_gemini`, which makes one real call: `GET https://generativelanguage.googleapis.com/v1beta/models` with your key in the `x-goog-api-key` header (the form Google's API-key page documents). It lists the models your key can see and does not generate anything. The row is **Gemini API key**:

- **200** with a list of models: works. Row shows ✅.
- **400 `API_KEY_INVALID`**, **401**, or **403**: key rejected. Row shows ⚠️ "re-check the line in .env". Either the key was copied wrong or it is a Standard-type key, which Google now rejects. Make a new key (section 3), paste it into `.env`, run `bash fan-out-env.sh`, say "Check my connections".
- **Blank**: the `.env` line is empty. Row shows ❌ "paste the key into .env".
- **Unreachable**: no network, or Google is down. Row shows ⚠️ "vendor unreachable". Try again in a minute.

## 6. Troubleshooting
- **Fresh key shows a quota of 0 or 1 requests per day in AI Studio:** it happens on some new keys. Delete it and create another.
- **Key Type column says Standard:** that key is on Google's rejection list ("On September 2026: the Gemini API will reject requests from standard keys"). Click Create API key, use the new one, paste it over the old value in `.env`.
- **Key shows a Blocked tag in AI Studio:** Google's page: "Starting May 7, 2026, the Gemini API blocks unrestricted API keys that have been dormant for an extended period. These keys show a Blocked tag in AI Studio. You must generate a new key or use an existing restricted key to continue." Make a new key.
- **400 `API_KEY_INVALID` on a key you just made:** most often a copy miss (a trailing space, a missing character). Open `.env`, delete the value, paste it again cleanly. If it still fails, make a new key.
- **Existing Google Cloud user, the API Keys page is empty or will not let you create a key:** you skipped the import. Dashboard > Projects > Import projects, pick your project, then back to API Keys.
- **Create API key is greyed out and says "You do not have permission to create a key in this project":** your Google account belongs to a company Workspace whose admin controls Cloud projects. Google's fix: ask your admin for a role such as Project Editor, or, in Google's words, "create a new Google Cloud project that is not associated with an organization to generate your keys." Fastest path for a summit attendee: sign out, sign in with a personal Gmail, and make the key there. The Listing Optimizer does not care which Google account the key came from.
- **AI Studio is nudging you to set up billing:** ignore it. Free tier is enough for photo scoring. Tier 1 is the one that needs a linked billing account, and you do not need Tier 1.

## 7. Sources
ai.google.dev/gemini-api/docs/api-key ("Last updated 2026-09-16"), ai.google.dev/gemini-api/docs/pricing, ai.google.dev/gemini-api/docs/rate-limits, Gemini API billing doc (tier table, 2026-09-20), aistudio.google.com/apikey. All read 2026-09-21. Probe shape and row name from the kit brief, task 3 and task 4.
