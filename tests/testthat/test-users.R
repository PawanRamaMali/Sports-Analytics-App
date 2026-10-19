users_tmp <- function(env = parent.frame()) file.path(withr::local_tempdir(.local_envir = env), "users.csv")

test_that("users sign in with their password only", {
  path <- users_tmp()
  add_user("ana", "correct horse", "analyst", path)
  expect_equal(verify_login("ana", "correct horse", path), list(username = "ana", role = "analyst"))
  expect_equal(verify_login("ANA", "correct horse", path)$username, "ana")
  expect_null(verify_login("ana", "wrong password", path))
  expect_null(verify_login("nobody", "correct horse", path))
  expect_null(verify_login("ana", "", path))
  expect_null(verify_login("", "correct horse", path))
})

test_that("passwords are stored hashed", {
  path <- users_tmp()
  add_user("ana", "correct horse", "analyst", path)
  raw <- paste(readLines(path), collapse = "\n")
  expect_false(grepl("correct horse", raw, fixed = TRUE))
  expect_match(read_users(path)$password_hash, "^\\$")
})

test_that("new users are checked", {
  path <- users_tmp()
  add_user("ana", "correct horse", "analyst", path)
  expect_error(add_user("Ana", "another pass", "analyst", path), "already exists")
  expect_error(add_user("al", "correct horse", "analyst", path), "Username")
  expect_error(add_user("bad name!", "correct horse", "analyst", path), "Username")
  expect_error(add_user("bob", "short", "analyst", path), "8 characters")
  expect_error(add_user("bob", "correct horse", "owner", path), "Unknown role")
  expect_equal(nrow(read_users(path)), 1)
})

test_that("the last admin cannot be demoted or deleted", {
  path <- users_tmp()
  add_user("root", "admin password", "admin", path)
  add_user("ana", "correct horse", "analyst", path)
  expect_error(set_user_role("root", "analyst", path), "last admin")
  expect_error(delete_user("root", path), "last admin")
  set_user_role("ana", "admin", path)
  set_user_role("root", "analyst", path)
  expect_equal(read_users(path)$role, c("analyst", "admin"))
  delete_user("root", path)
  expect_equal(read_users(path)$username, "ana")
  expect_error(delete_user("root", path), "No user")
})

test_that("a reset password replaces the old one", {
  path <- users_tmp()
  add_user("ana", "correct horse", "analyst", path)
  expect_error(set_user_password("ana", "short", path), "8 characters")
  set_user_password("ana", "battery staple", path)
  expect_null(verify_login("ana", "correct horse", path))
  expect_equal(verify_login("ana", "battery staple", path)$role, "analyst")
})

test_that("bootstrap_users creates the first admin from the environment", {
  path <- users_tmp()
  withr::local_envvar(SPORTS_ADMIN_USER = "", SPORTS_ADMIN_PASSWORD = "")
  expect_false(bootstrap_users(path))
  withr::local_envvar(SPORTS_ADMIN_USER = "boss", SPORTS_ADMIN_PASSWORD = "boss password")
  expect_true(bootstrap_users(path))
  expect_equal(verify_login("boss", "boss password", path)$role, "admin")
  # Runs once: an existing user file is left alone.
  withr::local_envvar(SPORTS_ADMIN_USER = "other", SPORTS_ADMIN_PASSWORD = "other password")
  expect_true(bootstrap_users(path))
  expect_equal(read_users(path)$username, "boss")
})
