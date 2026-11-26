# home-uptime

Every 5 minutes GitHub checks that the SeenRank, ORC and Echelon backends answer. When they stop, an
issue titled "Home PC down" opens (you get an email and a GitHub app notification); when they come
back it closes with how long they were down. Open issues = outage in progress, closed issues = history.

Test it: Actions tab, "uptime", Run workflow, tick "Open a test alert".
