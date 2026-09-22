# Exo Visuals

A local visual laboratory built with TypeScript, Preact, Vite+ and direct vGPU. Procedural metallic carriers and shared light suggest Prometheus, local intelligence and decentralization without literal figures or cloud-generated images.

## Run

Use Node 22.18 or newer. Install the committed dependency lock, then start Vite+:

```sh
npm ci
npm run dev
```

Open the printed localhost URL. Do not double-click source `index.html`. WebGPU needs HTTPS or localhost and a compatible browser with hardware acceleration. The UI and recipe editing remain available when GPU initialization fails; live image export does not substitute a reference thumbnail.

The existing repository is `gildrb/exo-visuals`. The package keeps its original `exo-v2-visuals` name.

## Studies and parameters

Six presets cover four form families: Prometheus, Commons, Hearth and Relay. The gift is a carrier opening toward a luminous core; the commons distributes its sources; the hearth contains its own fire; the relay passes illumination between independent forms. Material memory and Before ignition demonstrate dot-matrix and ordered-dither treatments.

Form controls geometry, seed and camera. Light controls material roughness, metallicity, power, emitter radius and participating-medium density. Finish controls optical, dot-matrix, ordered-dither and phosphor treatments, the OKLCH palette, exposure, grain and lens scattering.

Drag the canvas to compose. Control-scroll zooms. Space toggles playback. Ctrl/Cmd Z and Ctrl/Cmd Shift Z undo and redo. Double-click a slider to reset it. Paused scenes render only after changes; hidden tabs suspend preview work.

## Consistency and export

Save a recipe to retain parameters, seed, palette, explicit time and shader SHA-256. Scene links contain the recipe without uploading it. Exported PNGs contain their recipe as metadata and can be reopened. Restored scenes never autoplay. Same-renderer reproducibility does not promise bit-identical output across GPUs or different quality budgets.

Export options:

- PNG with embedded recipe, including tiled 4K and 8K outputs.
- JPEG or WebP with recipe sidecar in a ZIP archive.
- Exact-time PNG sequence plus recipe and FFmpeg command, not screen recording.
- Project JSON independent of GPU availability.

Images allow 64 to 8192 pixels per side and at most 33,554,432 pixels. Sequences allow up to 1080p, 60 FPS, 60 seconds and 600 frames, with a 240 MiB image-data budget. Tiling bounds GPU allocations, but a full 8K RGBA buffer still needs roughly 127 MiB on the CPU before encoding overhead. Use smaller exports on low-memory devices.

## Color and light

All authored colors are OKLCH. They are gamut-mapped and converted to linear RGB before light transport. HDR intermediate radiance is display-encoded once for sRGB export. Lighting directly in OKLCH would not be physically correct.

The shader uses GGX/Smith/Schlick surface shading, inverse-square emitters, geometry visibility queries, Beer-Lambert extinction and Henyey-Greenstein single scattering. These are finite-budget, physically based approximations, not exact light transport or simulated combustion. The medium omits a secondary shadow march and can leak through occluders. See [the rendering contract](docs/RENDERING.md).

MIT simplex noise and ordered dithering ports retain source provenance and license notices. The six thumbnails under `src/assets/presets` are approximate CPU illustrations, not evidence of live WebGPU rendering. User-supplied reference artwork is not included.

## Build, serve and test

```sh
npm test
npm run build
npx playwright install chromium
npm run test:browser
npm run test:gpu
```

`build` runs strict TypeScript checking and Vite+. `test:browser` checks the production artifact at both root and subdirectory paths with WebGPU deliberately unavailable. `test:gpu` separately runs actual WGSL, pixel comparisons, tiling, recipe export and the live editor through Chromium's software adapter. It is not a hardware performance benchmark and must not silently skip missing adapters.

```sh
npm run build
npm run serve
# Subdirectory deployment test:
BASE_PATH=/visuals/ PORT=4174 npm run serve
```

For a static host, deploy the complete contents of `dist`. Assets use build-managed relative paths. The included static server emits UTF-8 MIME types and rejects missing asset paths rather than returning HTML for them.

## Architecture

`src/App.tsx` and `src/components/` contain the Preact UI. `src/editor.ts` owns typed state, history, export locking and GPU lifetime. `src/model.ts` validates the shared model; `src/gpu/uniforms.ts` packs it. `src/gpu/renderer.ts` owns direct vGPU resources. `src/shaders/` contains the actual WGSL. `src/export.ts` and `src/binary.ts` implement image readback, archives and PNG metadata. Browser automation uses [the local agent API](docs/AGENT_API.md).

Read [repair notes](docs/REPAIR.md), [validation evidence](docs/VALIDATION.md) and [third-party notices](THIRD_PARTY_NOTICES.md) before changing rendering or claiming production qualification.
