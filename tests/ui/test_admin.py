import shutil
import time

import pytest
from playwright.sync_api import expect

from helpers import PROJECT_SEASON, USERS, open_admin, pick, sign_in, table_rows


@pytest.fixture(autouse=True)
def signed_in(page):
    sign_in(page, USERS["admin"])


def test_an_admin_adds_a_user_who_can_then_sign_in(page, browser, browser_context_args):
    name = f"analyst-{int(time.time() * 1000)}"
    open_admin(page, "Users")
    form = page.locator(".card", has_text="Add a user")
    form.get_by_label("Username").fill(name)
    form.get_by_label("Password").fill("new-user-pass")
    form.get_by_role("button", name="Add user").click()
    expect(form.get_by_role("status")).to_have_text(f"User {name} added.")
    expect(table_rows(page, "admin_users-users").filter(has_text=name)).to_contain_text("Analyst")

    other = browser.new_context(**browser_context_args)
    try:
        other_page = other.new_page()
        sign_in(other_page, {"name": name, "password": "new-user-pass"})
        expect(other_page.locator(".app-role")).to_have_text("Analyst")
    finally:
        other.close()


def test_a_new_user_needs_a_long_enough_password(page):
    open_admin(page, "Users")
    form = page.locator(".card", has_text="Add a user")
    form.get_by_label("Username").fill("shortpass")
    form.get_by_label("Password").fill("short")
    form.get_by_role("button", name="Add user").click()
    expect(form.get_by_role("alert")).to_contain_text("at least 8 characters")


def test_an_admin_cannot_delete_themselves(page):
    open_admin(page, "Users")
    form = page.locator(".card", has_text="Change a user")
    pick(page, "admin_users-who", USERS["admin"]["name"])
    form.get_by_role("button", name="Delete user").click()
    expect(form.get_by_role("alert")).to_have_text("You cannot delete yourself.")


def test_importing_a_csv_adds_a_season_and_a_bad_file_is_refused(page, tmp_path):
    open_admin(page, "Data")
    card = page.locator(".card", has_text="Import a CSV")

    bad = tmp_path / "bad.csv"
    bad.write_text("PLAYER_NAME,TEAM_ABBREVIATION\nSomeone,AAA\n")
    card.get_by_label("Season", exact=True).fill("2021-22")
    card.locator("input[type=file]").set_input_files(bad)
    expect(card.get_by_text("Upload complete")).to_be_visible()
    card.get_by_role("button", name="Import").click()
    expect(card.get_by_role("alert")).to_contain_text("Missing columns")

    good = tmp_path / "good.csv"
    shutil.copyfile(PROJECT_SEASON, good)
    card.locator("input[type=file]").set_input_files(good)
    expect(card.get_by_text("Upload complete")).to_be_visible()
    card.get_by_role("button", name="Import").click()
    expect(card.get_by_role("status")).to_have_text("Season 2021-22 imported: 246 players.")
    expect(table_rows(page, "admin_data-seasons").filter(has_text="2021-22")).to_contain_text("246")

    # The navbar's season picker offers the new season.
    page.locator("#season + .selectize-control .selectize-input").click()
    expect(page.locator("#season + .selectize-control .option", has_text="2021-22")).to_be_visible()


def test_fetching_needs_a_valid_season(page):
    open_admin(page, "Data")
    card = page.locator(".card", has_text="Fetch from stats.gleague.nba.com")
    card.get_by_label("Season", exact=True).fill("2021")
    card.get_by_role("button", name="Fetch season").click()
    expect(card.get_by_role("alert")).to_have_text("Season must look like 2020-21.")
