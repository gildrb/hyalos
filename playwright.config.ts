import { defineConfig } from '@playwright/test';
export default defineConfig({
  testDir: './tests/browser',
  fullyParallel: false,
  workers: 1,
  timeout: 30000,
  use: { headless: true, viewport: { width: 1440, height: 900 } },
  projects: [
    { name: 'root', use: { baseURL: 'http://127.0.0.1:4173/' } },
    { name: 'subdirectory', use: { baseURL: 'http://127.0.0.1:4174/visuals/' } },
  ],
  webServer: [
    { command: 'node scripts/serve.mjs', url: 'http://127.0.0.1:4173/', reuseExistingServer: false },
    { command: 'node scripts/serve.mjs', env: { PORT: '4174', BASE_PATH: '/visuals/' }, url: 'http://127.0.0.1:4174/visuals/', reuseExistingServer: false },
  ],
});
