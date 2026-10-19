import { test, expect } from '@playwright/test';
import { signIn, users, screen } from './helpers';

test.describe('sign in', () => {
  test('shows only the sign-in page before signing in', async ({ page }) => {
    await page.goto('/');
    await expect(page.getByRole('heading', { name: 'Sign in' })).toBeVisible();
    await expect(page.locator('.navbar')).toBeHidden();
  });

  test('asks for both fields', async ({ page }) => {
    await page.goto('/');
    await page.getByRole('button', { name: 'Sign in' }).click();
    await expect(page.getByRole('alert')).toHaveText('Enter your username and password.');
  });

  test('refuses a wrong password', async ({ page }) => {
    await page.goto('/');
    await page.getByLabel('Username').fill(users.analyst.name);
    await page.getByLabel('Password').fill('not the password');
    await page.getByRole('button', { name: 'Sign in' }).click();
    await expect(page.getByRole('alert')).toHaveText('Incorrect username or password.');
    await expect(page.locator('.navbar')).toBeHidden();
    await expect(page.getByLabel('Password')).toHaveValue('');
  });

  test('signs in with Enter', async ({ page }) => {
    await page.goto('/');
    await page.getByLabel('Username').fill(users.analyst.name);
    await page.getByLabel('Password').fill(users.analyst.password);
    await page.getByLabel('Password').press('Enter');
    await expect(screen(page, 'Players')).toBeVisible();
  });

  test('an analyst sees the analysis screens but no Admin menu', async ({ page }) => {
    await signIn(page, users.analyst);
    for (const name of ['Players', 'Player profile', 'Compare', 'Teams', 'Leaders', 'Player types']) {
      await expect(screen(page, name)).toBeVisible();
    }
    await expect(page.locator('.app-user')).toContainText(users.analyst.name);
    await expect(page.locator('.app-role')).toHaveText('Analyst');
    await expect(page.locator('.navbar .dropdown-toggle', { hasText: 'Admin' })).toHaveCount(0);
  });

  test('sign out returns to the sign-in page', async ({ page }) => {
    await signIn(page, users.analyst);
    await page.getByText('Sign out').click();
    await expect(page.getByRole('heading', { name: 'Sign in' })).toBeVisible();
    await expect(page.locator('.navbar')).toBeHidden();
  });
});
