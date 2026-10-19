# Fetches one season's per-game shot locations by zone from
# stats.gleague.nba.com and writes data/seasons/<season>.csv (or
# SPORTS_DATA_DIR). Run from the repo root:
#   Rscript scraper/run_scrape.R 2020-21
#   Rscript scraper/run_scrape.R 2020-21 --type Playoffs
# .github/workflows/scrape.yml runs it on a schedule and commits the file.

args <- commandArgs(trailingOnly = TRUE)
type_at <- match("--type", args)
season_type <- if (is.na(type_at)) "Regular Season" else args[type_at + 1]
season <- if (length(args) && !startsWith(args[1], "--")) args[1] else Sys.getenv("SCRAPE_SEASON", "2020-21")

suppressWarnings(source("global.R"))
load_app_code(c("access", "engine"))

if (!valid_season(season)) stop("Season must look like 2020-21, not: ", season)
df <- fetch_shot_locations(season, season_type)
path <- write_season(df, season)
cat(sprintf("Wrote %s: %d players, %d teams\n", path, nrow(df), length(unique(df$TEAM_ABBREVIATION))))
