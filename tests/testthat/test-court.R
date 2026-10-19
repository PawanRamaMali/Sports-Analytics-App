test_that("the three-point line meets the corners at the right height", {
  expect_equal(round(court_corner_y, 2), 14.2)
  line <- three_point_line()
  d <- sqrt((line$x - court_hoop[["x"]])^2 + (line$y - court_hoop[["y"]])^2)
  arc <- line$y > court_corner_y + 1e-9
  expect_true(all(abs(d[arc] - court_three_r) < 1e-6))
})

test_that("every shot zone has a polygon and a label on the court", {
  z <- court_zones()
  expect_setequal(names(z), shot_zones$id)
  for (id in names(z)) {
    expect_true(nrow(z[[id]]$poly) >= 4, info = id)
    lab <- z[[id]]$label
    expect_true(lab[1] >= -25 && lab[1] <= 25 && lab[2] >= 0 && lab[2] <= 51, info = id)
  }
})

test_that("svg_path draws closed and open paths", {
  p <- data.frame(x = c(0, 1, 1), y = c(0, 0, 1))
  expect_equal(svg_path(p), "M0.00,0.00 L1.00,0.00 L1.00,1.00 Z")
  expect_equal(svg_path(p, closed = FALSE), "M0.00,0.00 L1.00,0.00 L1.00,1.00")
})

test_that("diff_color is gray at the league average and clamps the ends", {
  near <- function(a, b) max(abs(grDevices::col2rgb(a) - grDevices::col2rgb(b))) <= 2
  expect_true(near(diff_color(0), "#f0efec"))
  expect_true(near(diff_color(-0.12), "#2a78d6"))
  expect_true(near(diff_color(1), "#e34948"))
  expect_equal(diff_color(-1), diff_color(-0.12))
  expect_equal(diff_color(c(NA, 0.5)), c("#f7f7f5", diff_color(0.5)))
  expect_equal(diff_color(NA), "#f7f7f5")
})

test_that("ordinal suffixes", {
  expect_equal(ordinal(c(1, 2, 3, 4, 11, 12, 13, 21, 22, 100)),
               c("1st", "2nd", "3rd", "4th", "11th", "12th", "13th", "21st", "22nd", "100th"))
})
