# Season files: one CSV per season in data_dir(), named <season>.csv (for
# example 2020-21.csv), with the columns in `shot_columns` (engine/catalog.R).
# The scraper, the admin upload and the app all go through these functions.

data_dir <- function() Sys.getenv("SPORTS_DATA_DIR", "data/seasons")

# Season ids are also file names, so only YYYY-YY is accepted.
valid_season <- function(season) {
  is.character(season) && length(season) == 1 && grepl("^[0-9]{4}-[0-9]{2}$", season) &&
    (as.integer(substr(season, 3, 4)) + 1) %% 100 == as.integer(substr(season, 6, 7))
}

season_path <- function(season, dir = data_dir()) {
  if (!valid_season(season)) stop("Invalid season: ", season)
  file.path(dir, paste0(season, ".csv"))
}

list_seasons <- function(dir = data_dir()) {
  s <- sub("\\.csv$", "", list.files(dir, pattern = "^[0-9]{4}-[0-9]{2}\\.csv$"))
  sort(s[vapply(s, valid_season, logical(1))], decreasing = TRUE)
}

# Problems with a shot data frame, as a character vector (empty when valid).
validate_shot_data <- function(df) {
  if (!is.data.frame(df)) return("Not a table.")
  missing <- setdiff(shot_columns, names(df))
  if (length(missing)) {
    return(sprintf("Missing column%s: %s", if (length(missing) > 1) "s" else "",
                   paste(utils::head(missing, 5), collapse = ", ")))
  }
  errs <- character()
  if (!nrow(df)) errs <- c(errs, "No players.")
  if (anyNA(df$PLAYER_NAME) || any(!nzchar(trimws(df$PLAYER_NAME)))) errs <- c(errs, "Some players have no name.")
  if (anyDuplicated(df$PLAYER_NAME)) errs <- c(errs, "Some players appear more than once.")
  bad <- zone_columns[!vapply(df[zone_columns], function(v)
    all(is.na(v) | !is.na(suppressWarnings(as.numeric(v)))), logical(1))]
  if (length(bad)) errs <- c(errs, paste("Not numeric:", paste(utils::head(bad, 5), collapse = ", ")))
  num <- suppressWarnings(vapply(df[zone_columns], function(v) min(as.numeric(v), na.rm = TRUE), numeric(1)))
  if (any(num < 0, na.rm = TRUE)) errs <- c(errs, "Negative makes, attempts or percentages.")
  pct <- unlist(df[grepl("_FG_PCT$", names(df))])
  if (any(suppressWarnings(as.numeric(pct)) > 1, na.rm = TRUE)) {
    errs <- c(errs, "FG% must be a fraction between 0 and 1.")
  }
  errs
}

# Keeps the known columns in their order, with numbers as numbers.
normalise_shot_data <- function(df) {
  df <- df[shot_columns]
  df$PLAYER_NAME <- trimws(as.character(df$PLAYER_NAME))
  df$TEAM_ABBREVIATION <- trimws(as.character(df$TEAM_ABBREVIATION))
  df[zone_columns] <- lapply(df[zone_columns], function(v) suppressWarnings(as.numeric(v)))
  # Byte order, not locale order, so a file written on any machine is the same.
  df <- df[order(df$PLAYER_NAME, method = "radix"), ]
  rownames(df) <- NULL
  df
}

read_season <- function(season, dir = data_dir()) {
  df <- utils::read.csv(season_path(season, dir), check.names = FALSE, stringsAsFactors = FALSE)
  errs <- validate_shot_data(df)
  if (length(errs)) stop(sprintf("Season %s: %s", season, paste(errs, collapse = " ")))
  normalise_shot_data(df)
}

# Validates, then writes through a temporary file so a reader never sees a
# half-written season.
write_season <- function(df, season, dir = data_dir()) {
  errs <- validate_shot_data(df)
  if (length(errs)) stop(paste(errs, collapse = " "))
  path <- season_path(season, dir)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  tmp <- tempfile(tmpdir = dir, fileext = ".tmp")
  on.exit(unlink(tmp))
  utils::write.csv(normalise_shot_data(df), tmp, row.names = FALSE, na = "", eol = "\n")
  if (!file.rename(tmp, path)) {
    file.copy(tmp, path, overwrite = TRUE)
  }
  invisible(path)
}

season_info <- function(dir = data_dir()) {
  s <- list_seasons(dir)
  if (!length(s)) {
    return(data.frame(season = character(), players = integer(), teams = integer(),
                      updated = as.POSIXct(character())))
  }
  rows <- lapply(s, function(x) {
    df <- tryCatch(read_season(x, dir), error = function(e) NULL)
    data.frame(season = x,
               players = if (is.null(df)) NA_integer_ else nrow(df),
               teams = if (is.null(df)) NA_integer_ else length(unique(df$TEAM_ABBREVIATION)),
               updated = file.mtime(season_path(x, dir)))
  })
  do.call(rbind, rows)
}
