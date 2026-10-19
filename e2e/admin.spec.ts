import { test, expect } from '@playwright/test';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { signIn, users, openAdmin, pick, tableRows } from './helpers';

test.beforeEach(async ({ page }) => {
  await signIn(page, users.admin);
});

test('an admin adds a user who can then sign in', async ({ page, browser }) => {
  const name = `analyst-${Date.now()}`;
  await openAdmin(page, 'Users');
  const form = page.locator('.card', { hasText: 'Add a user' });
  await form.getByLabel('Username').fill(name);
  await form.getByLabel(/Password/).fill('new-user-pass');
  await form.getByRole('button', { name: 'Add user' }).click();
  await expect(form.getByRole('status')).toHaveText(`User ${name} added.`);
  await expect(tableRows(page, 'admin_users-users').filter({ hasText: name })).toContainText('Analyst');

  const other = await browser.newPage();
  await signIn(other, { name, password: 'new-user-pass' });
  await expect(other.locator('.app-role')).toHaveText('Analyst');
  await other.close();
});

test('a new user needs a long enough password', async ({ page }) => {
  await openAdmin(page, 'Users');
  const form = page.locator('.card', { hasText: 'Add a user' });
  await form.getByLabel('Username').fill('shortpass');
  await form.getByLabel(/Password/).fill('short');
  await form.getByRole('button', { name: 'Add user' }).click();
  await expect(form.getByRole('alert')).toContainText('at least 8 characters');
});

test('an admin cannot delete themselves', async ({ page }) => {
  await openAdmin(page, 'Users');
  const form = page.locator('.card', { hasText: 'Change a user' });
  await pick(page, 'admin_users-who', users.admin.name);
  await form.getByRole('button', { name: 'Delete user' }).click();
  await expect(form.getByRole('alert')).toHaveText('You cannot delete yourself.');
});

test('importing a CSV adds a season; a bad file is refused', async ({ page }) => {
  await openAdmin(page, 'Data');
  const card = page.locator('.card', { hasText: 'Import a CSV' });

  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'e2e-import-'));
  const bad = path.join(dir, 'bad.csv');
  fs.writeFileSync(bad, 'PLAYER_NAME,TEAM_ABBREVIATION\nSomeone,AAA\n');
  await card.getByLabel('Season', { exact: true }).fill('2021-22');
  await card.locator('input[type=file]').setInputFiles(bad);
  await expect(card.getByText('Upload complete')).toBeVisible();
  await card.getByRole('button', { name: 'Import' }).click();
  await expect(card.getByRole('alert')).toContainText('Missing columns');

  const good = path.join(dir, 'good.csv');
  fs.copyFileSync(path.join('data', 'seasons', '2020-21.csv'), good);
  await card.locator('input[type=file]').setInputFiles(good);
  await expect(card.getByText('Upload complete')).toBeVisible();
  await card.getByRole('button', { name: 'Import' }).click();
  await expect(card.getByRole('status')).toHaveText('Season 2021-22 imported: 246 players.');
  await expect(tableRows(page, 'admin_data-seasons').filter({ hasText: '2021-22' })).toContainText('246');

  // The navbar's season picker offers the new season.
  await page.locator('#season + .selectize-control .selectize-input').click();
  await expect(page.locator('#season + .selectize-control .option', { hasText: '2021-22' })).toBeVisible();
});

test('fetching needs a valid season', async ({ page }) => {
  await openAdmin(page, 'Data');
  const card = page.locator('.card', { hasText: 'Fetch from stats.gleague.nba.com' });
  await card.getByLabel('Season', { exact: true }).fill('2021');
  await card.getByRole('button', { name: 'Fetch season' }).click();
  await expect(card.getByRole('alert')).toHaveText('Season must look like 2020-21.');
});
