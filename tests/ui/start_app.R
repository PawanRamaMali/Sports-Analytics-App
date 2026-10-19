# Starts the app for the UI tests (conftest.py runs this from the repo root
# with SPORTS_DATA_DIR and SPORTS_USERS_FILE pointing at a temporary copy, so
# a test run never touches data/). The users match USERS in helpers.py.

Sys.setenv(SPORTS_ADMIN_USER = "", SPORTS_ADMIN_PASSWORD = "")

suppressWarnings(source("global.R"))
load_app_code("access")
add_user("e2e-admin", "e2e-admin-pass", "admin")
add_user("e2e-analyst", "e2e-analyst-pass", "analyst")

shiny::runApp(".", host = "127.0.0.1", port = as.integer(Sys.getenv("UI_PORT", "3839")),
              launch.browser = FALSE)
