#!/usr/bin/env bash
# Pings the three backends that run on D1's home PC (through the Cloudflare tunnel) and opens a
# GitHub issue when they stop answering, closes it when they are back. Runs on GitHub's servers,
# so it keeps working when the PC is off. State lives in state.txt (committed only on changes).
set -uo pipefail
HOSTS=(seenrank-api.d1fpc3.com echelon-api.d1fpc3.com orc-api.d1fpc3.com)
down=()
for h in "${HOSTS[@]}"; do
  ok=0
  for try in 1 2 3; do
    code=$(curl -s -o /dev/null -w '%{http_code}' -m 15 "https://$h/rest/v1/" || true)
    # Any answer from the gateway (200/401/404) means the PC is up. 000 = no connection,
    # 502-504 and 520-530 = Cloudflare could not reach the tunnel (530 = tunnel down).
    if [[ "$code" =~ ^(2|3|4)[0-9][0-9]$ ]]; then ok=1; break; fi
    sleep 10
  done
  [[ $ok == 1 ]] || down+=("$h ($code)")
done
[[ "${SIMULATE_DOWN:-}" == "true" ]] && down=("simulated test alert")

now=$(date -u +%s)
prev=$(cat state.txt 2>/dev/null || echo "up 0")
read -r prev_state prev_since prev_issue <<<"$prev"

if (( ${#down[@]} )); then
  echo "DOWN: ${down[*]}"
  if [[ "$prev_state" != down ]]; then
    body="Unreachable since $(date -u -d @"$now" '+%Y-%m-%d %H:%M UTC'): ${down[*]}.

The home PC is off, lost power, or the Cloudflare tunnel stopped. While this issue is open, SeenRank, ORC and Echelon logins and data do not work (the websites themselves still load).

This issue closes itself when the backends answer again."
    url=$(gh issue create --title "Home PC down: apps offline" --body "$body" --label outage 2>/dev/null || gh issue create --title "Home PC down: apps offline" --body "$body")
    echo "down $now ${url##*/}" > state.txt
  fi
else
  echo "UP: all ${#HOSTS[@]} backends answer"
  if [[ "$prev_state" == down ]]; then
    mins=$(( (now - prev_since) / 60 ))
    gh issue close "$prev_issue" --comment "Back up at $(date -u -d @"$now" '+%H:%M UTC'). Down about $mins minutes (measured by 5-minute checks)." || true
    echo "up $now" > state.txt
  elif [[ ! -f state.txt ]] || (( now - prev_since > 25*86400 )); then
    # Monthly heartbeat commit: GitHub pauses scheduled workflows in repos with no activity for 60 days.
    echo "up $now" > state.txt
  fi
fi
