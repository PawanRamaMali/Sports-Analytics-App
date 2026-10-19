# The API is not called here; parse_shot_locations() gets a response of the
# shape stats.gleague.nba.com returns (as jsonlite::fromJSON simplifies it),
# including the combined "Corner 3" zone the app leaves out.

api_zones <- c("Restricted Area", "In The Paint (Non-RA)", "Mid-Range", "Left Corner 3",
               "Right Corner 3", "Above the Break 3", "Backcourt", "Corner 3")
api_ids <- c("PLAYER_ID", "PLAYER_NAME", "TEAM_ID", "TEAM_ABBREVIATION", "AGE", "NICKNAME")

fake_response <- function(zones = api_zones) {
  # Zone i has i makes of 10 attempts, so each zone's numbers are told apart.
  row <- function(name, team) {
    c("1", name, "10", team, "24", "Nick",
      unlist(lapply(seq_along(zones), function(i) c(i, 10, i / 10))))
  }
  headers <- data.frame(name = c("SHOT_CATEGORY", "columns"), columnsToSkip = c(6L, NA),
                        columnSpan = c(3L, 1L))
  headers$columnNames <- list(zones, c(api_ids, rep(c("FGM", "FGA", "FG_PCT"), length(zones))))
  list(resultSets = list(name = "ShotLocations", headers = headers,
                         rowSet = rbind(row("Player One", "AAA"), row("Player Two", "BBB"))))
}

test_that("parse_shot_locations finds the zones by name", {
  df <- parse_shot_locations(fake_response())
  expect_equal(names(df), shot_columns)
  expect_equal(df$PLAYER_NAME, c("Player One", "Player Two"))
  expect_equal(df$Restricted_Area_FGM, c(1, 1))
  expect_equal(df$Backcourt_3_FGM, c(7, 7))
  expect_equal(df$Above_the_Break_3_FG_PCT, c(0.6, 0.6))
  expect_length(validate_shot_data(df), 0)
})

test_that("zone order in the response does not matter", {
  df <- parse_shot_locations(fake_response(rev(api_zones)))
  # Restricted Area is now the last of 8 zones.
  expect_equal(df$Restricted_Area_FGM, c(8, 8))
})

test_that("parse_shot_locations refuses an unexpected layout", {
  expect_error(parse_shot_locations(fake_response(api_zones[-2])), "no zone In The Paint")
  r <- fake_response()
  r$resultSets$rowSet <- r$resultSets$rowSet[, -1]
  expect_error(parse_shot_locations(r), "columns for 8 zones")
  expect_error(parse_shot_locations(list(resultSets = list(rowSet = list()))), "no players")
})

test_that("the request asks for the season by zone, per game", {
  url <- gleague_shot_url("2021-22")
  expect_match(url, "leaguedashplayershotlocations")
  expect_match(url, "Season=2021-22")
  expect_match(url, "DistanceRange=By%20Zone")
  expect_match(url, "PerMode=PerGame")
  expect_match(url, "LeagueID=20")
  expect_error(fetch_shot_locations("2021"), "Invalid season")
})
