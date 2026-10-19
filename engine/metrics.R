# Shooting metrics from a season file. A season file has one row per player
# with per-game makes, attempts and FG% for each zone (engine/catalog.R).
# Everything here works on the long form from shots_long(): one row per
# player and zone. Percentages are fractions (0.45), not percents.

shots_long <- function(df) {
  rows <- lapply(seq_len(nrow(shot_zones)), function(i) {
    z <- shot_zones[i, ]
    fgm <- as.numeric(df[[paste0(z$prefix, "_FGM")]])
    fga <- as.numeric(df[[paste0(z$prefix, "_FGA")]])
    pct <- as.numeric(df[[paste0(z$prefix, "_FG_PCT")]])
    # A missing zone means no attempts there.
    fgm[is.na(fgm)] <- 0
    fga[is.na(fga)] <- 0
    # The reported FG% comes from season totals, so it is more exact than
    # the ratio of rounded per-game numbers; fall back to the ratio.
    pct <- ifelse(fga > 0, ifelse(is.na(pct), fgm / fga, pct), NA_real_)
    data.frame(player = df$PLAYER_NAME, team = df$TEAM_ABBREVIATION,
               zone = z$id, group = z$group, points = z$points,
               fgm = fgm, fga = fga, pct = pct, stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

safe_div <- function(a, b) ifelse(b > 0, a / b, NA_real_)

# Totals and rates for a set of long rows (one player, one team, the league).
shot_totals <- function(d) {
  fga <- sum(d$fga)
  fgm <- sum(d$fgm)
  three <- d$points == 3
  fg3a <- sum(d$fga[three])
  fg3m <- sum(d$fgm[three])
  shares <- vapply(names(diet_groups), function(g) safe_div(sum(d$fga[d$group == g]), fga),
                   numeric(1))
  in_zone <- function(z) safe_div(sum(d$fgm[d$zone %in% z]), sum(d$fga[d$zone %in% z]))
  c(list(fga = fga, fgm = fgm, fg_pct = safe_div(fgm, fga),
         fg3a = fg3a, fg3m = fg3m, fg3_pct = safe_div(fg3m, fg3a),
         efg = safe_div(fgm + 0.5 * fg3m, fga),
         pts_per_shot = safe_div(sum(d$fgm * d$points), fga),
         fg3a_rate = safe_div(fg3a, fga),
         rim_pct = in_zone("ra"), mid_pct = in_zone("mid")),
    stats::setNames(as.list(shares), paste0("share_", names(diet_groups))))
}

summarise_by <- function(long, by) {
  parts <- split(long, long[by], drop = TRUE)
  rows <- lapply(parts, function(d) data.frame(d[1, by, drop = FALSE], shot_totals(d)))
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[order(out[[by[1]]]), , drop = FALSE]
}

# One row per player: player, team, then the shot_totals() columns.
player_metrics <- function(long) summarise_by(long, c("player", "team"))

# One row per team, from the sum of its players' per-game numbers.
team_metrics <- function(long) {
  out <- summarise_by(long, "team")
  out$players <- as.integer(table(unique(long[c("player", "team")])$team)[out$team])
  out
}

# League FG% per zone, weighted by attempts.
league_zone_avg <- function(long) {
  out <- do.call(rbind, lapply(split(long, long$zone), function(d)
    data.frame(zone = d$zone[1], fgm = sum(d$fgm), fga = sum(d$fga))))
  out$pct <- safe_div(out$fgm, out$fga)
  out$share <- out$fga / sum(out$fga)
  out <- out[match(shot_zones$id, out$zone), ]
  rownames(out) <- NULL
  out
}

# Percentile (0-100) of `value` among `values`: the share at or below it.
percentile_of <- function(value, values) {
  values <- values[!is.na(values)]
  if (is.na(value) || !length(values)) return(NA_real_)
  100 * mean(values <= value)
}

# A player's zones against the league: FG%, the league FG%, the difference
# and the percentile among players with at least `min_fga` attempts per game
# in that zone. A zone below `min_fga` for the player has no percentile.
zone_profile <- function(long, player, min_fga = 0.5) {
  league <- league_zone_avg(long)
  me <- long[long$player == player, ]
  me <- me[match(shot_zones$id, me$zone), ]
  pctl <- vapply(shot_zones$id, function(z) {
    if (is.na(me$fga[me$zone == z]) || me$fga[me$zone == z] < min_fga) return(NA_real_)
    peers <- long[long$zone == z & long$fga >= min_fga, ]
    percentile_of(me$pct[me$zone == z], peers$pct)
  }, numeric(1))
  data.frame(zone = shot_zones$id, label = shot_zones$label,
             fgm = me$fgm, fga = me$fga, pct = me$pct,
             league_pct = league$pct, diff = me$pct - league$pct,
             percentile = unname(pctl), stringsAsFactors = FALSE)
}

# Metrics offered by Leaders and the player table: `fmt` is "pct" or "num".
leader_metrics <- data.frame(
  id = c("efg", "pts_per_shot", "fg_pct", "fg3_pct", "fg3a_rate", "fga", "fg3a"),
  label = c("Effective FG%", "Points per shot", "FG%", "3-point FG%", "3-point attempt rate",
            "Attempts per game", "3-point attempts per game"),
  fmt = c("pct", "num", "pct", "pct", "pct", "num", "num"),
  stringsAsFactors = FALSE
)

# Top `n` players by a metric (a leader_metrics id, or "zone:<id>" for a
# zone's FG%). Players need `min_fga` attempts per game: in total for a
# metric, in the zone for a zone's FG%.
leaderboard <- function(long, metric, min_fga = 1, n = 10) {
  if (startsWith(metric, "zone:")) {
    z <- sub("^zone:", "", metric)
    if (!z %in% shot_zones$id) stop("Unknown zone: ", z)
    d <- long[long$zone == z & long$fga >= min_fga & !is.na(long$pct), ]
    out <- data.frame(player = d$player, team = d$team, value = d$pct, attempts = d$fga)
  } else {
    if (!metric %in% leader_metrics$id) stop("Unknown metric: ", metric)
    m <- player_metrics(long)
    m <- m[m$fga >= min_fga & !is.na(m[[metric]]), ]
    out <- data.frame(player = m$player, team = m$team, value = m[[metric]], attempts = m$fga)
  }
  out <- out[order(-out$value, -out$attempts, out$player), ]
  rownames(out) <- NULL
  utils::head(out, n)
}

fmt_pct <- function(x, digits = 1) ifelse(is.na(x), "-", sprintf(paste0("%.", digits, "f%%"), 100 * x))
fmt_num <- function(x, digits = 1) ifelse(is.na(x), "-", formatC(x, format = "f", digits = digits))
