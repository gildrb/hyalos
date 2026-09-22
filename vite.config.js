import { defineConfig } from 'vite-plus';

export default defineConfig({
  // WGSL is deliberately assembled as text: production and validation consume
  // identical shader sources. Vite's native ?raw imports need no custom loader.
  server: { host: '127.0.0.1', port: 5173, strictPort: true },
  preview: { host: '127.0.0.1', port: 4173, strictPort: true },
  build: { target: 'es2022', sourcemap: true, chunkSizeWarningLimit: 300 },
});
