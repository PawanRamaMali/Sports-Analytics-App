test_that("only YYYY-YY seasons with consecutive years are valid", {
  expect_true(valid_season("2020-21"))
  expect_true(valid_season("1999-00"))
  expect_false(valid_season("2020-22"))
  expect_false(valid_season("2020"))
  expect_false(valid_season("../users"))
  expect_false(valid_season(c("2020-21", "2021-22")))
  expect_error(season_path("../../etc"), "Invalid season")
})

test_that("validate_shot_data accepts a season table", {
  expect_length(validate_shot_data(sample_shots()), 0)
  expect_length(validate_shot_data(real_season()), 0)
})

test_that("validate_shot_data reports what is wrong", {
  df <- sample_shots()
  expect_match(validate_shot_data(df[, -3]), "Missing column: Restricted_Area_FGM")
  expect_match(validate_shot_data(df[0, ]), "No players")
  expect_match(validate_shot_data(rbind(df, df[1, ])), "more than once")
  bad <- df
  bad$Mid_Range_FGA[1] <- -1
  expect_match(validate_shot_data(bad), "Negative")
  bad <- df
  bad$Mid_Range_FG_PCT[3] <- 45
  expect_match(validate_shot_data(bad), "fraction")
  bad <- df
  bad$Mid_Range_FGA <- as.character(bad$Mid_Range_FGA)
  bad$Mid_Range_FGA[2] <- "lots"
  expect_match(validate_shot_data(bad), "Not numeric: Mid_Range_FGA")
  expect_equal(validate_shot_data(list()), "Not a table.")
})

test_that("seasons are written and read back", {
  dir <- withr::local_tempdir()
  expect_equal(list_seasons(dir), character())
  expect_equal(nrow(season_info(dir)), 0)
  write_season(sample_shots(), "2021-22", dir)
  write_season(sample_shots(), "2019-20", dir)
  file.create(file.path(dir, c("notes.csv", "2020-22.csv")))
  expect_equal(list_seasons(dir), c("2021-22", "2019-20"))
  back <- read_season("2021-22", dir)
  expect_equal(names(back), shot_columns)
  expect_equal(back$PLAYER_NAME, sort(sample_shots()$PLAYER_NAME))
  info <- season_info(dir)
  expect_equal(info$players, c(3L, 3L))
  expect_equal(info$teams, c(2L, 2L))
})

test_that("write_season refuses invalid data and leaves no file", {
  dir <- withr::local_tempdir()
  expect_error(write_season(sample_shots()[, -1], "2021-22", dir), "Missing column")
  expect_equal(list.files(dir), character())
})

test_that("extra columns, such as a row number, are dropped", {
  dir <- withr::local_tempdir()
  df <- cbind(X = 1:3, sample_shots(), PLAYER_ID = 7:9)
  write_season(df, "2021-22", dir)
  expect_equal(names(read_season("2021-22", dir)), shot_columns)
})
