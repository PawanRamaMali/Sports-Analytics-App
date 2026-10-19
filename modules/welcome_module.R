# Sign-in page. The navbar stays hidden (html.app-no-nav) until a user
# signs in. Five wrong passwords in a row lock the form for 30 seconds in
# this session. Returns a reactive with list(username, role), or NULL
# before sign-in.

welcome_ui <- function(id) {
  ns <- NS(id)
  div(
    class = "app-welcome",
    div(
      class = "app-welcome-brand",
      div(class = "app-welcome-mark", bs_icon("dribbble", size = "2.2rem")),
      tags$h1("Sports Analytics"),
      tags$p(class = "lead", "G League shooting by court zone: player profiles, comparisons, team tendencies and player types."),
      tags$ul(
        class = "app-welcome-points",
        tags$li(bs_icon("bullseye"), " Shot charts against the league average"),
        tags$li(bs_icon("people"), " Side-by-side player comparison"),
        tags$li(bs_icon("diagram-3"), " Player types from shot diet")
      )
    ),
    card(
      class = "app-signin",
      card_body(
        tags$h4("Sign in"),
        uiOutput(ns("setup_note")),
        textInput(ns("username"), "Username", width = "100%"),
        passwordInput(ns("password"), "Password", width = "100%"),
        actionButton(ns("signin"), "Sign in", class = "btn-primary w-100 mt-2",
                     icon = icon("right-to-bracket")),
        uiOutput(ns("message")),
        div(class = "app-version-note", paste0("Version ", APP_VERSION))
      )
    )
  )
}

welcome_server <- function(id, users_path = users_file()) {
  moduleServer(id, function(input, output, session) {
    user <- reactiveVal(NULL)
    failures <- reactiveVal(0)
    locked_until <- reactiveVal(Sys.time() - 1)
    message <- reactiveVal(NULL)

    output$setup_note <- renderUI({
      if (nrow(read_users(users_path))) return(NULL)
      div(class = "alert alert-warning small",
          "No users are set up yet. Set SPORTS_ADMIN_USER and SPORTS_ADMIN_PASSWORD and restart the app.")
    })

    observeEvent(input$signin, {
      if (Sys.time() < locked_until()) {
        message(sprintf("Too many failed attempts. Try again in %d seconds.",
                        ceiling(as.numeric(difftime(locked_until(), Sys.time(), units = "secs")))))
        return()
      }
      name <- trimws(input$username %||% "")
      pass <- input$password %||% ""
      if (!nzchar(name) || !nzchar(pass)) {
        message("Enter your username and password.")
        return()
      }
      u <- verify_login(name, pass, users_path)
      if (is.null(u)) {
        failures(failures() + 1)
        if (failures() >= 5) {
          failures(0)
          locked_until(Sys.time() + 30)
        }
        message("Incorrect username or password.")
        updateTextInput(session, "password", value = "")
        return()
      }
      message(NULL)
      updateTextInput(session, "password", value = "")
      user(u)
    })

    output$message <- renderUI({
      m <- message()
      if (is.null(m)) return(NULL)
      div(class = "alert alert-danger small mt-3 mb-0", role = "alert", m)
    })

    user
  })
}
