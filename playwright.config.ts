import { defineConfig, devices } from '@playwright/test';

// Browser tests: Playwright starts the Shiny app (e2e/start-app.R, with its
// own users and data) and drives it in Chromium like a user would.
//   npx playwright test                 all tests
//   npx playwright test e2e/auth.spec.ts one file
//   npx playwright test -g "sign out"    tests whose title matches
// RSCRIPT points at Rscript when it is not on PATH.

const port = Number(process.env.E2E_PORT ?? 3839);
const rscript = process.env.RSCRIPT ?? 'Rscript';

export default defineConfig({
  testDir: './e2e',
  timeout: 60_000,
  expect: { timeout: 15_000 },
  // One R process serves every test, so tests run one at a time.
  fullyParallel: false,
  workers: 1,
  retries: process.env.CI ? 1 : 0,
  forbidOnly: !!process.env.CI,
  reporter: process.env.CI
    ? [['github'], ['html', { open: 'never' }]]
    : [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL: `http://127.0.0.1:${port}`,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'], viewport: { width: 1400, height: 900 } } },
  ],
  webServer: {
    command: `"${rscript}" e2e/start-app.R`,
    url: `http://127.0.0.1:${port}`,
    env: { E2E_PORT: String(port) },
    // A fresh app per run, so the users and seasons start the same.
    reuseExistingServer: !!process.env.E2E_REUSE_SERVER,
    timeout: 120_000,
    stdout: 'pipe',
    stderr: 'pipe',
  },
});
