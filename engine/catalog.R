# The seven shot zones of the stats.gleague.nba.com shot-location report, in
# court order. `prefix` is the column prefix in a season file
# (<prefix>_FGM, <prefix>_FGA, <prefix>_FG_PCT); `group` is the coarser shot
# diet the charts use (corner 3s together, backcourt with above the break).

shot_zones <- data.frame(
  id     = c("ra", "paint", "mid", "lc3", "rc3", "atb3", "bc3"),
  prefix = c("Restricted_Area", "In_The_Paint_Non_RA", "Mid_Range", "Left_Corner_3",
             "Right_Corner_3", "Above_the_Break_3", "Backcourt_3"),
  label  = c("Restricted area", "Paint (non-RA)", "Mid-range", "Left corner 3",
             "Right corner 3", "Above the break 3", "Backcourt 3"),
  points = c(2, 2, 2, 3, 3, 3, 3),
  group  = c("rim", "paint", "mid", "corner3", "corner3", "atb3", "atb3"),
  stringsAsFactors = FALSE
)

# Shot diet groups in display order; the order is also the colour order.
diet_groups <- c(rim = "Rim", paint = "Paint", mid = "Mid-range",
                 corner3 = "Corner 3", atb3 = "Above-break 3")

zone_columns <- as.vector(t(outer(shot_zones$prefix, c("_FGM", "_FGA", "_FG_PCT"), paste0)))
shot_columns <- c("PLAYER_NAME", "TEAM_ABBREVIATION", zone_columns)
