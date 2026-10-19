# Display helpers shared by the screens: theme, colours, stat tiles, table
# columns and plotly defaults.

app_theme <- function() {
  bs_theme(version = 5, primary = "#1C5CAB", base_font = font_collection("system-ui", "-apple-system", "Segoe UI", "sans-serif"))
}

# Chart colours (validated categorical slots, in fixed order). The shot diet
# groups always use the same slot, so a colour means the same group on every
# screen.
series_colors <- c("#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4")
diet_colors <- stats::setNames(series_colors, unname(diet_groups))
type_symbols <- c("circle", "square", "diamond", "triangle-up", "x")
ink <- list(primary = "#0b0b0b", secondary = "#52514e", muted = "#898781",
            grid = "#e1e0d9", axis = "#c3c2b7", surface = "#fcfcfb")

# Diverging blue (below the league) - gray - red (above), clamped at
# +/- `limit` FG% points.
diff_color <- function(diff, limit = 0.12) {
  ramp <- grDevices::colorRamp(c("#2a78d6", "#f0efec", "#e34948"), space = "Lab")
  out <- rep("#f7f7f5", length(diff))
  ok <- !is.na(diff)
  v <- (pmax(-limit, pmin(limit, diff[ok])) + limit) / (2 * limit)
  if (any(ok)) out[ok] <- grDevices::rgb(ramp(v), maxColorValue = 255)
  out
}

diff_legend <- function(limit = 0.12) {
  stops <- seq(-limit, limit, length.out = 7)
  div(class = "app-diff-legend",
      span(class = "text-muted", sprintf("%d pts below league", round(100 * limit))),
      lapply(diff_color(stops), function(col) span(class = "app-diff-swatch", style = paste0("background:", col))),
      span(class = "text-muted", sprintf("%d pts above", round(100 * limit))))
}

stat_tile <- function(label, value, sub = NULL) {
  div(class = "app-stat",
      div(class = "app-stat-label", label),
      div(class = "app-stat-value", value),
      if (!is.null(sub)) div(class = "app-stat-sub", sub))
}

empty_state <- function(icon, title, msg = NULL) {
  div(class = "app-empty",
      bs_icon(icon, size = "2.5rem", class = "text-secondary d-block mx-auto mb-2"),
      tags$h5(title), if (!is.null(msg)) tags$p(class = "text-muted mb-0", msg))
}

# reactable column definitions.
col_pct <- function(name, minWidth = 64, ...) {
  colDef(name = name, align = "right", minWidth = minWidth, format = colFormat(percent = TRUE, digits = 1),
         na = "-", ...)
}
col_num <- function(name, digits = 1, minWidth = 56, ...) {
  colDef(name = name, align = "right", minWidth = minWidth, format = colFormat(digits = digits), na = "-", ...)
}

# A table whose row click sends the row's `field` to the Shiny input `input_id`.
row_click_js <- function(input_id, field = "player") {
  JS(sprintf("function(rowInfo) { if (rowInfo) Shiny.setInputValue('%s', rowInfo.values['%s'], {priority: 'event'}); }",
             input_id, field))
}

app_table <- function(df, columns, ..., click = NULL) {
  reactable(df, columns = columns, compact = TRUE, highlight = TRUE, striped = FALSE,
            defaultPageSize = 15, showPageSizeOptions = TRUE, pageSizeOptions = c(15, 30, 100),
            onClick = click, rowClass = if (!is.null(click)) "app-clickable",
            theme = reactableTheme(headerStyle = list(color = ink$secondary, fontWeight = 600),
                                   rowHighlightStyle = list(background = "#eef4fc")),
            ...)
}

plot_defaults <- function(p, legend = TRUE) {
  p |>
    layout(font = list(family = "system-ui, -apple-system, Segoe UI, sans-serif", color = ink$secondary, size = 12),
           paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
           hoverlabel = list(bgcolor = "#ffffff", bordercolor = ink$grid, font = list(color = ink$primary)),
           showlegend = legend,
           legend = list(orientation = "h", traceorder = "normal", x = 0, y = 1.08, yanchor = "bottom",
                         font = list(color = ink$primary)),
           margin = list(l = 10, r = 10, t = 10, b = 10)) |>
    config(displaylogo = FALSE, modeBarButtonsToRemove = c("lasso2d", "select2d", "autoScale2d", "toggleSpikelines"))
}

pct_axis <- function(title = NULL, ...) {
  list(title = title, tickformat = ".0%", gridcolor = ink$grid, zerolinecolor = ink$axis,
       color = ink$muted, ...)
}
