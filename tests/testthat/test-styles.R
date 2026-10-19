metrics_2021 <- function() player_metrics(shots_long(real_season()))

test_that("player_types gives k named, ordered types", {
  t <- player_types(metrics_2021(), k = 4, min_fga = 3)
  expect_equal(nlevels(t$players$type), 4)
  expect_equal(nrow(t$centers), 4)
  expect_false(anyDuplicated(levels(t$players$type)) > 0)
  expect_equal(sum(t$centers$players), nrow(t$players))
  expect_true(all(t$players$fga >= 3))
  # Ordered from inside-heavy to perimeter-heavy.
  inside <- t$centers$rim + t$centers$paint
  expect_equal(inside, sort(inside, decreasing = TRUE))
  expect_equal(as.character(t$centers$type[1]), "Rim runners")
})

test_that("player_types is stable and leaves the random stream alone", {
  m <- metrics_2021()
  set.seed(1)
  before <- runif(1)
  set.seed(1)
  a <- player_types(m, k = 3)
  after <- runif(1)
  b <- player_types(m, k = 3)
  expect_equal(before, after)
  expect_identical(a$players$type, b$players$type)
})

test_that("player_types needs more players than types", {
  expect_null(player_types(player_metrics(shots_long(sample_shots())), k = 3, min_fga = 0))
})

test_that("name_types keeps names unique", {
  league <- c(rim = 0.3, paint = 0.15, mid = 0.1, corner3 = 0.1, atb3 = 0.35)
  centers <- rbind(c(0.6, 0.2, 0.05, 0.05, 0.1), c(0.5, 0.16, 0.06, 0.13, 0.15),
                   c(0.3, 0.15, 0.1, 0.1, 0.35))
  colnames(centers) <- names(league)
  nm <- name_types(centers, league)
  expect_equal(nm[1], "Rim runners")
  expect_equal(nm[2], "Rim + Corner 3")
  expect_equal(nm[3], "Balanced")
})
