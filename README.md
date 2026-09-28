# Hyalos

A local visual laboratory built with TypeScript, Preact, Vite+ and direct vGPU. Procedural metallic carriers and shared light suggest Prometheus, local intelligence and decentralization without literal figures or cloud-generated images.

## Run

Use Node 22.18 or newer. Install the committed dependency lock, then start Vite+:

```sh
npm ci
npm run dev
```

Open the printed localhost URL. Do not double-click source `index.html`. WebGPU needs HTTPS or localhost and a compatible browser with hardware acceleration. The UI and recipe editing remain available when GPU initialization fails; live image export does not substitute a reference thumbnail.

Repository: `gildrb/hyalos`.

## Glass Sculpture workspace

Glass Sculptures is the only active workspace. `/`, `/?glass` and legacy `/?classic` links all open it; saved workspace preferences no longer select the retired editor. Original Studies is removed from the interface and application entry point. Its unmounted source and historical documentation remain for provenance.

The complete vGPU example was pulled with `npx vgpu examples pull glass-sculpture --out ./glass-sculpture`. All nine upstream files remain unchanged; the verified revision and aggregate hash are recorded in `glass-sculpture/PROVENANCE.json`. Hyalos reuses its installed vGPU 0.5.0 and Preact dependencies. The upstream React and lil-gui wrappers are retained for provenance but are not mounted.

Knot, Gyroid and Droplets derive from the example's distance fields; Gyroid intersections now have configurable rounding. Twelve additional forms explore crescents, fused rings, trefoils, Möbius bands, minimal surfaces, petals, a broad torus, a double helix, folded ribbons, a pierced prism, fused pearls and a rippled body. These are artistic adaptations, not simulations of the reference photographs.

**Reset all** restores the default Gyroid scene, neutral environment, camera/light, animation clocks, materials, finish and 1080p export. **Undo reset** restores the previous complete recipe until another setting is edited.

Every setting updates the live render. Horizontal orbit is reversed at the user's request. Scroll from an overview into an 8× macro lens; the camera stays outside the sculpture. Shape changes preserve material, lighting, finish, render scale and camera. Reset view changes only the camera. Custom glass color and density, eight tint presets, custom key/rim/background colors and light powers are available. Finish has a master switch and independent bloom, glow spread, grain, scan texture, color grade, atmosphere, silver reflection and exposure controls. Smooth edges and visible light sources are separate switches.

All 33 shadercn orbs are available as animated materials, with GPU-rendered thumbnails, original parameters, colors and animation states. Choose surface, emission or reflection application and object, normal or screen projection. Each orb remembers its own settings. These are original animated shaders mapped onto the sculpture, not newly simulated three-dimensional volumes; source shaders retain their internal artistic lighting. XorDev's shader license is non-commercial with attribution; see THIRD_PARTY_NOTICES.md. The requested shadcn command encountered an upstream dependency URL error, so the exact registry payloads were installed through a local flattened registry. Sources, hashes and untouched wrappers are retained in `vendor/shadercn/`.

Preview is capped at 2,073,600 pixels, 1920 per axis and 24 frame starts per second, with one GPU submission in flight. Hidden tabs stop drawing. Settled paused orb materials reuse their texture; zero-strength materials skip their texture pass. Gallery thumbnails are mounted only while browsing. Render scale affects preview only. Save PNG offers 1080p, 4K (3840 × 2160), custom dimensions and portrait orientation. Each side may be 64–8192 pixels, up to 33,554,432 pixels total. Export uses full render scale and overlapped tiles, with progress and cancellation. The stage uses the export aspect ratio.

Settings persist locally and across shape changes. Save/Open recipe and reopening exported PNGs restore controls, camera, light, time and active orb animation state. Glass recipes use a separate storage key and format; legacy Original Studies recipes are not supported by this workspace. Export has a scoped GPU context disposed on success, failure, cancellation or unmount. Surfaces, observers, input listeners, targets, material scenes and frame loops are released on teardown.

Environment colors are independent of post-processing: key/rim lights, background gradient, atmosphere beam, reflection cards and grade color each have a picker. Background brightness, card strength and beam strength are adjustable to zero. Neutral, Warm, Rose, Emerald and Blue presets recolor the environment together. New scenes use neutral lights/backgrounds; existing saved scenes keep their choices. Neutral removes the environment's blue cast without changing glass or orb pigment.

## Surface and rendering quality

