import pytest
from playwright.sync_api import expect

from helpers import USERS, pick, players_table, screen, sign_in, table_rows


@pytest.fixture(autouse=True)
def signed_in(page):
    sign_in(page, USERS["analyst"])


def test_players_search_and_team_filter_narrow_the_table(page):
    search = players_table(page).get_by_placeholder("Search players")
    search.fill("Jordan")
    expect(table_rows(page, "players-table").first).to_contain_text("Jordan")
    search.fill("")

    pick(page, "players-teams", "RGV")
    teams = table_rows(page, "players-table").locator(".rt-td:nth-child(2)")
    expect(teams.first).to_have_text("RGV")
    assert set(teams.all_text_contents()) == {"RGV"}


def test_players_clicking_a_player_opens_their_profile_with_a_shot_chart(page):
    table_rows(page, "players-table").filter(has_text="Kevin Porter Jr.").click()
    expect(screen(page, "Player profile")).to_have_attribute("aria-selected", "true")
    expect(page.locator("#profile-player + .selectize-control .item")).to_have_text("Kevin Porter Jr.")
    expect(page.locator("#profile-tiles")).to_contain_text("RGV")
    expect(page.locator("#profile-tiles")).to_contain_text("19.1")
    # Seven zone shapes plus the court lines.
    shapes = page.locator("#profile-chart .shapelayer path")
    expect(shapes.first).to_be_visible()
    assert shapes.count() >= 7
    zones = table_rows(page, "profile-zones")
    expect(zones).to_have_count(7)
    expect(zones.first).to_contain_text("Restricted area")
    expect(zones.first).to_contain_text("63.2%")


def test_profile_picking_another_player_updates_the_numbers(page):
    screen(page, "Player profile").click()
    pick(page, "profile-player", "Jordan Bell")
    expect(page.locator("#profile-tiles")).to_contain_text("ERI")
    expect(page.locator("#profile-diet")).to_contain_text("League")


def test_compare_two_players_side_by_side(page):
    screen(page, "Compare").click()
    expect(page.get_by_text("Pick players to compare")).to_be_visible()
    pick(page, "compare-players", "Aaron Epps")
    pick(page, "compare-players", "Jordan Bell")
    rows = table_rows(page, "compare-table")
    expect(rows).to_have_count(2)
    expect(rows.nth(0)).to_contain_text("Aaron Epps")
    expect(rows.nth(1)).to_contain_text("Jordan Bell")
    expect(page.locator("#compare-zones")).to_contain_text("League average")


def test_teams_clicking_a_team_shows_its_roster_and_a_player_opens_the_profile(page):
    screen(page, "Teams").click()
    expect(table_rows(page, "teams-table")).to_have_count(18)
    table_rows(page, "teams-table").filter(has_text="RGV").click()
    expect(page.get_by_text("Roster: RGV")).to_be_visible()
    table_rows(page, "teams-roster").filter(has_text="Kevin Porter Jr.").click()
    expect(page.locator("#profile-tiles")).to_contain_text("RGV")


def test_leaders_top_10_by_a_metric_and_by_a_zone(page):
    screen(page, "Leaders").click()
    expect(page.locator("#leaders-title")).to_have_text("Effective FG%")
    expect(table_rows(page, "leaders-table")).to_have_count(10)
    expect(table_rows(page, "leaders-table").first).to_contain_text("Jaylen Morris")

    pick(page, "leaders-metric", "FG%: Restricted area")
    expect(page.locator("#leaders-title")).to_have_text("FG%: Restricted area")
    expect(table_rows(page, "leaders-table").first).to_contain_text("%")

    pick(page, "leaders-n", "Top 20")
    expect(table_rows(page, "leaders-table")).to_have_count(20)


def test_player_types_clicking_a_type_lists_its_players(page):
    screen(page, "Player types").click()
    expect(table_rows(page, "types-centers")).to_have_count(4)
    expect(page.locator("#types-scatter")).to_contain_text("Rim runners")
    table_rows(page, "types-centers").filter(has_text="Rim runners").click()
    expect(page.locator("#types-members_title")).to_have_text("Players: Rim runners")
    types = table_rows(page, "types-members").locator(".rt-td:nth-child(3)")
    expect(types.first).to_have_text("Rim runners")
    assert set(types.all_text_contents()) == {"Rim runners"}
