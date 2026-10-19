# Sports Analytics global config
#
# Packages, settings and the code loader. app.R sources this file first; the
# unit tests and scraper/run_scrape.R load the same folders through
# load_app_code().

# Bumped by .github/workflows/auto-version-bump.yml when a PR is merged into
# main; docs/VERSION_HISTORY.md lists what each version has.
APP_VERSION <- "0.1.0"

suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(bsicons)
  library(reactable)
  library(plotly)
  library(shinyjs)
})

# Local runs only: .env.local can hold SPORTS_* settings (see README.md). It
# is never committed or deployed. A variable already set in the environment
# wins, so the browser tests can point the app at their own files.
if (file.exists(".env.local") && !nzchar(Sys.getenv("CONNECT_SERVER"))) {
  local({
    kv <- grep("^\\s*[A-Za-z_][A-Za-z0-9_]*\\s*=", readLines(".env.local", warn = FALSE), value = TRUE)
    keys <- trimws(sub("=.*", "", kv))
    vals <- gsub("^[\"']|[\"']$", "", trimws(sub("^[^=]*=", "", kv)))
    new <- !nzchar(Sys.getenv(keys))
    if (any(new)) do.call(Sys.setenv, as.list(stats::setNames(vals[new], keys[new])))
  })
}

options(shiny.maxRequestSize = 5 * 1024^2)

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (is.atomic(a) && length(a) == 1 && is.na(a))) b else a

# The app's code, by folder (see README.md, Code layout):
#   access/    data, users and the stats.gleague.nba.com scraper
#   engine/    shooting metrics, player types, court geometry (no Shiny)
#   modules/   the Shiny screens
# Files in a folder are sourced in name order, so a new file needs no change
# here. There is no R/ folder on purpose: Shiny would source it by itself.
source_dir <- function(dir) {
  for (f in sort(list.files(dir, pattern = "\\.R$", full.names = TRUE))) source(f, local = FALSE)
}
load_app_code <- function(dirs = c("access", "engine")) {
  for (d in dirs) source_dir(d)
}
