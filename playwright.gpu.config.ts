import { defineConfig } from '@playwright/test';
export default defineConfig({
  testDir: './tests/gpu', workers: 1, timeout: 120000,
  projects: [{ name: 'gpu' }],
  use: {
    baseURL: 'http://127.0.0.1:5173', headless: true,
    viewport: { width: 1440, height: 900 },
    launchOptions: { args: ['--enable-unsafe-webgpu', '--use-angle=swiftshader', '--enable-features=Vulkan', '--disable-vulkan-surface'] },
  },
  webServer: { command: 'npm run dev', url: 'http://127.0.0.1:5173', reuseExistingServer: false, timeout: 120000 },
});
