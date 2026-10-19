# Admin > Data: the season files, fetching a season from
# stats.gleague.nba.com and importing a CSV. Only started for admins, and
# every action checks the role again. on_change() tells the app to reload
# the season list and data.

admin_data_ui <- function(id) {
  ns <- NS(id)
  tagList(
    card(card_header("Seasons"),
         card_body(reactableOutput(ns("seasons")))),
    layout_columns(
      col_widths = c(6, 6),
      card(
        card_header("Fetch from stats.gleague.nba.com"),
        card_body(fillable = FALSE,
          tags$p(class = "small text-muted",
                 "Downloads per-game shot locations by zone and replaces the season's file."),
          textInput(ns("fetch_season"), "Season", placeholder = "2020-21"),
          selectInput(ns("fetch_type"), "Season type", c("Regular Season", "Playoffs")),
          actionButton(ns("fetch"), "Fetch season", class = "btn-primary", icon = icon("cloud-arrow-down")),
          uiOutput(ns("fetch_msg"))
        )
      ),
      card(
        card_header("Import a CSV"),
        card_body(fillable = FALSE,
          tags$p(class = "small text-muted",
                 "A file with PLAYER_NAME, TEAM_ABBREVIATION and FGM, FGA and FG_PCT for each zone,",
                 "as the scraper writes it. It replaces the season's file."),
          textInput(ns("import_season"), "Season", placeholder = "2021-22"),
          fileInput(ns("file"), "CSV file", accept = c(".csv", "text/csv")),
          actionButton(ns("import"), "Import", class = "btn-primary", icon = icon("file-import")),
          uiOutput(ns("import_msg"))
        )
      )
    )
  )
}

admin_data_server <- function(id, is_admin, on_change) {
  moduleServer(id, function(input, output, session) {
    version <- reactiveVal(0)
    changed <- function() {
      version(version() + 1)
      on_change()
    }
    result <- function(ok, msg) {
      div(class = paste("alert small mt-3 mb-0", if (ok) "alert-success" else "alert-danger"),
          role = if (ok) "status" else "alert", msg)
    }

    output$seasons <- renderReactable({
      version()
      s <- season_info()
      s$updated <- format(s$updated, "%Y-%m-%d %H:%M")
      app_table(s, pagination = FALSE, columns = list(
        season = colDef(name = "Season"),
        players = colDef(name = "Players", align = "right"),
        teams = colDef(name = "Teams", align = "right"),
        updated = colDef(name = "Updated")
      ), language = reactableLang(noData = "No seasons yet."))
    })

    fetch_msg <- reactiveVal(NULL)
    output$fetch_msg <- renderUI(fetch_msg())
    observeEvent(input$fetch, {
      req(is_admin())
      season <- trimws(input$fetch_season)
      if (!valid_season(season)) return(fetch_msg(result(FALSE, "Season must look like 2020-21.")))
      df <- tryCatch(withProgress(message = paste("Fetching", season), value = 0.3,
                                  fetch_shot_locations(season, input$fetch_type)),
                     error = function(e) e)
      if (inherits(df, "error")) return(fetch_msg(result(FALSE, conditionMessage(df))))
      write_season(df, season)
      changed()
      fetch_msg(result(TRUE, sprintf("Season %s saved: %d players.", season, nrow(df))))
    })

    import_msg <- reactiveVal(NULL)
    output$import_msg <- renderUI(import_msg())
    observeEvent(input$import, {
      req(is_admin())
      season <- trimws(input$import_season)
      if (!valid_season(season)) return(import_msg(result(FALSE, "Season must look like 2021-22.")))
      if (is.null(input$file)) return(import_msg(result(FALSE, "Choose a CSV file.")))
      df <- tryCatch(utils::read.csv(input$file$datapath, check.names = FALSE, stringsAsFactors = FALSE),
                     error = function(e) e)
      if (inherits(df, "error")) return(import_msg(result(FALSE, paste("Cannot read the file:", conditionMessage(df)))))
      errs <- validate_shot_data(df)
      if (length(errs)) return(import_msg(result(FALSE, paste(errs, collapse = " "))))
      write_season(df, season)
      changed()
      import_msg(result(TRUE, sprintf("Season %s imported: %d players.", season, nrow(df))))
    })
  })
}
