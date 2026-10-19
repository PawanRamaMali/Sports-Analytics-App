# Teams: each team's shooting, added up from its players' per-game numbers,
# and its shot diet. Clicking a team shows its roster; clicking a player
# there opens the profile.

teams_ui <- function(id) {
  ns <- NS(id)
  tagList(
    layout_columns(
      col_widths = c(7, 5),
      card(full_screen = TRUE,
           card_header("Teams"),
           card_body(tags$p(class = "small text-muted mb-1",
                            "Sums of the players' per-game numbers. Click a team to see its roster."),
                     reactableOutput(ns("table")))),
      card(full_screen = TRUE,
           card_header("Shot diet, most 3s first"),
           card_body(plotlyOutput(ns("diet"), height = "520px")))
    ),
    uiOutput(ns("roster_card"))
  )
}

teams_server <- function(id, data, open_player) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    teams <- reactive(team_metrics(data$long()))
    picked <- reactiveVal(NULL)
    observeEvent(data$season(), picked(NULL))
    observeEvent(input$team, picked(input$team))

    output$table <- renderReactable({
      d <- teams()[c("team", "players", "fga", "fg_pct", "efg", "pts_per_shot", "fg3a_rate")]
      app_table(
        d[order(-d$efg), ], pagination = FALSE,
        click = row_click_js(ns("team"), "team"),
        columns = list(
          team = colDef(name = "Team"),
          players = colDef(name = "Players", align = "right"),
          fga = col_num("FGA"),
          fg_pct = col_pct("FG%"),
          efg = col_pct("eFG%"),
          pts_per_shot = col_num("Pts/shot", 2),
          fg3a_rate = col_pct("3PA rate")
        )
      )
    })

    output$diet <- renderPlotly({
      d <- teams()
      diet_bars(d[order(-d$fg3a_rate), ], "team")
    })

    output$roster_card <- renderUI({
      t <- picked()
      if (is.null(t)) return(NULL)
      card(card_header(paste("Roster:", t)),
           card_body(reactableOutput(ns("roster"))))
    })

    output$roster <- renderReactable({
      req(picked())
      m <- data$metrics()
      m <- m[m$team == picked(), c("player", "fga", "fg_pct", "efg", "pts_per_shot", "fg3a_rate")]
      app_table(
        m[order(-m$fga), ], pagination = FALSE,
        click = row_click_js(ns("open")),
        columns = list(
          player = colDef(name = "Player", minWidth = 160),
          fga = col_num("FGA"),
          fg_pct = col_pct("FG%"),
          efg = col_pct("eFG%"),
          pts_per_shot = col_num("Pts/shot", 2),
          fg3a_rate = col_pct("3PA rate")
        )
      )
    })

    observeEvent(input$open, open_player(input$open))
  })
}
