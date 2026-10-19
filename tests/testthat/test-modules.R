# Module servers with shiny::testServer: inputs are set directly, no browser.

test_that("sign-in returns the user and locks after five failures", {
  path <- file.path(withr::local_tempdir(), "users.csv")
  add_user("ana", "correct horse", "analyst", path)
  testServer(welcome_server, args = list(users_path = path), {
    session$setInputs(username = "ana", password = "", signin = 1)
    expect_null(user())
    expect_match(message(), "Enter your username")

    for (i in 1:5) session$setInputs(password = "wrong", signin = 1 + i)
    expect_null(user())
    # Locked now, even with the right password.
    session$setInputs(password = "correct horse", signin = 10)
    expect_null(user())
    expect_match(message(), "Too many failed attempts")

    locked_until(Sys.time() - 1)
    session$setInputs(password = "correct horse", signin = 11)
    expect_equal(user(), list(username = "ana", role = "analyst"))
    expect_null(message())
  })
})

season_data <- function() {
  long <- shots_long(sample_shots())
  list(season = reactive("2021-22"), long = reactive(long),
       metrics = reactive(player_metrics(long)))
}

test_that("the players table filters by attempts and team, and opens a profile", {
  opened <- NULL
  testServer(players_server, args = list(data = season_data(), open_player = function(p) opened <<- p), {
    session$setInputs(min_fga = 0, teams = NULL)
    expect_equal(nrow(rows()), 3)
    expect_equal(rows()$player[1], "Sharp Shooter")
    session$setInputs(min_fga = 9)
    expect_setequal(rows()$player, c("Sharp Shooter", "Mid Range"))
    session$setInputs(teams = "BBB")
    expect_equal(rows()$player, "Mid Range")
    session$setInputs(open = "Mid Range")
    expect_equal(opened, "Mid Range")
  })
})

test_that("compare keeps a player's colour while they stay selected", {
  testServer(compare_server, args = list(data = season_data()), {
    session$setInputs(players = c("Rim Runner", "Mid Range"))
    expect_equal(color_of("Mid Range"), series_colors[2])
    session$setInputs(players = "Mid Range")
    expect_equal(color_of("Mid Range"), series_colors[2])
    session$setInputs(players = c("Mid Range", "Sharp Shooter"))
    expect_equal(color_of("Sharp Shooter"), series_colors[1])
  })
})

test_that("leaders switch between metrics and zones", {
  testServer(leaders_server, args = list(data = season_data(), open_player = function(p) NULL), {
    session$setInputs(metric = "fga", min_fga = 0, n = "10")
    expect_equal(board()$player[1], "Sharp Shooter")
    expect_false(is_pct())
    session$setInputs(metric = "zone:ra")
    expect_true(is_pct())
    expect_equal(board()$player[1], "Rim Runner")
  })
})
