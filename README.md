# Hyalos

A local visual laboratory for abstract, distributed intelligence. Light is held, carried and shared between independent forms. No figurative Prometheus, neural-network stock illustration, image-generation service or external asset API.

**Delivery status:** source implementation and CPU/DOM tests are provided. The authoring environment could not install packages, execute WebGPU or write to GitHub. The Vite+ build, actual vGPU execution, GPU performance and private-repository creation are **not verified or completed**. See [validation](docs/VALIDATION.md). The study thumbnails are approximate CPU illustrations, not GPU test results.

## Run

Use Node 22.18 or newer. From this folder:

```sh
npm install
npm run dev
```

Open `http://127.0.0.1:5173` in a WebGPU-capable browser. The scripts run **Vite+**, not standalone Vite. `vp dev` also works when the Vite+ CLI is available. The initial `npm install` produces `package-lock.json`; retain and commit it, then use `npm ci` on other machines. Direct versions are pinned, but no invented lockfile is included.

WebGPU requires a secure context. HTTPS and localhost work; an ordinary HTTP Tailscale address does not. Keep the dev server bound to localhost and forward it securely when running on a remote server. The build contains no analytics, external fonts or runtime CDN imports. After installation, rendering and export are local.

## Create a visual

Choose a study on the left. Form controls composition, seed, shell structure, node count, material and camera. Light controls luminous power, emitter size, key/fill illumination, density and scattering. Finish controls the optical, dot-matrix, ordered-dither and phosphor treatments, exposure, grain and OKLCH palettes.

Drag the canvas to compose. Control-scroll changes scale. Double-click a slider to reset that parameter to the selected study. Play and scrub use explicit scene time. Saved and reopened scenes remain paused. Undo/redo works across complete recipe edits. On smaller screens, Studies and Parameters open the corresponding drawers.

Four scene families share one renderer:

| Family | Idea |
| --- | --- |
| Prometheus | A luminous source carried through rising, open ribbons. |
| Commons | Independent shells and local emitters, distributed around a shared space. |
| Hearth | A source protected within an open, sculptural enclosure. |
| Relay | Separate luminous cells arranged as a transfer of knowledge. |

Six starting studies and five OKLCH palettes are included. Presets are intentionally starting points, not a random image feed. “New seed” advances a repeatable integer sequence; nothing depends on the wall clock.

## Export

PNG supports custom sizes, including 7680 × 4320, within 8192 pixels per side and 33.5 megapixels total. Render tiles include overlap for the full bloom and dot-sampling kernels. The image is rendered at the chosen output dimensions, not resized from a preview screenshot.

**PNG carries its recipe inside the file.** Open that PNG in the editor to recover settings, exact time, engine version and shader SHA-256. JPEG and WebP are delivered as a ZIP with a JSON sidecar because their image codecs may not preserve application metadata. Plain JSON recipes and URL-fragment scene links are also available. Scene links contain settings, not uploads.

Animation exports a fixed-time PNG sequence ZIP, not a screen recording. Limits: 1080p, 1–60 FPS, at most 60 seconds and 600 frames, with a 240 MiB image-data budget. The archive includes an FFmpeg command for MP4 encoding. There is no direct MP4/WebM encoder in this version. Export can be cancelled without altering the recipe.

Preview and export use the same equations and model. Preview quality has bounded ray, volume and shadow samples; final exports use the highest budget, so small integration differences from a low-quality preview are expected. Identical settings, dimensions, time, engine and GPU implementation are intended to reproduce the same pixels. Different GPU drivers can round floating-point arithmetic differently; byte-identical cross-device rendering is not promised.

## Lighting and color

All **authored** palettes, UI colors and saved color values use OKLCH. They are gamut-mapped to linear sRGB for light transport, then display-encoded once. Performing physical lighting arithmetic directly in perceptual OKLCH would be incorrect.

Surface lighting uses GGX microfacets, correlated Smith visibility, Schlick Fresnel, diffuse/specular energy sharing, inverse-square sources and SDF visibility queries. The volumetric pass uses Beer-Lambert transmittance and Henyey-Greenstein single scattering. The camera scattering kernel is normalized rather than additively inventing light.

These are finite-budget, physically based approximations. The geometry and medium density are artist-authored fields, not simulated fire. This is not a fluid solver, a spectral renderer, an indirect-light path tracer or a certified energy-conserving transport solver. [Rendering details and limitations](docs/RENDERING.md).

## Verify

```sh
npm test
npm run build
npx playwright install chromium
npm run test:browser
```

The first command uses only Node's built-in test runner. Browser tests import the **real installed vgpu package** and must fail rather than silently pass when no GPU backend is available. GPU compilation, repeated pixel reads, tiled export equivalence, metadata, controls and fallback behavior are covered by those tests, but they were not executable in the delivery VM. No hardware frame-rate claim is made.

## Create the requested private repository

After reviewing the source, authenticate GitHub CLI as `gildrb`, then run:

```sh
bash scripts/publish-private.sh
```

The script installs dependencies, saves the real lockfile, runs CPU tests and the Vite+ build, initializes Git, creates **gildrb/hyalos as private**, checks private visibility, and pushes the initial commit. It refuses an existing repository, existing local Git history or a different logged-in account. It never force-pushes and does not need a token copied into this project. GPU browser verification remains a separate required check before release.

The script is included for local execution because the connected GitHub tool in the delivery session exposes reads only. The repository has not been created by that session.

## Extension points

`src/model.js` is the shared scene schema. `src/shaders/scene.wgsl` defines geometry and lighting. `src/shaders/post.wgsl` defines optical/print treatment. `src/gpu/renderer.js` is the actual vGPU integration. `src/export.js` handles bounded readback, images and exact-time sequences. The local `window.hyalos` API exposes recipes and exports to browser agents; see [Agent API](docs/AGENT_API.md).

Two MIT shader modules are actively integrated: Ashima/Stegu simplex noise and Hugh Kennedy's ordered dithering. No separate WebGL/Paper renderer is required. Source hashes, adaptations and preserved licenses are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
