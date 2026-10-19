# Starts the app for the browser tests (playwright.config.ts runs this from
# the repo root). It gets its own users file and a copy of the seasons under
# e2e/.tmp, so a test run never touches data/. The users match
# e2e/helpers.ts.

tmp <- file.path("e2e", ".tmp")
unlink(tmp, recursive = TRUE)
dir.create(file.path(tmp, "seasons"), recursive = TRUE)
file.copy(list.files("data/seasons", pattern = "\\.csv$", full.names = TRUE), file.path(tmp, "seasons"))

Sys.setenv(
  SPORTS_DATA_DIR = normalizePath(file.path(tmp, "seasons")),
  SPORTS_USERS_FILE = file.path(normalizePath(tmp), "users.csv"),
  SPORTS_ADMIN_USER = "",
  SPORTS_ADMIN_PASSWORD = ""
)

suppressWarnings(source("global.R"))
load_app_code("access")
add_user("e2e-admin", "e2e-admin-pass", "admin")
add_user("e2e-analyst", "e2e-analyst-pass", "analyst")

shiny::runApp(".", host = "127.0.0.1", port = as.integer(Sys.getenv("E2E_PORT", "3839")),
              launch.browser = FALSE)
