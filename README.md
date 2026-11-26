# home-uptime

Every 5 minutes GitHub checks that each app and website below answers. When one stops, an issue titled
"<name> unreachable" opens (you get an email and a GitHub app notification); when it comes back the issue
closes with how long it was down. Open issues = outage in progress, closed issues = history.

Watched: SeenRank app, ORC app, Sift, seenrank.com, orcstandard.com, d1fpc3.com, mechanicalandgasllc.com.
Add or remove one in `TARGETS` at the top of `check.sh` and in `GROUPS` in `docs/index.html` (same key).

Public status page: https://d1fpc3.github.io/home-uptime/ (GitHub Pages from `docs/`). It reads the issues
straight from the GitHub API and leaves out test alerts.

Test it: Actions tab, "uptime", Run workflow, tick "Open a test alert".
