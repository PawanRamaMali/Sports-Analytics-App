# App users: a CSV (username, password_hash, role, created) at users_file().
# Passwords are stored as libsodium hashes (sodium::password_store), never
# in clear. The file is not in git: on first start bootstrap_users() creates
# the admin from SPORTS_ADMIN_USER / SPORTS_ADMIN_PASSWORD.

user_roles <- c(admin = "Admin", analyst = "Analyst")

users_file <- function() Sys.getenv("SPORTS_USERS_FILE", "data/users.csv")

empty_users <- function() {
  data.frame(username = character(), password_hash = character(), role = character(),
             created = character(), stringsAsFactors = FALSE)
}

read_users <- function(path = users_file()) {
  if (!file.exists(path)) return(empty_users())
  u <- utils::read.csv(path, colClasses = "character", stringsAsFactors = FALSE)
  if (!all(names(empty_users()) %in% names(u))) stop("Users file has unexpected columns: ", path)
  u[names(empty_users())]
}

write_users <- function(u, path = users_file()) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- tempfile(tmpdir = dirname(path), fileext = ".tmp")
  on.exit(unlink(tmp))
  utils::write.csv(u, tmp, row.names = FALSE)
  if (!file.rename(tmp, path)) file.copy(tmp, path, overwrite = TRUE)
  invisible(u)
}

# Problems with a new user's fields (empty when valid).
check_username <- function(username) {
  if (!is.character(username) || length(username) != 1 || !grepl("^[A-Za-z0-9_.-]{3,32}$", username)) {
    "Username must be 3 to 32 letters, digits, dots, dashes or underscores."
  }
}
check_password <- function(password) {
  if (!is.character(password) || length(password) != 1 || nchar(password) < 8) {
    "Password must have at least 8 characters."
  }
}

add_user <- function(username, password, role = "analyst", path = users_file()) {
  err <- c(check_username(username), check_password(password),
           if (!role %in% names(user_roles)) "Unknown role.")
  if (length(err)) stop(paste(err, collapse = " "))
  u <- read_users(path)
  if (tolower(username) %in% tolower(u$username)) stop("User ", username, " already exists.")
  u <- rbind(u, data.frame(username = username, password_hash = sodium::password_store(password),
                           role = role, created = format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
  write_users(u, path)
}

find_user <- function(u, username) which(tolower(u$username) == tolower(username %||% ""))

# The user's role when the password matches, else NULL. An unknown user
# still pays for one hash check, so timing does not tell which users exist.
verify_login <- function(username, password, path = users_file()) {
  u <- read_users(path)
  i <- find_user(u, username)
  if (!nzchar(username %||% "") || !nzchar(password %||% "")) return(NULL)
  if (length(i) != 1) {
    sodium::password_verify(dummy_hash(), password)
    return(NULL)
  }
  if (isTRUE(sodium::password_verify(u$password_hash[i], password))) {
    list(username = u$username[i], role = u$role[i])
  }
}
dummy_hash <- local({
  h <- NULL
  function() h %||% (h <<- sodium::password_store("not a real password"))
})

set_user_role <- function(username, role, path = users_file()) {
  if (!role %in% names(user_roles)) stop("Unknown role.")
  u <- read_users(path)
  i <- find_user(u, username)
  if (length(i) != 1) stop("No user ", username, ".")
  if (u$role[i] == "admin" && role != "admin" && sum(u$role == "admin") == 1) {
    stop("The last admin cannot lose the admin role.")
  }
  u$role[i] <- role
  write_users(u, path)
}

set_user_password <- function(username, password, path = users_file()) {
  err <- check_password(password)
  if (length(err)) stop(err)
  u <- read_users(path)
  i <- find_user(u, username)
  if (length(i) != 1) stop("No user ", username, ".")
  u$password_hash[i] <- sodium::password_store(password)
  write_users(u, path)
}

delete_user <- function(username, path = users_file()) {
  u <- read_users(path)
  i <- find_user(u, username)
  if (length(i) != 1) stop("No user ", username, ".")
  if (u$role[i] == "admin" && sum(u$role == "admin") == 1) stop("The last admin cannot be deleted.")
  write_users(u[-i, , drop = FALSE], path)
}

# Creates the first admin when there are no users yet. Returns TRUE when
# the app has at least one user afterwards.
bootstrap_users <- function(path = users_file()) {
  if (nrow(read_users(path))) return(TRUE)
  user <- Sys.getenv("SPORTS_ADMIN_USER")
  pass <- Sys.getenv("SPORTS_ADMIN_PASSWORD")
  if (!nzchar(user) || !nzchar(pass)) return(FALSE)
  add_user(user, pass, "admin", path)
  TRUE
}
