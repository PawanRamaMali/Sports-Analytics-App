# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Sports Analytics: an R Shiny app for G League shooting by court zone (stats.gleague.nba.com shot-location report: per-game FGM/FGA/FG% in seven zones per player). After sign-in: Players, Player profile, Compare, Teams, Leaders, Player types, and for admins Admin > Data and Admin > Users. README.md has the user-facing overview, settings and deploy notes.

## Commands

On this machine Rscript is `C:/Program Files/R/R-4.5.1/bin/Rscript.exe` (not on PATH).

```sh
Rscript -e "shiny::runApp('.', port = 3838)"                        # run (needs a user: .env.local, see .env.example)
Rscript tests/testthat.R                                            # R unit tests
Rscript -e 'testthat::test_file("tests/testthat/test-metrics.R")'   # one test file
RSCRIPT="C:/Program Files/R/R-4.5.1/bin/Rscript.exe" npx playwright test   # browser tests
npx playwright test e2e/admin.spec.ts -g "import"                   # one file / one test
Rscript scraper/run_scrape.R 2020-21 [--type Playoffs]              # fetch a season into data/seasons
```

No linter or build step. CI (`.github/workflows/ci.yml`) runs both test suites; R packages come from `DESCRIPTION` (keep it in step when adding a package to `global.R`).

## Architecture

**Load order.** `app.R` sources `global.R` (APP_VERSION, packages, `.env.local` where existing env vars win, `%||%`, `load_app_code()`), then sources every `.R` file in `access/`, `engine/`, `modules/` in name order. A new file needs no registration. There is no `R/` folder on purpose (Shiny would auto-source it). Name order matters within a folder: `engine/catalog.R` (zones) must sort before files that use it at source time. `tests/testthat/helper-app.R` and `scraper/run_scrape.R` load the same folders. Do not `library()` jsonlite or httr in `global.R`: `jsonlite::validate` masks `shiny::validate`; call them with `::`.

**Layers.** `access/` = files and network: `shots.R` (season CSVs `data/seasons/<YYYY-YY>.csv`, `validate_shot_data()` / `write_season()` used by every writer, atomic temp+rename, radix sort and LF so files are byte-identical across OSes), `users.R` (users CSV with `sodium::password_store` hashes, roles `admin`/`analyst`, last-admin guards, `bootstrap_users()` from `SPORTS_ADMIN_*`), `scrape.R` (API call; zones are matched by name from the response's first header row, since the API returns an extra combined "Corner 3" zone). `engine/` = pure functions, no Shiny: `catalog.R` (`shot_zones`, `diet_groups`, column names), `metrics.R` (everything works on the long form from `shots_long()`: one row per player x zone; `shot_totals()` is the single place rates are computed), `styles.R` (k-means player types, deterministic order and names, preserves the caller's RNG), `court.R` (half-court polygons in feet, drawn bottom-up). `modules/` = one `<name>_ui()` / `<name>_server()` per screen, plus `charts.R` (shot chart, diet bars) and `ui_helpers.R` (theme, colours, table column helpers).

**Server wiring (`app.R`).** `page_navbar` with a hidden `welcome` panel; `html.app-no-nav` hides the navbar until `welcome_server()` returns a user. Admin menu is added with `nav_insert()` and admin module servers start only for admins; `is_admin()` re-reads the role from the users file on every admin action. Sign out = `session$reload()`. Screens get `data` = list of reactives (`season`, `long`, `metrics`) built from the navbar `season` input; `data_version` is bumped by Admin > Data to reload. `open_player(name)` (row clicks) sets the `focus` reactiveVal read by the profile module and must call `nav_select(..., session = session)` with the app session, since it runs inside modules.

**UI conventions.** reactable row clicks go through `row_click_js(ns("input"), field)` to a Shiny input. Chart colours are fixed slots in `series_colors` (diet groups always map to the same slot; Compare keeps a player's slot while selected); the shot chart uses the blue-gray-red `diff_color()` scale for FG% against the league. Styles are `app-*` classes in `www/style.css`.

**Browser tests.** `playwright.config.ts` starts `e2e/start-app.R` on port 3839, which copies `data/seasons` to `e2e/.tmp` and creates users `e2e-admin` / `e2e-analyst`, so tests never touch `data/`. Tests run serially (one R process). Selectors: navbar screens are `getByRole('tab', { name })`; selectize inputs via `pick()` in `e2e/helpers.ts`; reactable rows via `tableRows(page, outputId)`.

## Versioning

`APP_VERSION` in `global.R` is the only version shown; `auto-version-bump.yml` bumps it and `DESCRIPTION`'s Version on PR merge (`feat:` minor, `major:` major, else patch). Update `docs/VERSION_HISTORY.md` by hand.
