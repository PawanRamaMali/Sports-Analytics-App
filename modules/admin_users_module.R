# Admin > Users: list, add, change role, reset password and delete users.
# Only started for admins, and every action checks the role again. An admin
# cannot delete themselves, and the last admin cannot be removed
# (access/users.R).

admin_users_ui <- function(id) {
  ns <- NS(id)
  layout_columns(
    col_widths = c(7, 5),
    card(card_header("Users"),
         card_body(reactableOutput(ns("users")))),
    tagList(
      card(
        card_header("Add a user"),
        card_body(fillable = FALSE,
          textInput(ns("new_name"), "Username"),
          passwordInput(ns("new_pass"), "Password (at least 8 characters)"),
          selectInput(ns("new_role"), "Role", stats::setNames(names(user_roles), user_roles), selected = "analyst"),
          actionButton(ns("add"), "Add user", class = "btn-primary", icon = icon("user-plus")),
          uiOutput(ns("add_msg"))
        )
      ),
      card(
        card_header("Change a user"),
        card_body(fillable = FALSE,
          selectInput(ns("who"), "User", choices = NULL),
          selectInput(ns("role"), "Role", stats::setNames(names(user_roles), user_roles)),
          actionButton(ns("set_role"), "Save role", class = "btn-outline-primary btn-sm"),
          hr(),
          passwordInput(ns("reset_pass"), "New password"),
          actionButton(ns("reset"), "Reset password", class = "btn-outline-primary btn-sm"),
          hr(),
          actionButton(ns("delete"), "Delete user", class = "btn-outline-danger btn-sm", icon = icon("trash")),
          uiOutput(ns("change_msg"))
        )
      )
    )
  )
}

admin_users_server <- function(id, me, is_admin) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    version <- reactiveVal(0)
    users <- reactive({
      version()
      read_users()[c("username", "role", "created")]
    })
    result <- function(ok, msg) {
      div(class = paste("alert small mt-3 mb-0", if (ok) "alert-success" else "alert-danger"),
          role = if (ok) "status" else "alert", msg)
    }
    # Runs a change; an error from access/users.R becomes the message.
    attempt <- function(msg_out, expr, ok_msg) {
      req(is_admin())
      r <- tryCatch({ force(expr); TRUE }, error = function(e) conditionMessage(e))
      if (isTRUE(r)) {
        version(version() + 1)
        msg_out(result(TRUE, ok_msg))
      } else {
        msg_out(result(FALSE, r))
      }
      isTRUE(r)
    }

    output$users <- renderReactable({
      u <- users()
      u$role <- unname(user_roles[u$role])
      app_table(u, pagination = FALSE, columns = list(
        username = colDef(name = "Username"),
        role = colDef(name = "Role"),
        created = colDef(name = "Created")
      ))
    })

    observe({
      u <- users()
      updateSelectInput(session, "who", choices = u$username,
                        selected = if (isTRUE(isolate(input$who) %in% u$username)) isolate(input$who))
    })
    observeEvent(input$who, {
      u <- users()
      updateSelectInput(session, "role", selected = u$role[u$username == input$who])
    })

    add_msg <- reactiveVal(NULL)
    output$add_msg <- renderUI(add_msg())
    observeEvent(input$add, {
      name <- trimws(input$new_name)
      if (attempt(add_msg, add_user(name, input$new_pass, input$new_role), sprintf("User %s added.", name))) {
        updateTextInput(session, "new_name", value = "")
        updateTextInput(session, "new_pass", value = "")
      }
    })

    change_msg <- reactiveVal(NULL)
    output$change_msg <- renderUI(change_msg())
    observeEvent(input$set_role, {
      req(input$who)
      attempt(change_msg, set_user_role(input$who, input$role),
              sprintf("%s is now %s.", input$who, user_roles[[input$role]]))
    })
    observeEvent(input$reset, {
      req(input$who)
      if (attempt(change_msg, set_user_password(input$who, input$reset_pass),
                  sprintf("Password of %s reset.", input$who))) {
        updateTextInput(session, "reset_pass", value = "")
      }
    })
    observeEvent(input$delete, {
      req(input$who)
      if (tolower(input$who) == tolower(me())) {
        return(change_msg(result(FALSE, "You cannot delete yourself.")))
      }
      showModal(modalDialog(
        title = "Delete user",
        sprintf("Delete %s? They will no longer be able to sign in.", input$who),
        footer = tagList(modalButton("Cancel"),
                         actionButton(ns("confirm_delete"), "Delete", class = "btn-danger")),
        easyClose = TRUE
      ))
    })
    observeEvent(input$confirm_delete, {
      removeModal()
      who <- input$who
      attempt(change_msg, delete_user(who), sprintf("User %s deleted.", who))
    })
  })
}
