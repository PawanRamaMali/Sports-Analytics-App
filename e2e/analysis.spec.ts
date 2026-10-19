import { test, expect } from '@playwright/test';
import { signIn, users, screen, pick, playersTable, tableRows } from './helpers';

test.beforeEach(async ({ page }) => {
  await signIn(page, users.analyst);
});

test('players: search and team filter narrow the table', async ({ page }) => {
  const table = playersTable(page);
  await table.getByPlaceholder('Search players').fill('Jordan');
  await expect(tableRows(page, 'players-table').first()).toContainText('Jordan');
  await table.getByPlaceholder('Search players').fill('');

  await pick(page, 'players-teams', 'RGV');
  const teams = tableRows(page, 'players-table').locator('.rt-td:nth-child(2)');
  await expect(teams.first()).toHaveText('RGV');
  expect(new Set(await teams.allTextContents())).toEqual(new Set(['RGV']));
});

test('players: clicking a player opens their profile with a shot chart', async ({ page }) => {
  await tableRows(page, 'players-table').filter({ hasText: 'Kevin Porter Jr.' }).click();
  await expect(screen(page, 'Player profile')).toHaveAttribute('aria-selected', 'true');
  await expect(page.locator('#profile-player + .selectize-control .item')).toHaveText('Kevin Porter Jr.');
  await expect(page.locator('#profile-tiles')).toContainText('RGV');
  await expect(page.locator('#profile-tiles')).toContainText('19.1');
  // Seven zone shapes plus the court lines.
  await expect(page.locator('#profile-chart .shapelayer path').first()).toBeVisible();
  expect(await page.locator('#profile-chart .shapelayer path').count()).toBeGreaterThanOrEqual(7);
  const zones = tableRows(page, 'profile-zones');
  await expect(zones).toHaveCount(7);
  await expect(zones.first()).toContainText('Restricted area');
  await expect(zones.first()).toContainText('63.2%');
});

test('profile: picking another player updates the numbers', async ({ page }) => {
  await screen(page, 'Player profile').click();
  await pick(page, 'profile-player', 'Jordan Bell');
  await expect(page.locator('#profile-tiles')).toContainText('ERI');
  await expect(page.locator('#profile-diet')).toContainText('League');
});

test('compare: two players side by side', async ({ page }) => {
  await screen(page, 'Compare').click();
  await expect(page.getByText('Pick players to compare')).toBeVisible();
  await pick(page, 'compare-players', 'Aaron Epps');
  await pick(page, 'compare-players', 'Jordan Bell');
  const rows = tableRows(page, 'compare-table');
  await expect(rows).toHaveCount(2);
  await expect(rows.nth(0)).toContainText('Aaron Epps');
  await expect(rows.nth(1)).toContainText('Jordan Bell');
  await expect(page.locator('#compare-zones')).toContainText('League average');
});

test('teams: clicking a team shows its roster, and a player opens the profile', async ({ page }) => {
  await screen(page, 'Teams').click();
  await expect(tableRows(page, 'teams-table')).toHaveCount(18);
  await tableRows(page, 'teams-table').filter({ hasText: 'RGV' }).click();
  await expect(page.getByText('Roster: RGV')).toBeVisible();
  await tableRows(page, 'teams-roster').filter({ hasText: 'Kevin Porter Jr.' }).click();
  await expect(page.locator('#profile-tiles')).toContainText('RGV');
});

test('leaders: top 10 by a metric and by a zone', async ({ page }) => {
  await screen(page, 'Leaders').click();
  await expect(page.locator('#leaders-title')).toHaveText('Effective FG%');
  await expect(tableRows(page, 'leaders-table')).toHaveCount(10);
  await expect(tableRows(page, 'leaders-table').first()).toContainText('Jaylen Morris');

  await pick(page, 'leaders-metric', 'FG%: Restricted area');
  await expect(page.locator('#leaders-title')).toHaveText('FG%: Restricted area');
  await expect(tableRows(page, 'leaders-table').first()).toContainText('%');

  await pick(page, 'leaders-n', 'Top 20');
  await expect(tableRows(page, 'leaders-table')).toHaveCount(20);
});

test('player types: clicking a type lists its players', async ({ page }) => {
  await screen(page, 'Player types').click();
  await expect(tableRows(page, 'types-centers')).toHaveCount(4);
  await expect(page.locator('#types-scatter')).toContainText('Rim runners');
  await tableRows(page, 'types-centers').filter({ hasText: 'Rim runners' }).click();
  await expect(page.locator('#types-members_title')).toHaveText('Players: Rim runners');
  const types = tableRows(page, 'types-members').locator('.rt-td:nth-child(3)');
  expect(new Set(await types.allTextContents())).toEqual(new Set(['Rim runners']));
});
