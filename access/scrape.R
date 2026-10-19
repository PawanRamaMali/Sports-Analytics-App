# Player shot locations from the stats.gleague.nba.com API
# (leaguedashplayershotlocations, by zone, per game). Used by
# scraper/run_scrape.R and the admin Data screen; both write the result with
# write_season().

gleague_headers <- c(
  `Accept` = "application/json, text/plain, */*",
  `Accept-Language` = "en-US,en;q=0.9",
  `Connection` = "keep-alive",
  `Origin` = "https://stats.gleague.nba.com",
  `Referer` = "https://stats.gleague.nba.com/",
  `User-Agent` = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36",
  `x-nba-stats-origin` = "stats",
  `x-nba-stats-token` = "true"
)

gleague_shot_url <- function(season, season_type = "Regular Season") {
  query <- list(
    College = "", Conference = "", Country = "", DateFrom = "", DateTo = "",
    DistanceRange = "By Zone", Division = "", DraftPick = "", DraftYear = "",
    GameScope = "", GameSegment = "", Height = "", LastNGames = 0, LeagueID = "20",
    Location = "", MeasureType = "Base", Month = 0, OpponentTeamID = 0, Outcome = "",
    PORound = 0, PaceAdjust = "N", PerMode = "PerGame", Period = 0, PlayerExperience = "",
    PlayerPosition = "", PlusMinus = "N", Rank = "N", Season = season, SeasonSegment = "",
    SeasonType = season_type, ShotClockRange = "", StarterBench = "", TeamID = 0,
    VsConference = "", VsDivision = "", Weight = ""
  )
  httr::modify_url("https://stats.gleague.nba.com/stats/leaguedashplayershotlocations",
                   query = query)
}

# API zone names -> season file column prefixes (engine/catalog.R). Other
# zones the API returns, such as the combined "Corner 3", are left out.
api_zone_prefixes <- c(
  "Restricted Area" = "Restricted_Area", "In The Paint (Non-RA)" = "In_The_Paint_Non_RA",
  "Mid-Range" = "Mid_Range", "Left Corner 3" = "Left_Corner_3", "Right Corner 3" = "Right_Corner_3",
  "Above the Break 3" = "Above_the_Break_3", "Backcourt" = "Backcourt_3"
)

# The API answers with two header rows: the zone names (after
# `columnsToSkip` id columns, `columnSpan` columns each) and the column
# names (PLAYER_ID, PLAYER_NAME, ..., then FGM, FGA, FG_PCT per zone). Rows
# are positional, so zones are found by name in the first header row.
parse_shot_locations <- function(json) {
  rs <- json$resultSets
  rows <- rs$rowSet
  if (is.null(rows) || !length(rows)) stop("The API returned no players.")
  m <- if (is.matrix(rows)) rows else do.call(rbind, lapply(rows, unlist))
  zones <- rs$headers$columnNames[[1]]
  ids <- rs$headers$columnNames[[2]][seq_len(rs$headers$columnsToSkip[1])]
  missing <- setdiff(names(api_zone_prefixes), zones)
  if (length(missing)) stop("Unexpected response: no zone ", paste(missing, collapse = ", "), ".")
  if (!all(c("PLAYER_NAME", "TEAM_ABBREVIATION") %in% ids)) stop("Unexpected response: no player columns.")
  if (ncol(m) != length(ids) + 3 * length(zones)) {
    stop(sprintf("Unexpected response: %d columns for %d zones.", ncol(m), length(zones)))
  }
  df <- as.data.frame(m[, seq_along(ids), drop = FALSE], stringsAsFactors = FALSE)
  names(df) <- ids
  for (z in names(api_zone_prefixes)) {
    at <- length(ids) + 3 * (match(z, zones) - 1)
    df[paste0(api_zone_prefixes[[z]], c("_FGM", "_FGA", "_FG_PCT"))] <- m[, at + 1:3]
  }
  normalise_shot_data(df)
}

fetch_shot_locations <- function(season, season_type = "Regular Season", timeout = 60) {
  if (!valid_season(season)) stop("Invalid season: ", season)
  res <- httr::GET(gleague_shot_url(season, season_type),
                   httr::add_headers(.headers = gleague_headers), httr::timeout(timeout))
  if (httr::http_error(res)) {
    stop(sprintf("stats.gleague.nba.com answered HTTP %d.", httr::status_code(res)))
  }
  parse_shot_locations(jsonlite::fromJSON(httr::content(res, "text", encoding = "UTF-8")))
}
