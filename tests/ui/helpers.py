from pathlib import Path

from playwright.sync_api import Locator, Page, expect

# The committed season, used as a valid file to import.
PROJECT_SEASON = Path(__file__).resolve().parents[2] / "data" / "seasons" / "2020-21.csv"

# Users created by start_app.R.
USERS = {
    "admin": {"name": "e2e-admin", "password": "e2e-admin-pass"},
    "analyst": {"name": "e2e-analyst", "password": "e2e-analyst-pass"},
}


def wait_for_shiny_idle(page: Page, timeout=10_000):
    page.wait_for_function(
        "() => !document.documentElement.classList.contains('shiny-busy')",
        timeout=timeout,
    )


def sign_in(page: Page, who: dict):
    page.goto("/")
    page.get_by_label("Username").fill(who["name"])
    page.get_by_label("Password").fill(who["password"])
    page.get_by_role("button", name="Sign in").click()
    expect(page.locator(".navbar")).to_be_visible()
    expect(players_table(page)).to_contain_text("Kevin Porter Jr.")


# A top-level screen in the navbar (bslib renders them as tabs).
def screen(page: Page, name: str) -> Locator:
    return page.get_by_role("tab", name=name, exact=True)


def open_admin(page: Page, item: str):
    page.locator(".navbar .dropdown-toggle", has_text="Admin").click()
    page.locator(".dropdown-item", has_text=item).click()


def players_table(page: Page) -> Locator:
    return page.locator("#players-table")


# Picks an option of a selectize input (Shiny's selectInput and
# selectizeInput) by typing it, as a user would.
def pick(page: Page, input_id: str, option: str):
    control = page.locator(f"#{input_id} + .selectize-control")
    field = control.locator("input")
    field.click()
    field.fill(option)
    control.locator(".selectize-dropdown .option", has_text=option).first.click()


# Rows of a reactable output, by the output's id.
def table_rows(page: Page, output_id: str) -> Locator:
    return page.locator(f"#{output_id} .rt-tbody .rt-tr:not(.rt-tr-pad)")
