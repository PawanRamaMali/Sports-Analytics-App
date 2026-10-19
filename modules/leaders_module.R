# Leaders: the best players by a metric or a zone's FG%, with a minimum of
# attempts per game so a 1-for-1 does not top the list.

leader_choices <- c(
  stats::setNames(leader_metrics$id, leader_metrics$label),
  stats::setNames(paste0("zone:", shot_zones$id), paste("FG%:", shot_zones$label))
)

leaders_ui <- function(id) {
  ns <- NS(id)
  tagList(
    div(class = "app-filter-row app-filter-bar",
        selectInput(ns("metric"), "Metric", choices = list(
          Overall = leader_choices[!startsWith(leader_choices, "zone:")],
          `By zone` = leader_choices[startsWith(leader_choices, "zone:")])),
        sliderInput(ns("min_fga"), "Minimum attempts per game", min = 0, max = 10, value = 3, step = 0.5),
        selectInput(ns("n"), "Show", choices = c("Top 10" = 10, "Top 20" = 20, "Top 50" = 50), width = "120px")),
    layout_columns(
      col_widths = c(7, 5),
      card(full_screen = TRUE, card_header(textOutput(ns("title"), inline = TRUE)),
           card_body(plotlyOutput(ns("chart"), height = "520px"))),
      card(card_header("Table"),
           card_body(tags$p(class = "small text-muted mb-1", "Click a player to open their profile."),
                     reactableOutput(ns("table"))))
    )
  )
}

leaders_server <- function(id, data, open_player) {
  moduleServer(id, function(input, output, session) {
    # A zone's minimum is per zone, so its slider default is lower.
    observeEvent(input$metric, {
      zone <- startsWith(input$metric, "zone:")
      if (zone && input$min_fga > 2) updateSliderInput(session, "min_fga", value = 1)
    }, ignoreInit = TRUE)

    is_pct <- reactive({
      startsWith(input$metric, "zone:") || leader_metrics$fmt[leader_metrics$id == input$metric] == "pct"
    })
    label <- reactive(names(leader_choices)[leader_choices == input$metric])
    board <- reactive(leaderboard(data$long(), input$metric, input$min_fga, as.integer(input$n)))

    output$title <- renderText(label())

    output$chart <- renderPlotly({
      b <- board()
      validate(need(nrow(b) > 0, "No player has that many attempts."))
      txt <- if (is_pct()) fmt_pct(b$value) else fmt_num(b$value, 2)
      plot_ly(x = b$value, y = b$player, type = "bar", orientation = "h",
              marker = list(color = series_colors[1]), text = txt, textposition = "outside",
              textfont = list(color = ink$primary, size = 11), cliponaxis = FALSE,
              hovertext = sprintf("%s (%s)<br>%s: %s<br>%s attempts per game", b$player, b$team,
                                  label(), txt, fmt_num(b$attempts)),
              hoverinfo = "text") |>
        layout(xaxis = c(if (is_pct()) pct_axis() else list(gridcolor = ink$grid, color = ink$muted),
                         list(fixedrange = TRUE, rangemode = "tozero")),
               yaxis = list(categoryorder = "array", categoryarray = rev(b$player), title = NULL,
                            color = ink$primary, fixedrange = TRUE, automargin = TRUE),
               bargap = 0.45, margin = list(r = 50)) |>
        plot_defaults(legend = FALSE)
    })

    output$table <- renderReactable({
      b <- board()
      b <- cbind(rank = seq_len(nrow(b)), b)
      app_table(
        b, pagination = FALSE, sortable = FALSE,
        click = row_click_js(session$ns("open")),
        columns = list(
          rank = colDef(name = "#", width = 45),
          player = colDef(name = "Player", minWidth = 150),
          team = colDef(name = "Team", width = 70),
          value = if (is_pct()) col_pct(label()) else col_num(label(), 2),
          attempts = col_num(if (startsWith(input$metric, "zone:")) "Zone FGA" else "FGA")
        )
      )
    })

    observeEvent(input$open, open_player(input$open))
  })
}
