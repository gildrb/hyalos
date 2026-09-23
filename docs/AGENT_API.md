# Local agent API

The editor exposes `window.hyalos` to browser automation. It does not expose a network service or send settings to a server.

```js
const live = await window.hyalos.ready;
if (!live) throw new Error('A real WebGPU renderer is required.');
const original = window.hyalos.getScene();
window.hyalos.setParameters({ seed: 240915, scene: 0, rotation: 38, time: 2.5 });
const png = await window.hyalos.exportPNG(3840, 2160);
// A Blob with the settings and shader hash embedded as PNG text metadata.
window.hyalos.setScene(original);
```

`getScene()` returns an independent, validated document. `setScene(document)` checks format, engine, version and parameter bounds; pass the document object, not JSON text. `setParameters(patch)` validates the complete merged model. Nested palette changes require a complete palette with `background`, `metal` and `energy` as `[L,C,H]` arrays, not RGB strings or hex values. Palette bounds are L 0–1, C 0–0.4, H 0–360; all values must be finite.

`setScene` and `setParameters` stage the new state without rendering the canvas. They cancel any queued or active explicit preview at submission boundaries. The saved study reference or last complete preview remains visible until the UI's **Render** action; position, scale and in-plane rotation have only a CSS bitmap approximation, not updated scene geometry or lighting. Recipe reads and exports use the staged settings immediately. Scene `time` and `duration` remain explicit recipe/API parameters for deterministic stills and exact-time sequence export, not a live timeline or continuously advancing editor clock.

```js
window.hyalos.setParameters({ palette: {
  background: [0.115, 0.018, 270],
  metal: [0.79, 0.022, 240],
  energy: [0.84, 0.10, 235],
} });
```

## Forms, perforation, glass, beams and edge sampling

`scene` is an integer from 0 to 9:

| ID | Form |
| --- | --- |
| 0 | Prometheus |
| 1 | Commons |
| 2 | Hearth |
| 3 | Relay |
| 4 | Knot |
| 5 | Gyroid |
| 6 | Droplets |
| 7 | Reliquary |
| 8 | Sanctum |
| 9 | Corona |

Form IDs are not study/preset IDs: the `hearth` study uses form 4, and the `relay` study uses form 6. IDs 0–8 retain their original body geometry at `perforation: 0`. Corona uses XorDev's ORB-31 warped-sphere subtraction; the other forms optionally subtract a warped copy of their own body. These are actual body holes used by primary, visibility and optical rays, not a shading mask. Emitters are not carved.

| Parameter | Valid bounds | Meaning |
| --- | --- | --- |
| `transmission` | 0–1 | Glass mixture weight, multiplied by `1-metallic` |
| `ior` | 1–2.5 | Green (550 nm) reference refractive index |
| `dispersion` | 0–0.08 | Blue-minus-red IOR span; Cauchy-like RGB approximation at 610/550/460 nm, indices clamped to at least 1 |
| `absorption` | 0–4 | Beer–Lambert absorption scale using the linear metal palette as tint and scene-unit path lengths |
| `sampleGrid` | Integer 1, 2 or 3 | 1, 4 or 9 deterministic full-scene rays per pixel, averaged in linear HDR before display processing |
| `beam` | 0–1 | Key-light spotlight blend, from isotropic to a normalized cone aimed at the origin |
| `beamAngle` | Integer 8–60 | Outer cone half-angle in degrees |
| `holeWarp` | 0.3–10 | Warp divisor; larger values reduce displacement |
| `holeFrequency` | 0.15–30 | Sinusoidal warp frequency |
| `holeSoftness` | 0.015–4 | Smooth-subtraction width in the unscaled hole coordinates |
| `perforation` | 0–1 | Signed-field interpolation from original to carved body for forms 0–8; ignored by Corona |

Current optical/sampling/beam defaults are respectively 0, 1.5, 0.004, 0.35, 2, 0.85 and 18. The four hole defaults are respectively 0.9, 5.25, 0.42 and 0. All numeric settings must be finite and inside `src/model.ts`'s `RANGES`; bounds are inclusive. Fields with step 1 require integers; other UI step sizes do not quantize API input. Draft rendering always uses one ray without changing `sampleGrid`; balanced/final use the recipe value. Glass is bounded Snell/Fresnel transport with absorption and total internal reflection, not full spectral transport, caustics or measured material data. See [RENDERING.md](RENDERING.md) for the budgets and limitations.

