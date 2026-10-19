# Players: every player of the season with their key shooting numbers,
# filtered by team and attempts per game. Clicking a row opens the player's
# profile (open_player()).

players_ui <- function(id) {
  ns <- NS(id)
  card(
    full_screen = TRUE,
    card_header(
      class = "app-filter-row",
      selectizeInput(ns("teams"), "Teams", choices = NULL, multiple = TRUE,
                     options = list(placeholder = "All teams")),
      sliderInput(ns("min_fga"), "Minimum attempts per game", min = 0, max = 15, value = 3, step = 0.5),
      div(class = "app-filter-end",
          downloadButton(ns("download"), "CSV", class = "btn-outline-secondary btn-sm"))
    ),
    card_body(
      tags$p(class = "small text-muted mb-1",
             "Per-game numbers. Click a player to open their profile."),
      reactableOutput(ns("table"))
    )
  )
}

players_server <- function(id, data, open_player) {
  moduleServer(id, function(input, output, session) {
    observe({
      m <- data$metrics()
      updateSelectizeInput(session, "teams", choices = sort(unique(m$team)),
                           selected = intersect(isolate(input$teams), m$team))
    })

    rows <- reactive({
      m <- data$metrics()
      m <- m[m$fga >= input$min_fga, ]
      if (length(input$teams)) m <- m[m$team %in% input$teams, ]
      m[order(-m$fga), c("player", "team", "fga", "fg_pct", "efg", "pts_per_shot",
                         "fg3a_rate", "rim_pct", "mid_pct", "fg3_pct")]
    })

    output$table <- renderReactable({
      d <- rows()
      app_table(
        d, searchable = TRUE,
        click = row_click_js(session$ns("open")),
        columns = list(
          player = colDef(name = "Player", minWidth = 160, sticky = "left"),
          team = colDef(name = "Team", minWidth = 70),
          fga = col_num("FGA"),
          fg_pct = col_pct("FG%"),
          efg = col_pct("eFG%"),
          pts_per_shot = col_num("Pts/shot", 2),
          fg3a_rate = col_pct("3PA rate"),
          rim_pct = col_pct("Rim FG%"),
          mid_pct = col_pct("Mid FG%"),
          fg3_pct = col_pct("3P FG%")
        ),
        language = reactableLang(searchPlaceholder = "Search players", noData = "No players match these filters.")
      )
    })

    observeEvent(input$open, open_player(input$open))

    output$download <- downloadHandler(
      filename = function() sprintf("players-%s.csv", data$season()),
      content = function(file) utils::write.csv(rows(), file, row.names = FALSE)
    )
  })
}
