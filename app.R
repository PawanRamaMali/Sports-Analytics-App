# Sports Analytics
# G League shooting by court zone. After sign-in: Players, Player profile,
# Compare, Teams, Leaders and Player types for the season picked in the
# navbar; admins also get Admin > Data (fetch or import seasons) and
# Admin > Users.

source("global.R", local = FALSE)
load_app_code(c("access", "engine", "modules"))

APP_TITLE <- "Sports Analytics"

cat(sprintf("%s version %s  |  Started at %s\n", APP_TITLE, APP_VERSION,
            format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
if (!bootstrap_users()) {
  warning("No users yet: set SPORTS_ADMIN_USER and SPORTS_ADMIN_PASSWORD to create the first admin.")
}

# Browsers cache www/ files, so their URLs carry the file time: a changed
# file is fetched again instead of running a stale copy.
www_url <- function(file) {
  sprintf("%s?v=%d", file, as.integer(file.mtime(file.path("www", file))))
}

# ---- UI --------------------------------------------------------------

ui <- page_navbar(
  id = "main_nav",
  title = tags$span(class = "app-title", bs_icon("dribbble"), " ", APP_TITLE,
                    tags$span(class = "app-version-chip", paste0("v", APP_VERSION))),
  window_title = APP_TITLE,
  selected = "welcome",
  theme = app_theme(),
  header = tagList(
    tags$head(
      # Hides the navbar until sign-in; set before the page paints.
      tags$script(HTML("document.documentElement.classList.add('app-no-nav');")),
      tags$link(rel = "stylesheet", href = www_url("style.css")),
      tags$script(src = www_url("app.js"))
    ),
    useShinyjs(),
    useBusyIndicators(spinners = TRUE, pulse = TRUE)
  ),

  nav_panel_hidden("welcome", welcome_ui("welcome")),
  nav_panel("Players", value = "players", icon = bs_icon("people"), players_ui("players")),
  nav_panel("Player profile", value = "profile", icon = bs_icon("person-badge"), profile_ui("profile")),
  nav_panel("Compare", value = "compare", icon = bs_icon("layout-split"), compare_ui("compare")),
  nav_panel("Teams", value = "teams", icon = bs_icon("shield"), teams_ui("teams")),
  nav_panel("Leaders", value = "leaders", icon = bs_icon("trophy"), leaders_ui("leaders")),
  nav_panel("Player types", value = "types", icon = bs_icon("diagram-3"), types_ui("types")),

  nav_spacer(),
  nav_item(div(class = "app-season", selectInput("season", NULL, choices = NULL, width = "120px"))),
  nav_item(uiOutput("user_chip", inline = TRUE)),
  nav_item(actionLink("signout", tagList(bs_icon("box-arrow-right"), " Sign out"), class = "app-signout"))
)

# ---- Server ---------------------------------------------------------

server <- function(input, output, session) {

  # ---- Sign in / out ---------------------------------------------------
  user <- welcome_server("welcome")
  signed_in <- reactive(!is.null(user()))
  # The role is read from the users file again for every admin action, so
  # an admin who was demoted meanwhile cannot keep changing things.
  is_admin <- function() {
    u <- read_users()
    i <- find_user(u, isolate(user())$username)
    length(i) == 1 && u$role[i] == "admin"
  }

  observeEvent(user(), {
    u <- user()
    shinyjs::runjs("document.documentElement.classList.remove('app-no-nav');")
    nav_select("main_nav", "players")
    if (u$role == "admin") {
      nav_insert("main_nav", target = "types", position = "after",
                 nav_menu("Admin", value = "admin", icon = bs_icon("gear"),
                          nav_panel("Data", value = "admin_data", admin_data_ui("admin_data")),
                          nav_panel("Users", value = "admin_users", admin_users_ui("admin_users"))))
      admin_data_server("admin_data", is_admin, on_change = function() data_version(data_version() + 1))
      admin_users_server("admin_users", me = reactive(user()$username), is_admin)
    }
  }, once = TRUE)

  # Sign-in lives in the session, so a reload signs out.
  observeEvent(input$signout, session$reload())

  output$user_chip <- renderUI({
    u <- user()
    req(u)
    tags$span(class = "app-user", bs_icon("person-circle"), " ", u$username,
              tags$span(class = "app-role", user_roles[[u$role]]))
  })

  # ---- Season data -------------------------------------------------------
  data_version <- reactiveVal(0)
  seasons <- reactive({
    data_version()
    list_seasons()
  })
  observe({
    req(signed_in())
    s <- seasons()
    cur <- isolate(input$season)
    updateSelectInput(session, "season", choices = s, selected = if (isTRUE(cur %in% s)) cur else s[1])
  })

  shots <- reactive({
    req(signed_in(), input$season)
    data_version()
    tryCatch(read_season(input$season), error = function(e) {
      showNotification(conditionMessage(e), type = "error", duration = NULL)
      NULL
    })
  })
  long <- reactive({
    req(shots())
    shots_long(shots())
  })
  data <- list(
    season = reactive(input$season),
    long = long,
    metrics = reactive(player_metrics(long()))
  )

  # ---- Screens -----------------------------------------------------------
  focus <- reactiveVal(NULL)
  open_player <- function(name) {
    focus(list(player = name, at = Sys.time()))
    # Called from inside modules: the app session, not the module's.
    nav_select("main_nav", "profile", session = session)
  }

  players_server("players", data, open_player)
  profile_server("profile", data, focus)
  compare_server("compare", data)
  teams_server("teams", data, open_player)
  leaders_server("leaders", data, open_player)
  types_server("types", data, open_player)
}

shinyApp(ui, server)
