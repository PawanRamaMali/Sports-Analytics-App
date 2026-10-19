import { expect, type Locator, type Page } from '@playwright/test';

// Users created by e2e/start-app.R.
export const users = {
  admin: { name: 'e2e-admin', password: 'e2e-admin-pass' },
  analyst: { name: 'e2e-analyst', password: 'e2e-analyst-pass' },
} as const;

export async function signIn(page: Page, who: { name: string; password: string }) {
  await page.goto('/');
  await page.getByLabel('Username').fill(who.name);
  await page.getByLabel('Password').fill(who.password);
  await page.getByRole('button', { name: 'Sign in' }).click();
  await expect(page.locator('.navbar')).toBeVisible();
  await expect(playersTable(page)).toContainText('Kevin Porter Jr.');
}

// A top-level screen in the navbar (bslib renders them as tabs).
export function screen(page: Page, name: string): Locator {
  return page.getByRole('tab', { name, exact: true });
}

export async function openAdmin(page: Page, item: 'Data' | 'Users') {
  await page.locator('.navbar .dropdown-toggle', { hasText: 'Admin' }).click();
  await page.locator('.dropdown-item', { hasText: item }).click();
}

export function playersTable(page: Page): Locator {
  return page.locator('#players-table');
}

// Picks an option of a selectize input (Shiny's selectInput and
// selectizeInput) by typing it, as a user would.
export async function pick(page: Page, inputId: string, option: string) {
  const control = page.locator(`#${inputId} + .selectize-control`);
  const input = control.locator('input');
  await input.click();
  await input.fill(option);
  await control.locator('.selectize-dropdown .option', { hasText: option }).first().click();
}

// Rows of a reactable output, by the output's id.
export function tableRows(page: Page, outputId: string): Locator {
  return page.locator(`#${outputId} .rt-tbody .rt-tr:not(.rt-tr-pad)`);
}
