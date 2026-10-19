test_that("the zone catalog matches the season file layout", {
  expect_equal(nrow(shot_zones), 7)
  expect_length(zone_columns, 21)
  expect_equal(shot_columns[1:2], c("PLAYER_NAME", "TEAM_ABBREVIATION"))
  expect_true(all(shot_zones$group %in% names(diet_groups)))
})

test_that("shots_long has one row per player and zone, with no attempts as 0", {
  long <- shots_long(sample_shots())
  expect_equal(nrow(long), 3 * 7)
  rr <- long[long$player == "Rim Runner", ]
  expect_equal(rr$fga[rr$zone == "mid"], 0)
  expect_true(is.na(rr$pct[rr$zone == "mid"]))
  expect_equal(rr$pct[rr$zone == "ra"], 0.667)
})

test_that("missing makes and attempts count as none", {
  df <- sample_shots()
  df$Backcourt_3_FGM <- NA
  df$Backcourt_3_FGA <- NA
  long <- shots_long(df)
  expect_true(all(long$fga[long$zone == "bc3"] == 0))
})

test_that("shot_totals computes FG%, eFG%, points per shot and shares", {
  long <- shots_long(sample_shots())
  t <- shot_totals(long[long$player == "Sharp Shooter", ])
  # 4 of 10: 1/2 at the rim, 1/2 corner 3, 2/6 above the break.
  expect_equal(t$fga, 10)
  expect_equal(t$fg_pct, 0.4)
  expect_equal(t$fg3a, 8)
  expect_equal(t$fg3m, 3)
  expect_equal(t$efg, (4 + 0.5 * 3) / 10)
  expect_equal(t$pts_per_shot, (1 * 2 + 3 * 3) / 10)
  expect_equal(t$fg3a_rate, 0.8)
  expect_equal(t$share_rim + t$share_paint + t$share_mid + t$share_corner3 + t$share_atb3, 1)
})

test_that("player and team metrics have a row each", {
  long <- shots_long(sample_shots())
  pm <- player_metrics(long)
  expect_equal(sort(pm$player), sort(c("Mid Range", "Rim Runner", "Sharp Shooter")))
  tm <- team_metrics(long)
  expect_equal(tm$team, c("AAA", "BBB"))
  expect_equal(tm$players, c(2L, 1L))
  expect_equal(tm$fga[tm$team == "AAA"], 8 + 10)
})

test_that("league zone averages are weighted by attempts", {
  lg <- league_zone_avg(shots_long(sample_shots()))
  expect_equal(lg$zone, shot_zones$id)
  expect_equal(lg$pct[lg$zone == "ra"], (4 + 1 + 1) / (6 + 2 + 2))
  expect_true(is.na(lg$pct[lg$zone == "bc3"]))
  expect_equal(sum(lg$share), 1)
})

test_that("percentile_of counts the share at or below the value", {
  expect_equal(percentile_of(0.5, c(0.2, 0.5, 0.8, 0.9)), 50)
  expect_equal(percentile_of(1, c(0.2, NA, 0.5)), 100)
  expect_true(is.na(percentile_of(NA, c(0.1, 0.2))))
  expect_true(is.na(percentile_of(0.3, numeric())))
})

test_that("zone_profile compares a player with the league", {
  p <- zone_profile(shots_long(sample_shots()), "Rim Runner", min_fga = 1)
  expect_equal(p$zone, shot_zones$id)
  ra <- p[p$zone == "ra", ]
  expect_equal(ra$diff, ra$pct - 0.6)
  # Best of the three at the rim.
  expect_equal(ra$percentile, 100)
  # No attempts, so no percentile.
  expect_true(is.na(p$percentile[p$zone == "mid"]))
})

test_that("leaderboard ranks by a metric with a minimum of attempts", {
  long <- shots_long(sample_shots())
  b <- leaderboard(long, "fga", min_fga = 0, n = 10)
  expect_equal(b$player[1], "Sharp Shooter")
  b <- leaderboard(long, "fga", min_fga = 9, n = 10)
  expect_equal(nrow(b), 2)
  b <- leaderboard(long, "zone:ra", min_fga = 3, n = 10)
  expect_equal(b$player, "Rim Runner")
  expect_equal(nrow(leaderboard(long, "efg", min_fga = 0, n = 2)), 2)
  expect_error(leaderboard(long, "nope"), "Unknown metric")
  expect_error(leaderboard(long, "zone:xx"), "Unknown zone")
})

test_that("the 2020-21 season gives the known league numbers", {
  long <- shots_long(real_season())
  expect_equal(length(unique(long$player)), 246)
  expect_equal(length(unique(long$team)), 18)
  lg <- league_zone_avg(long)
  expect_equal(round(lg$pct[lg$zone == "ra"], 3), 0.629)
  expect_equal(round(lg$pct[lg$zone == "atb3"], 3), 0.316)
})

test_that("formatters show a dash for missing values", {
  expect_equal(fmt_pct(c(0.4567, NA)), c("45.7%", "-"))
  expect_equal(fmt_num(c(1.25, NA), 1), c("1.2", "-"))
})
