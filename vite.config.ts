import { defineConfig } from "vite-plus";

export default defineConfig({
  base: "./",
  // Vite+'s native Oxc transform targets Preact directly. No React or Babel layer.
  oxc: { jsx: { runtime: "automatic", importSource: "preact" } },
  server: { host: "127.0.0.1", port: 5173, strictPort: false, allowedHosts: [".ts.net"] },
  preview: { host: "127.0.0.1", port: 4173, strictPort: false },
  build: { target: "es2022", sourcemap: true, chunkSizeWarningLimit: 300 },
  test: {
    // Vitest v4 compatibility: preserve mock call history.
    // Remove after tests no longer rely on calls from setup or earlier tests.
    // https://viteplus.dev/guide/vitest-v5#remove-unneeded-compatibility-settings
    // https://vitest.dev/guide/migration/#clearmocks-is-enabled-by-default
    clearMocks: false,
    include: ["tests/*.test.mjs"],
  },
  // Upstream sources are kept verbatim; see THIRD_PARTY_NOTICES.md.
  lint: {
    ignorePatterns: ["vendor/**", "glass-sculpture/**"],
    options: { typeAware: true, typeCheck: true },
  },
});
