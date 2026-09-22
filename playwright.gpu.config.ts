import { defineConfig } from '@playwright/test';
export default defineConfig({
  testDir: './tests/gpu', workers: 1, timeout: 180000,
  projects: [{ name: 'gpu' }],
  use: {
    baseURL: 'http://127.0.0.1:5173', headless: false,
    viewport: { width: 1440, height: 900 },
    launchOptions: {
      // The Linux software-Vulkan preset in vGPU 0.5.0's
      // docs/topics/agent-browser-webgpu.docs.md, also used for captures.
      // CI runs this headed browser inside Xvfb. This is not a hardware benchmark.
      args: ['--enable-unsafe-webgpu', '--enable-features=Vulkan', '--use-angle=vulkan', '--use-vulkan=swiftshader', '--use-webgpu-adapter=swiftshader', '--disable-vulkan-surface', '--disable-gpu-watchdog'],
    },
  },
  webServer: { command: 'npm run dev', url: 'http://127.0.0.1:5173', reuseExistingServer: false, timeout: 120000 },
});
