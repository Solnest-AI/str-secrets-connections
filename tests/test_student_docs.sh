#!/usr/bin/env bash
# Summit 2.0 student questions that became docs (S2-028, S2-029, S2-030, S2-041, S2-042).
# Each check is the answer a student needed and could not find in the kit.
set -u; cd "$(dirname "$0")/.."
fail=0; t(){ if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
GUIDE=guide/connections-setup-guide.html
CARDS=guide/_cards.html

# S2-029 Breezeway bounces vague requests: the exact read-only "Use case" form answer, in the guide itself.
t "guide: Breezeway form 'Use case' answer, copy-paste ready" "grep -q 'Account holder, not a software vendor. An AI assistant (Claude Code) on my own computer reads my own Breezeway account, read-only' '$GUIDE'"
t "connector: same Use case wording as the guide" "grep -q 'Account holder, not a software vendor. An AI assistant (Claude Code) on my own computer reads my own Breezeway account, read-only' connectors/ops-breezeway.md"

# S2-030 "Is RankBreeze worth it with 2 listings?"
t "rankbreeze: 'Do I need it?' by portfolio size" "grep -q 'Do I need it?' connectors/ranking-rankbreeze.md"
t "rankbreeze card shows it"                      "awk '/<h3>RankBreeze<\/h3>/,/<\/article>/' '$CARDS' | grep -q 'Do I need it?'"

# S2-028 PriceLabs names Hostfully 'orbirental' (PriceLabs' integrations page and API reference)
t "pricelabs: hostfully = orbirental"             "grep -q 'orbirental' connectors/pricing-pricelabs.md"
t "hostfully: points PriceLabs users at orbirental" "grep -q 'orbirental' connectors/pms-hostfully.md"
t "pricelabs: no booked-date filter = old server" "grep -q 'booked_start_date' connectors/pricing-pricelabs.md"

# S2-041 / S2-042 which Claude account, do VAs see my computer, registered with another email
t "guide: Teams vs personal account question"     "grep -q 'Team account or my personal one' '$GUIDE'"
t "guide: VAs cannot see your computer"           "grep -q 'cannot see your computer' '$GUIDE'"
t "guide: registration email does not matter"     "grep -q 'signed up for the summit with a different email' '$GUIDE'"
t "claude-code connector: same account answer"    "grep -q 'Team or personal' connectors/system-claude-code.md"
exit $fail
