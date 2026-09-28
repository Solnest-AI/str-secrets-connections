#!/usr/bin/env bash
set -u; cd "$(dirname "$0")/.."
. tests/_helpers.sh
fail=0; t(){ if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
tmp=$(mktemp -d); cp -R tests/fixtures/fanout "$tmp/f"; cp fan-out-env.sh lib "$tmp/" -R 2>/dev/null || { cp fan-out-env.sh "$tmp/"; cp -R lib "$tmp/"; }
cd "$tmp"
printf 'STACK_PMS=hospitable\nSTACK_OPS=turno\nHOSPITABLE_API_KEY=hk\nAIRROI_API_KEY=ak\nGEMINI_API_KEY=gk\nTURNO_API_TOKEN=tt\nTURNO_PARTNER_ID=tp\nTURNO_ENV=\nPRICELABS_API_KEY=pk\nSKILL_PATH_LISTING_OPTIMIZER=%s/f/listing-optimizer\n' "$tmp" > .env
# existing turno .env with a custom line that must survive
printf 'TURNO_API_TOKEN=old\nTURNO_PARTNER_ID=\nTURNO_ENV=sandbox\nCUSTOM_LINE=keep\n' > f/turno/.env
MCP_SERVERS_DIR="$tmp/f" bash fan-out-env.sh >/dev/null
t "hospitable key written"          "grep -q '^HOSPITABLE_API_KEY=hk$' f/hospitable/.env"
t "undeclared key not written"      "! grep -q PRICELABS f/hospitable/.env"
t "blank webhook left blank"        "grep -q '^HOSPITABLE_WEBHOOK_SECRET=$' f/hospitable/.env"
t "turno token overwritten"         "grep -q '^TURNO_API_TOKEN=tt$' f/turno/.env"
t "turno custom line survives"      "grep -q '^CUSTOM_LINE=keep$' f/turno/.env"
t "turno env defaults production"   "grep -q '^TURNO_ENV=production$' f/turno/.env"
t "alias HOSPITABLE_TOKEN written"  "grep -q '^HOSPITABLE_TOKEN=hk$' f/listing-optimizer/.env"
t "skill gets airroi+gemini"        "grep -q '^AIRROI_API_KEY=ak$' f/listing-optimizer/.env && grep -q '^GEMINI_API_KEY=gk$' f/listing-optimizer/.env"
t "mode 600"                        "mode_is_600 f/turno/.env"
t "prints no values"                "! MCP_SERVERS_DIR=$tmp/f bash fan-out-env.sh | grep -qE 'hk|ak|gk|tt|tp'"
# only the attendee's own stack gets a .env (2026-09-28: a Hostfully shop found a filled hospitable/.env)
rm -f f/hospitable/.env f/listing-optimizer/.env
sed -i.bak 's/^STACK_PMS=.*/STACK_PMS=hostfully/' .env; rm -f .env.bak
out_h="$(MCP_SERVERS_DIR="$tmp/f" bash fan-out-env.sh)"
t "another PMS's folder is left alone"     "[ ! -f f/hospitable/.env ]"
t "fan-out names what it left alone"       "printf '%s' \"\$out_h\" | grep -q 'left alone:.*hospitable'"
t "chosen ops folder still filled"         "grep -q '^TURNO_API_TOKEN=tt$' f/turno/.env"
t "skill folder still filled"              "grep -q '^AIRROI_API_KEY=ak$' f/listing-optimizer/.env"
t "no HOSPITABLE_TOKEN alias for a non-Hospitable shop" "grep -q '^HOSPITABLE_TOKEN=$' f/listing-optimizer/.env"
exit $fail