Surface & quality offers Glass, Polished and Chrome starting points, reflection roughness, dispersion amount and rounded intersections on Gyroid, Schwarz, Prism, Helix and Vesper. These are continuous distance fields, not polygon meshes; intersection rounding and spatial sampling improve edges without a subdivision mesh. Refined mode traces four rays per pixel, while Interactive traces one. Both preview and export honor the selected sampling mode.

Bloom now uses a luminance-weighted tent prefilter, adjustable soft threshold, and a blend of tight and broad separable blurs. Export halos grow with glow spread and stay aligned to the downsample grid. The reflective floor is optional and off by default. Environment reflections no longer receive duplicate Phong highlights. Glass internal rays begin inside the surface normal to reduce self-intersection artifacts. This remains an approximate real-time renderer, not a path tracer.

The canvas supports arrow-key orbit and +/− zoom, visible keyboard focus, and a skip link to controls. New scenes respect reduced-motion preferences for turntable/orb autoplay. Fixed lights are the default. Existing saved appearance values remain preserved; use the surface presets or Reset all to try the new defaults.

## Historical Original Studies documentation

The following sections describe the retired editor and its retained source, not the current application interface.

## Original studies and parameters

Ten studies explore polished metal, amber and clear glass: silver knots, crystal vessels, a liquid cascade, folded membranes and the Selene crescent. Corona retains XorDev’s original ORB-31 geometry. All studies have matching GPU-rendered previews and embedded recipes.

Form controls geometry, seed and camera. Light controls material roughness, metallicity, power, emitter radius and participating-medium density. Finish controls optical, dot-matrix, ordered-dither and phosphor treatments, the OKLCH palette, exposure, grain and lens scattering.

Drag the canvas to compose. Control-scroll zooms. Ctrl/Cmd Z and Ctrl/Cmd Shift Z undo and redo. Double-click a slider to reset it. Edits automatically queue a preview after a short debounce; Render requests it immediately. Draft, Balanced and Final quality are available beside Render. Cancel render stops work at the next safe submission boundary; idle and hidden tabs do not keep rendering.

## Original studies: consistency and export

Save a recipe to retain parameters, seed, palette, explicit time and shader SHA-256. Scene links contain the recipe without uploading it. Exported PNGs contain their recipe as metadata and can be reopened. Restored scenes never autoplay. Same-renderer reproducibility does not promise bit-identical output across GPUs or different quality budgets.

Export options:

- PNG with embedded recipe, including tiled 4K and 8K outputs.
- JPEG or WebP with recipe sidecar in a ZIP archive.
- Exact-time PNG sequence plus recipe and FFmpeg command, not screen recording.
- Project JSON independent of GPU availability.

Images allow 64 to 8192 pixels per side and at most 33,554,432 pixels. Sequences allow up to 1080p, 60 FPS, 60 seconds and 600 frames, with a 240 MiB image-data budget. Tiling bounds GPU allocations, but a full 8K RGBA buffer still needs roughly 127 MiB on the CPU before encoding overhead. Use smaller exports on low-memory devices.

## Original studies: color and light

All authored colors are OKLCH. They are gamut-mapped and converted to linear RGB before light transport. HDR intermediate radiance is display-encoded once for sRGB export. Lighting directly in OKLCH would not be physically correct.

The shader uses GGX/Smith/Schlick surface shading, inverse-square emitters, geometry visibility queries, Beer-Lambert extinction and Henyey-Greenstein single scattering. These are finite-budget, physically based approximations, not exact light transport or simulated combustion. The medium omits a secondary shadow march and can leak through occluders. See [the rendering contract](docs/RENDERING.md).

MIT simplex noise and ordered dithering ports retain source provenance and license notices. The ten thumbnails under `src/assets/presets` are 960 × 540 final-quality renders from the shared vGPU renderer, generated on Metal. They remain labeled saved references until a live preview completes. User-supplied reference artwork is not included.

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

## Regenerate study previews

With the native vGPU adapter available:

```sh
npm run render:studies -- --width=960 --quality=final --out=src/assets/presets
node scripts/export-recipes.mjs
```

The native command uses the same scene model, shader assembly, tiling, color processing and PNG recipe metadata as browser export. Optional trailing study IDs limit the selection. It fails when the GPU is unavailable; it does not substitute CPU illustrations.

Render the new compositions through the same scene on the native GPU:

```sh
node scripts/render-sculpture.mjs --width=1920 --out=work/sculptures vesper reliquary
```