`scripts/compile-orb31.mjs` generates `src/shaders/vendor/orb31.wgsl` from the original installed TypeGPU `smin`/`coronaSDF` functions after checking the source against the saved registry payload. Those helpers are imported into the shared preview/export scene shader, not merely retained as an unused asset. ORB-31 is by [XorDev](https://x.com/XorDev), ported for Orbkit with permission, **non-commercial use only with attribution**; this exception also covers the marked derived perforation geometry, not Hyalos's MIT transport. Corona preserves the upstream radius 2.6 and defaults under uniform scaling and invertible seed/explicit-time rotations, rather than importing the full upstream renderer or animated/audio behavior. The unchanged `16 x vec4f` layout repurposes `view.z` for `perforation`, `emit.x` for `holeWarp`, `emit.w` for `holeFrequency` and `finish.w` for `holeSoftness`; `motion.y` still carries the explicit scene-time loop phase and `emit.y` the renderer-owned sample index.

The spotlight redistributes the existing key budget with a normalized smooth cone; `beam` also broadens the authored haze envelope and fades in key-light scattering. Medium lighting uses a single key-centre approximation with HG scattering and no light-side extinction/shadow march, so shafts can leak through blockers. This is not volumetric path tracing, and glass studio reflections remain an independent analytic approximation.

The phosphor finish filters scanline amplitude near the pixel Nyquist limit and suppresses unresolved scanline modulation. Its appearance therefore depends on output resolution; this does not change the deterministic midpoint medium sampling or add new rendering parameters.

```js
window.hyalos.setParameters({
  scene: 6, metallic: 0, transmission: 0.96,
  ior: 1.38, dispersion: 0.026, absorption: 0.28, sampleGrid: 2,
});
```

Recipes retain `format: 'hyalos-visual'`, `version: 1` and `engine: 'hyalos-prometheus/1'`. `setScene`/recipe import supplies the historical optical defaults (0, 1.5, 0.008, 0.35) only when all four optical fields are absent; partial optics are rejected. Missing `sampleGrid` independently migrates to 2. If both `beam` and `beamAngle` are absent they migrate to 0 and 26, preserving the legacy isotropic key light; supplying only one is invalid. If all four of `holeWarp`, `holeFrequency`, `holeSoftness` and `perforation` are absent they migrate to 0.9, 5.25, 0.42 and 0; any partially supplied hole group is rejected. These migrations are for document import, not default-filling arbitrary `setParameters` patches. The shader hash records implementation provenance; import checks its type/length, not equality to the current shader. A migrated recipe is not a guarantee of historical pixel identity. Subsequent snapshots/exports record the active renderer hash (`unverified` when no renderer supplies one).

## Capabilities and scheduling

`capabilities()` reports initialized vGPU availability, shader hash, maximum image pixel count, selected preview quality and export busy state. A visible thumbnail is not evidence that `webgpu` is true, and `webgpu: true` is not evidence of a rendered frame. `ready` is a getter for the current connection promise: it resolves true after device initialization and pipeline prewarming, without drawing or presenting a preview. No automatic preview or refinement follows. Explicit image export is available after initialization without a prior preview. The viewport continues showing a labeled saved study reference until an explicit Render completes. Wait for `window.hyalos` to exist: Preact publishes it after mounting.

Startup has a 20-second initialization timeout covering module/device loading and compilation, with no first-draw or visibility-wait phase. Failure resolves `ready` false and leaves recipe editing available; Reconnect replaces the connection promise and likewise requests no frame. Cancellation releases resources, including a device that arrives after cancellation, but cannot preempt native acquisition/compilation or already submitted GPU work.

The UI-facing `Editor` exposes `startupPhase: 'idle' | 'loading' | 'compiling' | 'ready'`, `refining: boolean`, `renderQueued: boolean` (getter), `pendingChanges: boolean`, `renderedSettings: Settings | null` and `renderPreview(): void`; these are not additional `window.hyalos` methods. `status === 'ready'` gates explicit rendering/export, not image existence. `renderedSettings` is null until a preview completes and resets on disconnect/reconnect. `renderPreview()` requests the current scene once at the selected quality without changing settings and respects export, visibility, one-flight and pacing gates. It is unavailable before readiness, during export or while a preview is active or queued. `renderQueued` distinguishes an explicit request waiting for visibility, pacing or cancelled work from an actively rendering pass; the UI shows Queued and blocks duplicate requests. `refining` is true only during the active preview, not while queued or exporting. Edits clear it immediately while cancelled native work drains. `pendingChanges` stays true until a completed preview matches the current settings revision, selected quality and viewport; export does not clear it or populate `renderedSettings`. `createRenderer`/`RendererFactory` accept optional typed initialization options with an AbortSignal and `onPhase('loading' | 'compiling')` callback.

Preview defaults to draft (≤230,400 pixels, ≤640 per axis); balanced is ≤500,000 / 1024 and opt-in final ≤1,000,000 / 1440, with DPR ≤1 and device texture limits applied. Control, camera, API time, preset, recipe, history, quality and viewport edits do not schedule GPU work. They cancel queued/active previews; resizing only scales the retained bitmap until Render. Only explicit Render authorizes a preview; startup never does, and the editor has no playback scheduler. The timer scheduler permits at most 15 frame starts per second and rests for at least the preceding draw's elapsed duration after completion, including cancellation. Only one preview draw is in flight, and a fresh explicit request waits for cancelled work and its rest debt. Idle scenes do no work even with staged changes. Hidden tabs suspend preview work; visibility return can resume only an outstanding explicit Render request, not create one.

The viewport's saved reference or last completed frame supports CSS-only position, scale and in-plane rotation relative to that image's baseline settings. This is explicitly labeled an approximation: form, perforation, light, orbit and finish still wait for Render. Stage drag-to-pan and Ctrl-scroll-to-zoom also work while connecting or unavailable, without requiring WebGPU; they are disabled during export. A preset thumbnail is not a rendering of arbitrary restored settings, and export never substitutes the saved image for GPU output.

Renderer scene chunks use a separate target of at most 128 × 128, submitting one primary sample per pass. A reusable 256 KiB GPU storage buffer retains the ordered f32 sums for 4/9-ray pixels; only the final averaged chunk is copied into a full-preview/export-tile HDR texture. Every sample submission is followed by queue/error drain and a cooldown of at least 4 ms or twice its elapsed dispatch-through-drain time, including the final sample's copy. One full-target post pass follows; partial cancelled HDR work is not presented. These limits and the advisory low-power adapter preference are not a real-time frame-rate promise or a guarantee against memory pressure, device loss or crashes.

Chunk sides are 128 for opaque material, 64 for active glass and 32 for active dispersive glass, independent of sample grid; edge chunks can be smaller. Separate sample submissions preserve the authored 1/4/9-ray spatial integration and final quality, without CPU readback of the sample sums. Cancellation is checked between these submissions, but cannot preempt submitted GPU work. This does not establish a maximum execution time for a sample pass.

## Snapshots and export

API writes stage changes without requesting a preview. An active export rejects writes and concurrent exports. Export clones the current staged time, settings and palette before asynchronous work without advancing time implicitly; it cancels preview requests and uses the shared context after active preview work drains. It neither clears pending canvas changes nor requests a preview afterward. PNG embeds this recipe, the renderer source SHA-256, and output width/height, quality (`final`) and `colorSpace: 'srgb'` as text metadata. Export uses final ray/transport budgets and the authored sample grid, independent of preview caps and quality; it can be substantially slower.

`exportPNG(width = 1920, height = 1080)` returns a PNG `Blob`; it does not trigger a download. Both dimensions must be integers from 64 to 8192 and the image must contain at most 33,554,432 pixels. Readback is tiled with overlap, but assembly and encoding still allocate a full CPU image plus temporary buffers. The top-bar **Save PNG** action downloads a 1920 × 1080 PNG with embedded recipe in one click. The separate **Export** dialog provides custom dimensions, PNG, JPEG/WebP plus recipe ZIP, exact-time PNG sequence ZIP, and JSON recipe output. Sequences allow at most 2,073,600 pixels, integer 1–60 FPS, integer 1–60 seconds and 600 frames, with an accumulated encoded-frame limit of 240 MiB, not a total-memory guarantee.

Use the advanced export dialog's **Cancel render** action for cancellable exports; the public `exportPNG` API does not expose an AbortSignal. Internally, cancellation propagates through tile rendering to the chunk scheduler, retains cooldown owed before replacement work, and is checked before post-processing and after image encoding. It cannot preempt an already dispatched GPU chunk/post pass or browser image encoding; a cancelled or superseded export does not return its completed blob.

Exports reject and stop the renderer if readback contains a non-opaque pixel (alpha other than 255), since the post shader always writes opaque output. Reconnect creates a fresh renderer; a failed browser/driver may still need reload. This guard does not validate RGB correctness or guarantee export success on every device.

The real browser harness is `/tests/render.html` on the development server. It imports `src/gpu/renderer.ts` and the installed `vgpu` package, not a mock adapter. See VALIDATION.md for the distinction between CPU tests, GPU-less UI tests and actual WebGPU qualification.

`emitter` controls inner-light strength from 0 to 1. Newly authored studies use 0; legacy recipes without the field migrate to 1. Preview rendering can be cancelled from the canvas toolbar without changing settings.
