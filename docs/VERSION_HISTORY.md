# Sports Analytics Version History

| Field | Value |
|---|---|
| Application | Sports Analytics, G League shooting by court zone |
| Application type | R Shiny web application |
| Primary branch | `main` |
| Current version | 0.2.0 |
| Version source | `APP_VERSION` in `global.R` |

## Versioning policy

Semantic Versioning (MAJOR.MINOR.PATCH). `.github/workflows/auto-version-bump.yml`
bumps the version when a pull request is merged into `main`, from the PR
title: `major:`, `!:` or `BREAKING CHANGE` for major; `feat:`, `feature:` or
`minor:` for minor; anything else for patch. A minor or major bump creates
`docs/change_log/RELEASE_NOTES_v<MAJOR.MINOR>.md` from
`.github/workflows/release_notes_stub_template.md`. This file is updated by
hand.

## Versions

| Version | Date | Summary |
|---|---|---|
| 0.2.0 | 2026-10-19 | First release: analysis screens, sign-in with roles, admin data and users, tests and CI |

## 0.2.0 (2026-10-19)

Replaces the login template with the analytics app (PR #1). Release notes:
[change_log/RELEASE_NOTES_v0.2.md](change_log/RELEASE_NOTES_v0.2.md).

### Analysis
- Players table with team and attempts filters, search and CSV download.
- Player profile: key numbers, shot chart against the league, zone
  percentiles, shot diet.
- Compare up to three players; Teams with rosters; Leaders by metric or
  zone; Player types by shot diet (k-means).
- Season picker for every screen.

### Access
- Users in a CSV with libsodium password hashes; first admin from
  `SPORTS_ADMIN_USER` / `SPORTS_ADMIN_PASSWORD`.
- Analyst and Admin roles; sign-in lockout after five failures.

### Data
- Season files in `data/seasons/`, validated on every write.
- Scraper reads the API's zone headers by name (the API added a combined
  "Corner 3" zone); weekly scrape workflow commits changed seasons.
- Admin fetch from stats.gleague.nba.com and CSV import.

### Quality
- R unit tests (testthat, shiny::testServer) and Playwright browser tests,
  run by `.github/workflows/ci.yml`.

### Known issues
- Team numbers are sums of the players' per-game averages, not team totals.
- Users and season files live on the server's disk; a host without
  persistent storage loses changes on redeploy unless `SPORTS_USERS_FILE`
  and `SPORTS_DATA_DIR` point elsewhere.
- stats.gleague.nba.com may refuse requests from cloud runners.
