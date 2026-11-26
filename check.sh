#!/usr/bin/env bash
# Pings every target below and opens one GitHub issue per target when it stops answering, closes it
# when it is back. Runs on GitHub's servers, so it keeps working when the PC is off. State lives in
# state.txt, one line per target (committed only on changes). The status page in docs/ reads the
# issues, and finds each one's target by the "target: <key>" line in its body.
set -uo pipefail

# key|name|url
TARGETS=(
  "seenrank-app|SeenRank app|https://seenrank-api.d1fpc3.com/rest/v1/"
  "orc-app|ORC app|https://orc-api.d1fpc3.com/rest/v1/"
  "sift|Sift|https://sift-api.d1fpc3.workers.dev/health"
  "seenrank.com|seenrank.com|https://seenrank.com/"
  "orcstandard.com|orcstandard.com|https://orcstandard.com/"
  "d1fpc3.com|d1fpc3.com|https://d1fpc3.com/"
  "mechanicalandgasllc.com|mechanicalandgasllc.com|https://mechanicalandgasllc.com/"
)
UA="Mozilla/5.0 (compatible; d1-status/1.0; +https://d1fpc3.github.io/home-uptime/)"

probe() {
  local url=$1 code try
  for try in 1 2 3; do
    code=$(curl -s -o /dev/null -w '%{http_code}' -m 10 -A "$UA" "$url" || true)
    # Any answer under 500 means the server is up (the API gateways answer 401 without a key, and
    # Hostinger's bot check can answer 403). 000 = no connection, 5xx = server or tunnel failure
    # (Cloudflare 530 = tunnel down).
    if [[ "$code" =~ ^[234][0-9][0-9]$ ]]; then echo "up $code"; return; fi
    sleep 5
  done
  echo "down $code"
}

# All targets in parallel, so a slow one cannot push the run past its timeout.
tmp=$(mktemp -d)
for t in "${TARGETS[@]}"; do
  IFS='|' read -r key name url <<<"$t"
  probe "$url" > "$tmp/$key" &
done
wait

now=$(date -u +%s)
stamp() { date -u -d @"$1" '+%Y-%m-%d %H:%M UTC'; }
touch state.txt
new_state=""

for t in "${TARGETS[@]}"; do
  IFS='|' read -r key name url <<<"$t"
  read -r result code < "$tmp/$key"
  if [[ "${SIMULATE_DOWN:-}" == "true" && "$key" == "seenrank-app" ]]; then result=down; code=test; fi
  prev=$(grep -m1 "^$key " state.txt || echo "$key up $now")
  read -r _ prev_state prev_since prev_issue <<<"$prev"

  if [[ "$result" == down ]]; then
    echo "DOWN: $name ($code)"
    if [[ "$prev_state" != down ]]; then
      if [[ "$code" == test ]]; then
        why="simulated test alert"
      else
        why="no answer from $url (HTTP $code)"
      fi
      body="$name has been unreachable since $(stamp "$now"): $why.

This issue closes itself when it answers again.

target: $key"
      url_out=$(gh issue create --title "$name unreachable" --body "$body" --label outage 2>/dev/null \
        || gh issue create --title "$name unreachable" --body "$body")
      new_state+="$key down $now ${url_out##*/}"$'\n'
    else
      new_state+="$prev"$'\n'
    fi
  else
    echo "UP: $name ($code)"
    if [[ "$prev_state" == down ]]; then
      mins=$(( (now - prev_since) / 60 ))
      gh issue close "$prev_issue" --comment "Back up at $(date -u -d @"$now" '+%H:%M UTC'). Down about $mins minutes (measured by 5-minute checks)." || true
      new_state+="$key up $now"$'\n'
    elif (( now - prev_since > 25*86400 )); then
      # Monthly heartbeat commit: GitHub pauses scheduled workflows in repos with no activity for 60 days.
      new_state+="$key up $now"$'\n'
    else
      new_state+="$prev"$'\n'
    fi
  fi
done

printf '%s' "$new_state" > state.txt
rm -rf "$tmp"
