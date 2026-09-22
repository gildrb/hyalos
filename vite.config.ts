import { defineConfig } from 'vite-plus';

export default defineConfig({
  base: './',
  // Vite+'s native Oxc transform targets Preact directly. No React or Babel layer.
  oxc: { jsx: { runtime: 'automatic', importSource: 'preact' } },
  server: { host: '127.0.0.1', port: 5173, strictPort: true },
  preview: { host: '127.0.0.1', port: 4173, strictPort: true },
  build: { target: 'es2022', sourcemap: true, chunkSizeWarningLimit: 300 },
});
