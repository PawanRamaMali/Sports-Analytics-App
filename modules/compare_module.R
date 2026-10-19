# Compare: up to three players side by side, zone FG% against the league
# average, key numbers and shot diets. A player keeps their colour while
# they stay selected, so removing one does not repaint the others.

compare_ui <- function(id) {
  ns <- NS(id)
  tagList(
    div(class = "app-filter-row app-filter-bar",
        selectizeInput(ns("players"), "Players (up to 3)", choices = NULL, multiple = TRUE,
                       width = "520px",
                       options = list(maxItems = 3, placeholder = "Type names"))),
    uiOutput(ns("body"))
  )
}

compare_server <- function(id, data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    observe({
      m <- data$metrics()
      updateSelectizeInput(session, "players", choices = m$player, server = TRUE,
                           selected = intersect(isolate(input$players), m$player))
    })

    # Colour slot per player, kept while the player stays selected.
    slots <- reactiveVal(character())
    observe({
      sel <- input$players %||% character()
      s <- slots()
      s[!s %in% sel] <- NA
      for (p in setdiff(sel, s)) {
        free <- which(is.na(s))
        if (length(free)) s[free[1]] <- p else s <- c(s, p)
      }
      slots(s)
    })
    color_of <- function(p) series_colors[match(p, slots())]

    chosen <- reactive({
      sel <- input$players
      req(length(sel) > 0)
      m <- data$metrics()
      m[match(sel, m$player), ]
    })

    output$body <- renderUI({
      if (!length(input$players)) {
        return(card(card_body(empty_state("people", "Pick players to compare",
                                          "Choose up to three players above."))))
      }
      tagList(
        card(full_screen = TRUE,
             card_header("FG% by zone"),
             card_body(plotlyOutput(ns("zones"), height = "360px"),
                       tags$p(class = "small text-muted mb-0",
                              "Gray ticks mark the league average. Zones with no attempts have no bar."))),
        layout_columns(
          col_widths = c(6, 6),
          card(card_header("Key numbers"), card_body(reactableOutput(ns("table")))),
          card(card_header("Shot diet"), card_body(plotlyOutput(ns("diet"), height = "220px")))
        )
      )
    })

    output$zones <- renderPlotly({
      sel <- chosen()$player
      long <- data$long()
      league <- league_zone_avg(long)
      p <- plot_ly()
      for (pl in sel) {
        d <- long[long$player == pl, ]
        d <- d[match(shot_zones$id, d$zone), ]
        d$label <- shot_zones$label
        # Zones without attempts get no bar.
        d <- d[!is.na(d$pct), ]
        p <- add_bars(p, x = d$label, y = d$pct, name = pl,
                      marker = list(color = color_of(pl), line = list(color = "#ffffff", width = 2)),
                      hovertext = sprintf("%s<br>%s: %s (%s of %s per game)", pl, d$label,
                                          fmt_pct(d$pct), fmt_num(d$fgm), fmt_num(d$fga)),
                      hoverinfo = "text")
      }
      lg <- !is.na(league$pct)
      p |>
        add_markers(x = shot_zones$label[lg], y = league$pct[lg], name = "League average",
                    marker = list(symbol = "line-ew-open", size = 34, color = ink$muted,
                                  line = list(width = 3, color = ink$muted)),
                    hovertext = sprintf("League %s: %s", shot_zones$label[lg], fmt_pct(league$pct[lg])),
                    hoverinfo = "text") |>
        layout(barmode = "group", bargap = 0.25,
               xaxis = list(categoryorder = "array", categoryarray = shot_zones$label,
                            title = NULL, color = ink$primary, fixedrange = TRUE),
               yaxis = pct_axis(range = c(0, 1), fixedrange = TRUE)) |>
        plot_defaults()
    })

    output$table <- renderReactable({
      d <- chosen()[c("player", "team", "fga", "fg_pct", "efg", "pts_per_shot", "fg3a_rate")]
      app_table(
        d, pagination = FALSE, sortable = FALSE,
        columns = list(
          player = colDef(name = "Player", minWidth = 150, cell = function(v) {
            tags$span(tags$span(class = "app-key", style = paste0("background:", color_of(v))), v)
          }),
          team = colDef(name = "Team"),
          fga = col_num("FGA"),
          fg_pct = col_pct("FG%"),
          efg = col_pct("eFG%"),
          pts_per_shot = col_num("Pts/shot", 2),
          fg3a_rate = col_pct("3PA rate")
        )
      )
    })

    output$diet <- renderPlotly(diet_bars(chosen(), "player"))
  })
}
