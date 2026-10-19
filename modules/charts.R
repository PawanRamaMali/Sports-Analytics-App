# Plotly charts shared by the screens.

# Half-court shot chart: each zone filled by the player's FG% against the
# league (diff_color()), with the FG% written in the zone and the details on
# hover. `profile` is a zone_profile() data frame.
shot_chart <- function(profile) {
  zones <- court_zones()
  prof <- profile[match(names(zones), profile$zone), ]
  fills <- diff_color(prof$diff)

  zone_shapes <- lapply(seq_along(zones), function(i) {
    list(type = "path", path = svg_path(zones[[i]]$poly), fillcolor = fills[i],
         line = list(color = "#ffffff", width = 2), layer = "below")
  })
  line_shapes <- lapply(court_lines(), function(l) {
    list(type = "path", path = svg_path(l$path, l$closed),
         line = list(color = "rgba(11,11,11,0.35)", width = 1.2), layer = "above")
  })

  pos <- do.call(rbind, lapply(zones, function(z) z$label))
  hover <- sprintf(
    "<b>%s</b><br>%s of %s per game<br>FG%% %s (league %s)%s",
    prof$label, fmt_num(prof$fgm), fmt_num(prof$fga), fmt_pct(prof$pct), fmt_pct(prof$league_pct),
    ifelse(is.na(prof$percentile), "", sprintf("<br>%s percentile", ordinal(round(prof$percentile)))))
  corner <- prof$zone %in% c("lc3", "rc3")
  text <- ifelse(is.na(prof$pct), "-", ifelse(corner, sprintf("%.0f%%", 100 * prof$pct), fmt_pct(prof$pct)))

  plot_ly(x = pos[, 1], y = pos[, 2], type = "scatter", mode = "text", text = text,
          textfont = list(color = ink$primary, size = ifelse(corner, 11, 14)),
          hovertext = hover, hoverinfo = "text", showlegend = FALSE) |>
    # A large invisible marker per zone, so hovering anywhere near the label works.
    add_markers(x = pos[, 1], y = pos[, 2], marker = list(size = 40, opacity = 0),
                hovertext = hover, hoverinfo = "text", inherit = FALSE, showlegend = FALSE) |>
    layout(shapes = c(zone_shapes, line_shapes),
           xaxis = list(range = c(-28, 28), visible = FALSE, fixedrange = TRUE),
           yaxis = list(range = c(-0.5, 51.5), visible = FALSE, fixedrange = TRUE,
                        scaleanchor = "x", scaleratio = 1)) |>
    plot_defaults(legend = FALSE) |>
    config(displayModeBar = FALSE)
}

ordinal <- function(n) {
  suffix <- ifelse(n %% 100 %in% 11:13, "th",
                   c("th", "st", "nd", "rd", rep("th", 6))[n %% 10 + 1])
  paste0(n, suffix)
}

# 100% stacked horizontal bars of shot diet: one bar per row of `df`, which
# has a label column `by` and the share_* columns. Rows keep their order,
# top to bottom.
diet_bars <- function(df, by) {
  labels <- df[[by]]
  p <- plot_ly()
  for (g in names(diet_groups)) {
    v <- df[[paste0("share_", g)]]
    p <- add_bars(p, x = v, y = labels, orientation = "h", name = diet_groups[[g]],
                  marker = list(color = diet_colors[[diet_groups[[g]]]],
                                line = list(color = "#ffffff", width = 2)),
                  text = ifelse(v >= 0.08, sprintf("%.0f%%", 100 * v), ""),
                  textposition = "inside", insidetextanchor = "middle",
                  textfont = list(color = ink$primary, size = 11),
                  hovertext = sprintf("%s<br>%s: %s of attempts", labels, diet_groups[[g]], fmt_pct(v)),
                  hoverinfo = "text")
  }
  p |>
    layout(barmode = "stack", bargap = 0.35,
           xaxis = pct_axis(range = c(0, 1), fixedrange = TRUE),
           yaxis = list(categoryorder = "array", categoryarray = rev(labels), title = NULL,
                        color = ink$primary, fixedrange = TRUE, automargin = TRUE)) |>
    plot_defaults()
}
