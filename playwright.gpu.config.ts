import { defineConfig } from '@playwright/test';
export default defineConfig({
  testDir: './tests/gpu', workers: 1, timeout: 180000,
  projects: [{ name: 'gpu' }],
  use: {
    baseURL: 'http://127.0.0.1:5173', headless: true,
    viewport: { width: 1440, height: 900 },
    launchOptions: {
      // This suite exercises actual WGSL through Chromium's software adapter.
      // Slow CPU rendering is not a hardware FPS benchmark. Keep Playwright's
      // finite test timeout, but do not let Chromium kill a long software draw.
      args: ['--enable-unsafe-webgpu', '--use-angle=swiftshader', '--enable-features=Vulkan', '--disable-vulkan-surface', '--disable-gpu-watchdog'],
    },
  },
  webServer: { command: 'npm run dev', url: 'http://127.0.0.1:5173', reuseExistingServer: false, timeout: 120000 },
});
