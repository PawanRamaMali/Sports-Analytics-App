# Sports Analytics 0.2

Released October 19, 2026.

## Overview

The first release of the analytics app. It replaces the Shiny login
template with screens for G League shooting by court zone, sign-in with
Analyst and Admin roles, admin tools for season data and users, and
automated tests that run on every pull request.

## Features

- Players: every player's shooting numbers, with team and minimum-attempts
  filters, search and CSV download. Click a player to open their profile.
- Player profile: key numbers against the league, a half-court shot chart
  coloured by FG% against the league average, zone percentiles and shot diet.
- Compare up to three players; Teams with rosters; Leaders by a metric or a
  zone; Player types grouped by shot diet.
- A season picker that switches every screen.
- Admin > Data: fetch a season from stats.gleague.nba.com or import a CSV;
  every file is checked before it is saved.
- Admin > Users: add users, change roles, reset passwords, delete users.
- Passwords are stored as hashes; five wrong passwords lock sign-in for 30
  seconds; the first admin comes from environment variables.

## Bug fixes

- The scraper no longer breaks on the API's new combined "Corner 3" zone:
  zones are matched by name.
- The scraper writes to the folder the app reads from.
- The plaintext credentials file is removed.

## Known issues

- Team numbers are sums of the players' per-game averages, not team totals.
- On a host without persistent storage, users and fetched seasons are lost
  on redeploy unless `SPORTS_USERS_FILE` and `SPORTS_DATA_DIR` point at
  persistent storage.
- stats.gleague.nba.com may refuse requests from cloud runners, including the
  weekly scrape workflow.
- The old demo passwords are still in the git history.
