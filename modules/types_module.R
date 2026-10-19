# Player types: players grouped by shot diet with k-means (engine/styles.R).
# The scatter places each player by inside share (rim + paint) and 3-point
# attempt rate; colour and marker shape both mark the type.

types_ui <- function(id) {
  ns <- NS(id)
  tagList(
    div(class = "app-filter-row app-filter-bar",
        sliderInput(ns("k"), "Number of types", min = 3, max = 5, value = 4, step = 1),
        sliderInput(ns("min_fga"), "Minimum attempts per game", min = 1, max = 10, value = 3, step = 0.5)),
    layout_columns(
      col_widths = c(6, 6),
      card(full_screen = TRUE, card_header("Players by shot diet"),
           card_body(plotlyOutput(ns("scatter"), height = "460px"))),
      card(card_header("Types"),
           card_body(tags$p(class = "small text-muted mb-1",
                            "Average share of attempts from each area. Click a type to list its players."),
                     reactableOutput(ns("centers"))))
    ),
    card(card_header(textOutput(ns("members_title"), inline = TRUE)),
         card_body(reactableOutput(ns("members"))))
  )
}

types_server <- function(id, data, open_player) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    types <- reactive({
      t <- player_types(data$metrics(), input$k, input$min_fga)
      validate(need(!is.null(t), "Too few players for that many types; lower the minimum attempts."))
      t
    })
    picked <- reactiveVal(NULL)
    observeEvent(input$type, picked(input$type))
    observeEvent(types(), if (!isTRUE(picked() %in% levels(types()$players$type))) picked(NULL))

    output$scatter <- renderPlotly({
      d <- types()$players
      d$inside <- d$share_rim + d$share_paint
      lv <- levels(d$type)
      p <- plot_ly()
      for (i in seq_along(lv)) {
        s <- d[d$type == lv[i], ]
        p <- add_markers(p, x = s$inside, y = s$fg3a_rate, name = lv[i],
                         marker = list(color = series_colors[i], symbol = type_symbols[i], size = 9,
                                       line = list(color = "#ffffff", width = 1.5)),
                         hovertext = sprintf("<b>%s</b> (%s)<br>%s<br>Inside %s, 3PA rate %s<br>%s attempts per game",
                                             s$player, s$team, lv[i], fmt_pct(s$inside),
                                             fmt_pct(s$fg3a_rate), fmt_num(s$fga)),
                         hoverinfo = "text")
      }
      p |>
        layout(xaxis = pct_axis("Share of attempts at the rim or in the paint", range = c(0, 1)),
               yaxis = pct_axis("3-point attempt rate", range = c(0, 1)),
               margin = list(l = 60, b = 50)) |>
        plot_defaults()
    })

    output$centers <- renderReactable({
      c <- types()$centers
      c$type <- as.character(c$type)
      cols <- stats::setNames(lapply(names(diet_groups), function(g) col_pct(diet_groups[[g]], minWidth = 60)),
                              names(diet_groups))
      app_table(
        c, pagination = FALSE, sortable = FALSE,
        click = row_click_js(ns("type"), "type"),
        columns = c(list(
          type = colDef(name = "Type", minWidth = 170, cell = function(v, i) {
            tags$span(tags$span(class = "app-key", style = paste0("background:", series_colors[i])), v)
          }),
          players = colDef(name = "Players", align = "right", minWidth = 60)), cols)
      )
    })

    output$members_title <- renderText({
      if (is.null(picked())) "All players" else paste("Players:", picked())
    })

    output$members <- renderReactable({
      d <- types()$players
      if (!is.null(picked())) d <- d[d$type == picked(), ]
      d$type <- as.character(d$type)
      d <- d[order(-d$fga), c("player", "team", "type", "fga", "efg", "fg3a_rate")]
      app_table(
        d, searchable = TRUE,
        click = row_click_js(ns("open")),
        columns = list(
          player = colDef(name = "Player", minWidth = 160),
          team = colDef(name = "Team"),
          type = colDef(name = "Type", minWidth = 150),
          fga = col_num("FGA"),
          efg = col_pct("eFG%"),
          fg3a_rate = col_pct("3PA rate")
        )
      )
    })

    observeEvent(input$open, open_player(input$open))
  })
}
