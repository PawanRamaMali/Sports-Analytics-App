from playwright.sync_api import expect

from helpers import USERS, screen, sign_in

ANALYST = USERS["analyst"]


def test_shows_only_the_sign_in_page_before_signing_in(page):
    page.goto("/")
    expect(page.get_by_role("heading", name="Sign in")).to_be_visible()
    expect(page.locator(".navbar")).to_be_hidden()


def test_asks_for_both_fields(page):
    page.goto("/")
    page.get_by_role("button", name="Sign in").click()
    expect(page.get_by_role("alert")).to_have_text("Enter your username and password.")


def test_refuses_a_wrong_password(page):
    page.goto("/")
    page.get_by_label("Username").fill(ANALYST["name"])
    page.get_by_label("Password").fill("not the password")
    page.get_by_role("button", name="Sign in").click()
    expect(page.get_by_role("alert")).to_have_text("Incorrect username or password.")
    expect(page.locator(".navbar")).to_be_hidden()
    expect(page.get_by_label("Password")).to_have_value("")


def test_signs_in_with_enter(page):
    page.goto("/")
    page.get_by_label("Username").fill(ANALYST["name"])
    page.get_by_label("Password").fill(ANALYST["password"])
    page.get_by_label("Password").press("Enter")
    expect(screen(page, "Players")).to_be_visible()


def test_an_analyst_sees_the_analysis_screens_but_no_admin_menu(page):
    sign_in(page, ANALYST)
    for name in ["Players", "Player profile", "Compare", "Teams", "Leaders", "Player types"]:
        expect(screen(page, name)).to_be_visible()
    expect(page.locator(".app-user")).to_contain_text(ANALYST["name"])
    expect(page.locator(".app-role")).to_have_text("Analyst")
    expect(page.locator(".navbar .dropdown-toggle", has_text="Admin")).to_have_count(0)


def test_sign_out_returns_to_the_sign_in_page(page):
    sign_in(page, ANALYST)
    page.get_by_text("Sign out").click()
    expect(page.get_by_role("heading", name="Sign in")).to_be_visible()
    expect(page.locator(".navbar")).to_be_hidden()
