# Player profile: key numbers, the shot chart against the league, each
# zone's FG% with its percentile, and the shot diet against the league's.
# `focus` is a reactiveVal set by other screens (list(player, at)) to open a
# player here.

profile_ui <- function(id) {
  ns <- NS(id)
  tagList(
    div(class = "app-filter-row app-filter-bar",
        selectizeInput(ns("player"), "Player", choices = NULL,
                       options = list(placeholder = "Type a name")),
        numericInput(ns("min_zone"), "Percentile: minimum zone attempts per game",
                     value = 0.5, min = 0, max = 5, step = 0.1)),
    uiOutput(ns("tiles")),
    layout_columns(
      col_widths = c(6, 6),
      card(full_screen = TRUE,
           card_header("Shot chart vs league"),
           card_body(plotlyOutput(ns("chart"), height = "430px"), diff_legend())),
      card(card_header("By zone"),
           card_body(reactableOutput(ns("zones"))))
    ),
    card(card_header("Shot diet vs league"),
         card_body(plotlyOutput(ns("diet"), height = "170px")))
  )
}

profile_server <- function(id, data, focus) {
  moduleServer(id, function(input, output, session) {
    observe({
      m <- data$metrics()
      cur <- isolate(input$player)
      sel <- if (isTRUE(cur %in% m$player)) cur else m$player[which.max(m$fga)]
      updateSelectizeInput(session, "player", choices = m$player, selected = sel, server = TRUE)
    })
    observeEvent(focus(), {
      updateSelectizeInput(session, "player", choices = data$metrics()$player,
                           selected = focus()$player, server = TRUE)
    })

    me <- reactive({
      m <- data$metrics()
      req(input$player %in% m$player)
      m[m$player == input$player, ]
    })
    profile <- reactive({
      req(me())
      zone_profile(data$long(), me()$player, input$min_zone %||% 0.5)
    })

    output$tiles <- renderUI({
      p <- me()
      lg <- shot_totals(data$long())
      vs <- function(x, l) sprintf("League %s", fmt_pct(l))
      layout_column_wrap(
        width = "150px", class = "mb-3",
        stat_tile("Team", p$team),
        stat_tile("Attempts per game", fmt_num(p$fga), sprintf("%s made", fmt_num(p$fgm))),
        stat_tile("FG%", fmt_pct(p$fg_pct), vs(p$fg_pct, lg$fg_pct)),
        stat_tile("eFG%", fmt_pct(p$efg), vs(p$efg, lg$efg)),
        stat_tile("Points per shot", fmt_num(p$pts_per_shot, 2), sprintf("League %s", fmt_num(lg$pts_per_shot, 2))),
        stat_tile("3PA rate", fmt_pct(p$fg3a_rate), vs(p$fg3a_rate, lg$fg3a_rate))
      )
    })

    output$chart <- renderPlotly(shot_chart(profile()))

    output$zones <- renderReactable({
      z <- profile()[c("label", "fgm", "fga", "pct", "league_pct", "diff", "percentile")]
      app_table(
        z, pagination = FALSE, sortable = FALSE,
        columns = list(
          label = colDef(name = "Zone", minWidth = 120),
          fgm = col_num("FGM"),
          fga = col_num("FGA"),
          pct = col_pct("FG%"),
          league_pct = col_pct("League"),
          diff = colDef(name = "Diff", align = "right", minWidth = 56, na = "-",
                        cell = function(v) if (is.na(v)) "-" else sprintf("%+.1f", 100 * v)),
          percentile = colDef(name = "Pctl", align = "right", minWidth = 56, na = "-",
                              cell = function(v) if (is.na(v)) "-" else ordinal(round(v)))
        )
      )
    })

    output$diet <- renderPlotly({
      p <- me()
      lg <- as.data.frame(shot_totals(data$long()))
      d <- rbind(data.frame(who = p$player, p[share_cols]),
                 data.frame(who = "League", lg[share_cols]))
      diet_bars(d, "who")
    })
  })
}
