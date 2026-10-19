import pytest
from playwright.sync_api import expect

from helpers import (PROJECT_SEASON, USERS, open_admin, pick, players_table, screen, sign_in,
                     table_rows, wait_for_shiny_idle)

ANALYST = USERS["analyst"]


@pytest.fixture
def sign_in_page(page):
    page.goto("/")
    expect(page.get_by_role("button", name="Sign in")).to_be_visible()
    wait_for_shiny_idle(page)
    return page


def attempt(page, name, password):
    page.get_by_label("Username").fill(name)
    page.get_by_label("Password").fill(password)
    page.get_by_role("button", name="Sign in").click()
    wait_for_shiny_idle(page)


def test_five_wrong_passwords_lock_the_form(sign_in_page):
    page = sign_in_page
    for _ in range(5):
        attempt(page, ANALYST["name"], "not the password")
        expect(page.get_by_role("alert")).to_have_text("Incorrect username or password.")
    # Even the right password is refused while the form is locked.
    attempt(page, ANALYST["name"], ANALYST["password"])
    expect(page.get_by_role("alert")).to_contain_text("Too many failed attempts")
    expect(page.locator(".navbar")).to_be_hidden()


def test_username_is_trimmed_and_not_case_sensitive(sign_in_page):
    page = sign_in_page
    attempt(page, "  " + ANALYST["name"].upper() + "  ", ANALYST["password"])
    expect(screen(page, "Players")).to_be_visible()
    expect(page.locator(".app-role")).to_have_text("Analyst")


def test_password_is_case_sensitive(sign_in_page):
    page = sign_in_page
    attempt(page, ANALYST["name"], ANALYST["password"].upper())
    expect(page.get_by_role("alert")).to_have_text("Incorrect username or password.")


def test_a_search_with_no_match_shows_no_players(page):
    sign_in(page, ANALYST)
    players_table(page).get_by_placeholder("Search players").fill("zzz no such player")
    expect(table_rows(page, "players-table")).to_have_count(0)
    expect(players_table(page)).to_contain_text("No players match these filters.")


def test_compare_holds_at_most_three_players(page):
    sign_in(page, ANALYST)
    screen(page, "Compare").click()
    for name in ["Aaron Epps", "Jordan Bell", "Kevin Porter Jr."]:
        pick(page, "compare-players", name)
    expect(table_rows(page, "compare-table")).to_have_count(3)
    control = page.locator("#compare-players + .selectize-control")
    expect(control.locator(".item")).to_have_count(3)
    # selectize keeps its dropdown closed once three are picked.
    field = control.locator("input")
    field.click()
    field.fill("Jaylen")
    field.press("Enter")
    expect(control.locator(".selectize-dropdown")).to_be_hidden()
    expect(control.locator(".item")).to_have_count(3)
    expect(table_rows(page, "compare-table")).to_have_count(3)


@pytest.mark.parametrize("season", ["2021/22", "2021-23", "../users", ""])
def test_import_refuses_a_bad_season_name(page, season):
    sign_in(page, USERS["admin"])
    open_admin(page, "Data")
    card = page.locator(".card", has_text="Import a CSV")
    card.get_by_label("Season", exact=True).fill(season)
    card.locator("input[type=file]").set_input_files(PROJECT_SEASON)
    expect(card.get_by_text("Upload complete")).to_be_visible()
    card.get_by_role("button", name="Import").click()
    expect(card.get_by_role("alert")).to_have_text("Season must look like 2021-22.")


def test_import_needs_a_file(page):
    sign_in(page, USERS["admin"])
    open_admin(page, "Data")
    card = page.locator(".card", has_text="Import a CSV")
    card.get_by_label("Season", exact=True).fill("2022-23")
    card.get_by_role("button", name="Import").click()
    expect(card.get_by_role("alert")).to_have_text("Choose a CSV file.")


def test_import_refuses_a_player_listed_twice(page, tmp_path):
    lines = PROJECT_SEASON.read_text().splitlines()
    dup = tmp_path / "dup.csv"
    dup.write_text("\n".join(lines + [lines[1]]) + "\n")
    sign_in(page, USERS["admin"])
    open_admin(page, "Data")
    card = page.locator(".card", has_text="Import a CSV")
    card.get_by_label("Season", exact=True).fill("2022-23")
    card.locator("input[type=file]").set_input_files(dup)
    expect(card.get_by_text("Upload complete")).to_be_visible()
    card.get_by_role("button", name="Import").click()
    expect(card.get_by_role("alert")).to_contain_text("Some players appear more than once.")
    expect(table_rows(page, "admin_data-seasons").filter(has_text="2022-23")).to_have_count(0)


def test_a_username_cannot_be_taken_twice_in_any_case(page):
    sign_in(page, USERS["admin"])
    open_admin(page, "Users")
    form = page.locator(".card", has_text="Add a user")
    form.get_by_label("Username").fill(ANALYST["name"].upper())
    form.get_by_label("Password").fill("another-pass")
    form.get_by_role("button", name="Add user").click()
    expect(form.get_by_role("alert")).to_contain_text("already exists")
