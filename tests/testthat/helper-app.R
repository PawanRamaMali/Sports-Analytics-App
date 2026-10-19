# Loads the app's code (as app.R does, without starting the app) and gives
# the tests small shot tables to work with.

app_root <- normalizePath(testthat::test_path("..", ".."))
if (!exists("shots_long", mode = "function")) {
  withr::with_dir(app_root, {
    suppressWarnings(source("global.R", local = globalenv()))
    load_app_code(c("access", "engine", "modules"))
  })
}

# A season table with one row per player; `zones` is a named list of
# c(fgm, fga) per zone id, other zones get 0 of 0.
shot_row <- function(player, team, zones) {
  row <- list(PLAYER_NAME = player, TEAM_ABBREVIATION = team)
  for (i in seq_len(nrow(shot_zones))) {
    z <- shot_zones[i, ]
    v <- zones[[z$id]] %||% c(0, 0)
    row[[paste0(z$prefix, "_FGM")]] <- v[1]
    row[[paste0(z$prefix, "_FGA")]] <- v[2]
    row[[paste0(z$prefix, "_FG_PCT")]] <- if (v[2] > 0) round(v[1] / v[2], 3) else NA
  }
  as.data.frame(row, check.names = FALSE, stringsAsFactors = FALSE)
}

# Three players: a rim runner, a shooter and a mid-range player.
sample_shots <- function() {
  rbind(
    shot_row("Rim Runner", "AAA", list(ra = c(4, 6), paint = c(1, 2))),
    shot_row("Sharp Shooter", "AAA", list(ra = c(1, 2), lc3 = c(1, 2), atb3 = c(2, 6))),
    shot_row("Mid Range", "BBB", list(ra = c(1, 2), mid = c(3, 6), atb3 = c(1, 1)))
  )
}

real_season <- function() read_season("2020-21", file.path(app_root, "data", "seasons"))
