# Sports Analytics

[![CI](https://github.com/PawanRamaMali/Sports-Analytics-App/actions/workflows/ci.yml/badge.svg)](https://github.com/PawanRamaMali/Sports-Analytics-App/actions/workflows/ci.yml)

R Shiny app for G League shooting by court zone. Data comes
from the stats.gleague.nba.com shot-location report: per-game makes,
attempts and FG% in seven zones for every player of a season.

After sign-in:

| Screen | What it shows |
|---|---|
| **Players** | Every player with FGA, FG%, eFG%, points per shot, 3PA rate and FG% at the rim, from mid-range and from 3; team filter, minimum attempts, search, CSV download. Click a player to open their profile. |
| **Player profile** | Key numbers against the league, a half-court shot chart coloured by FG% against the league average, each zone's FG% with its percentile, and the shot diet against the league's. |
| **Compare** | Up to three players: zone FG% next to the league average, key numbers and shot diets. |
| **Teams** | Team shooting and shot diet (from the players' per-game numbers); click a team for its roster. |
| **Leaders** | Top 10/20/50 by a metric or a zone's FG%, with a minimum of attempts. |
| **Player types** | Players grouped by shot diet with k-means (3 to 5 types), named after what they lean on (Rim runners, Perimeter shooters, ...). |
| **Admin > Data** | Admins only: the season files, fetching a season from stats.gleague.nba.com, importing a CSV. |
| **Admin > Users** | Admins only: add users, change roles, reset passwords, delete users. |

The season picker in the navbar switches every screen to another season.

The current version is shown in the navbar and on the sign-in page. What
each version has is in [docs/VERSION_HISTORY.md](docs/VERSION_HISTORY.md),
with release notes in [docs/change_log/](docs/change_log/).

## Running locally

Needs R (4.1 or later) and the packages in `DESCRIPTION`:

```r
install.packages(c("shiny", "bslib", "bsicons", "reactable", "plotly", "shinyjs",
                   "sodium", "httr", "jsonlite", "testthat", "withr"))
```

Copy `.env.example` to `.env.local` and set the first admin's username and
password, then start the app:

```sh
Rscript -e "shiny::runApp('.', port = 3838)"
```

Sign in with that admin and add other users under Admin > Users.

### Settings

| Variable | Default | Meaning |
|---|---|---|
| `SPORTS_ADMIN_USER`, `SPORTS_ADMIN_PASSWORD` | | First admin, created on start when there are no users yet |
| `SPORTS_USERS_FILE` | `data/users.csv` | Users and their password hashes (libsodium); never committed |
| `SPORTS_DATA_DIR` | `data/seasons` | One CSV per season, `<season>.csv` |

`.env.local` is read on start; a variable already set in the environment wins.

## Users and roles

- **Analyst**: every analysis screen.
- **Admin**: also Admin > Data and Admin > Users. The Admin menu is only
  added to the page for admins, and every admin action checks the role in
  the users file again.

Passwords are stored as libsodium hashes. Five wrong passwords in a row lock
the sign-in form for 30 seconds. The last admin cannot be demoted or deleted.

## Data

`data/seasons/2020-21.csv` is the 2020-21 regular season (246 players, 18
teams). New seasons come from:

- **Admin > Data > Fetch**, which calls stats.gleague.nba.com,
- **Admin > Data > Import**, which takes a CSV with the same columns,
- `Rscript scraper/run_scrape.R 2021-22 [--type Playoffs]` from the repo root,
- the **Scrape season** workflow (`.github/workflows/scrape.yml`): weekly for
  the `SCRAPE_SEASON` repository variable, or by hand for any season. It
  commits the season file when it changed.

Every way in validates the file (columns, numbers, no duplicate players)
before writing it. stats.gleague.nba.com may refuse requests from cloud
runners; fetching from the app or importing a CSV still works then.

## Tests

```sh
# R unit tests: metrics, player types, court geometry, data files, users,
# the scraper's parser and module servers (shiny::testServer)
Rscript tests/testthat.R
Rscript -e 'testthat::test_file("tests/testthat/test-metrics.R")'   # one file

# Browser tests: Playwright starts the app with its own users and data
# (e2e/start-app.R) and uses it in Chromium like a user would
npm ci
npx playwright install chromium
npx playwright test
npx playwright test e2e/admin.spec.ts         # one file
npx playwright test -g "sign out"              # by test title
npx playwright show-report                     # HTML report of the last run
```

Set `RSCRIPT` to the Rscript path when it is not on `PATH`, for example
`RSCRIPT="C:/Program Files/R/R-4.5.1/bin/Rscript.exe"`.

`.github/workflows/ci.yml` runs both suites on every push and pull request
to `main` and keeps the Playwright report as a build artifact.

## Code layout

```
app.R, global.R      UI and server; packages, settings, code loader
access/              data files (shots.R), users (users.R),
                     stats.gleague.nba.com (scrape.R)
engine/              no Shiny: zone catalog (catalog.R), metrics (metrics.R),
                     player types (styles.R), court geometry (court.R)
modules/             one file per screen, plus charts.R and ui_helpers.R
www/                 CSS and JS
data/seasons/        season files
scraper/             command-line scraper
tests/testthat/      R unit tests
e2e/                 Playwright browser tests
```

`global.R` sources `access/`, `engine/` and `modules/` in name order, so a
new file needs no change there. There is no `R/` folder on purpose: Shiny
would source it by itself.

## Deploying

The app runs on any Shiny host (Posit Connect, shinyapps.io, Shiny Server).
With rsconnect:

```r
rsconnect::deployApp(appDir = ".", appName = "sports-analytics")
```

`.rscignore` keeps tests, docs, the scraper and Node files out of the
bundle. A redeploy replaces the bundle, so in production point
`SPORTS_USERS_FILE` and `SPORTS_DATA_DIR` at persistent storage and set
`SPORTS_ADMIN_USER` / `SPORTS_ADMIN_PASSWORD` in the host's environment
settings for the first start.

## Versioning

`APP_VERSION` in `global.R` is the version shown in the navbar and on the
sign-in page. `.github/workflows/auto-version-bump.yml` bumps it (and
`Version` in `DESCRIPTION`) when a pull request is merged into `main`:
`major:` or `BREAKING CHANGE` in the title for major, `feat:` for minor,
anything else for patch. A minor or major bump adds a release notes stub in
`docs/change_log/`.

## License

[MIT](LICENSE)
