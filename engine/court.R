# Half-court geometry in feet for the shot chart: x from -25 (left sideline)
# to 25, y from 0 (baseline) up to the half-court line at 47, hoop at
# (0, 5.25). Zones are polygons drawn bottom-up in the order returned, so a
# later zone covers an earlier one (the corners cover above the break, the
# paint covers mid-range, and so on). Backcourt 3 is a strip past half court.

court_hoop <- c(x = 0, y = 5.25)
court_three_r <- 23.75
court_corner_x <- 22
court_corner_y <- unname(court_hoop["y"] + sqrt(court_three_r^2 - court_corner_x^2))

court_arc <- function(r, from, to, cx = court_hoop[["x"]], cy = court_hoop[["y"]], n = 60) {
  t <- seq(from, to, length.out = n)
  data.frame(x = cx + r * cos(t), y = cy + r * sin(t))
}

court_rect <- function(x0, x1, y0, y1) data.frame(x = c(x0, x1, x1, x0), y = c(y0, y0, y1, y1))

three_point_line <- function() {
  a <- atan2(court_corner_y - court_hoop[["y"]], court_corner_x)
  rbind(data.frame(x = -court_corner_x, y = 0),
        court_arc(court_three_r, pi - a, a),
        data.frame(x = court_corner_x, y = 0))
}

restricted_area <- function() {
  rbind(data.frame(x = -4, y = 0), court_arc(4, pi, 0), data.frame(x = 4, y = 0))
}

# list of zone id -> list(poly = data.frame(x, y), label = c(x, y)).
court_zones <- function() {
  list(
    atb3  = list(poly = court_rect(-25, 25, 0, 47),         label = c(0, 36)),
    lc3   = list(poly = court_rect(-25, -court_corner_x, 0, court_corner_y), label = c(-23.5, 7)),
    rc3   = list(poly = court_rect(court_corner_x, 25, 0, court_corner_y),   label = c(23.5, 7)),
    mid   = list(poly = three_point_line(),                 label = c(-14.5, 13)),
    paint = list(poly = court_rect(-8, 8, 0, 19),           label = c(0, 13)),
    ra    = list(poly = restricted_area(),                  label = c(0, 2.6)),
    bc3   = list(poly = court_rect(-25, 25, 47, 51),        label = c(0, 49))
  )
}

# The court's painted lines, as open (closed = FALSE) or closed paths.
court_lines <- function() {
  list(
    list(path = court_rect(-25, 25, 0, 47), closed = TRUE),
    list(path = court_rect(-8, 8, 0, 19), closed = TRUE),
    list(path = court_arc(6, 0, pi, cy = 19), closed = FALSE),
    list(path = three_point_line(), closed = FALSE),
    list(path = court_arc(4, pi, 0), closed = FALSE),
    list(path = court_arc(0.75, 0, 2 * pi), closed = TRUE),
    list(path = data.frame(x = c(-3, 3), y = c(4, 4)), closed = FALSE),
    list(path = court_arc(6, pi, 2 * pi, cy = 47), closed = FALSE)
  )
}

# An SVG path string (plotly shapes take these).
svg_path <- function(p, closed = TRUE) {
  pts <- sprintf("%.2f,%.2f", p$x, p$y)
  paste0("M", pts[1], paste0(" L", pts[-1], collapse = ""), if (closed) " Z" else "")
}
