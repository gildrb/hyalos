# Third-party notices

## Vendored shader code

**Ashima Arts and Stefan Gustavson, webgl-noise.** MIT. Source: https://github.com/ashima/webgl-noise/blob/master/src/noise3D.glsl. Original Git blob SHA-1: `0d5858780b7edcededdc2bff9e2c9d4d369fe1ed`. License: `LICENSES/ashima.txt`. Local: `src/shaders/vendor/simplex3.wgsl`. Changes: GLSL translated to WGSL, helper functions renamed to avoid collisions, normalization inlined. Used for surface micro-normal detail and volumetric density. Not an unused dependency.

**Hugh Kennedy, glsl-dither.** MIT. Source: https://github.com/hughsk/glsl-dither/blob/master/8x8.glsl. Original Git blob SHA-1: `8c795e52124a93c7307df16523cd9a266941408b`. License: https://github.com/hughsk/glsl-dither/blob/master/LICENSE.md, retained in `LICENSES/glsl-dither.txt`. Local: `src/shaders/vendor/dither8.wgsl`. Changes: WGSL port, the original 64 thresholds stored as a constant array rather than a branch chain. Used by the Ordered dither finish.

**XorDev / shadercn ORB-31. Non-commercial use only, with attribution.** Exact registry: https://www.shadercn.run/r/orb-31.json. Original shader by https://x.com/XorDev, ported for Orbkit with the author's permission. The shader's explicit file notice overrides the repository-level MIT license for this code. Commercial permission has not been established.

The requested shadcn installer installed the complete component. Its upstream registry dependency `orb` incorrectly resolved against shadcn's default registry; the retained `vendor/shadercn/orb-31.registry.json` changes only that dependency address to `@shadercn/orb`. The five installed files are preserved under `vendor/shadercn/components/orbs/`. In particular, `orb-31/gpu.ts` is byte-for-byte identical to the registry payload, SHA-256 `13281ce0ac952dc3fb64c5729877a413e3d381d837c4206764e5cd8ed3f7f375`.

`scripts/compile-orb31.mjs` compiles the original TypeGPU function objects using TypeGPU 0.12.5 and unplugin-typegpu 0.12.3. It emits the original full fragment shader to `vendor/shadercn/orb-31.wgsl`, and its exact `smin` and `coronaSDF` geometry to `src/shaders/vendor/orb31.wgsl`, with stable helper names. The shared vGPU sculpture pipeline actually calls this generated geometry. `scene.wgsl` adds uniform scale, rigid orientation, conservative march steps and an explicitly marked adaptation of the subtraction to other sculpture fields. These derivative geometry sections retain the non-commercial restriction.

The upstream React canvas and automatic/randomized animation runtime are retained as source provenance, **not mounted or executed**. The editor uses Preact, deterministic recipe time, its existing physical light transport and explicit Render/export submission. ORB-31's artistic per-step godray accumulation is not claimed to be physical refraction or installed as a second automatic render loop. The shadercn runtime's MIT notice is retained separately in `LICENSES/shadercn.txt`.

## Runtime and tools

**vGPU 0.5.0.** MIT, Copyright (c) 2025 Vercel, Inc. https://github.com/vercel-labs/vgpu. License retained in `LICENSES/vgpu.txt`. The actual library owns WebGPU contexts, effect compilation, target resources and frame submission. It is not replaced by a compatibility facade.

**Vite+ 0.3.3.** MIT, VoidZero Inc. https://github.com/voidzero-dev/vite-plus/releases/tag/v0.3.3. Build/dev tool, not a runtime renderer. Installed dependencies carry their own notices. The lockfile must be resolved on the first connected installation; it is not fabricated in this source archive.

## Original work and inspiration

The original compositions, scene model, editor, optical/dot-matrix/phosphor finishes and export implementation are MIT project code, except for the explicitly identified ORB-31 derivative geometry above. Taxis inspired the shared deterministic model, local agent API and recipe-based workflow. No Taxis implementation or reference-artwork pixels have been copied. No Paper shaders are bundled. The artwork references are not redistributed; the explicitly requested official logo is attributed above.

`src/assets/presets/*.png` are 960 × 540 exports from this project's real vGPU renderer on an Apple Metal adapter. Each includes its scene recipe and shader hash. The Corona study uses the attributed ORB-31 geometry. The older `docs/studies-cpu-preview.png` and `scripts/reference-previews.py` remain CPU-reference material, not GPU qualification.

The cyan sculpture image shared by [Nous Research](https://x.com/NousResearch/status/2099984561451028913), the [vGPU glass-sculpture example](https://vgpu.sh/examples/glass-sculpture), and [Mareux and Riki's Ébène Fumé video](https://www.youtube.com/watch?v=VcnOSLWOQ78) informed the visual direction. Their images and footage are not bundled. The explicitly requested vGPU example source is now bundled as described below. The dielectric transport and cinematic lighting additions are original implementations of standard optics.

Prime Intellect's [ivory point-field composition](https://x.com/PrimeIntellect/status/2100657260343267767) and [blue-black grain treatment](https://x.com/PrimeIntellect/status/1974892387559506003) informed the additional mythological studies. Their artwork, logos and text are not included in those renders.

## vGPU Glass Sculpture example

Complete nine-file source retained under `glass-sculpture/`, pulled and verified by the official CLI. Source: https://vgpu.sh/examples/glass-sculpture. Concept and visual design by Kazuyuki Chinda (@ckazu). vGPU is MIT, Copyright (c) 2025 Vercel, Inc.; see `LICENSES/vgpu.txt`. Exact revision and aggregate SHA-256: `glass-sculpture/PROVENANCE.json`.

`src/studio/scene.ts`, `pointer-input.ts`, `controls.ts`, `sculpture.wgsl` and `present.wgsl` are marked adaptations. The original three shapes and their optical branches remain; Hyalos adds twelve shapes, custom lighting and tint controls, macro zoom and configurable finishing. Blur and camera helpers are imported directly from the unchanged example; Hyalos now supplies a soft-knee extraction shader and a second blur scale. The React/lil-gui wrappers are replaced with the existing Preact UI, automatic lifecycle cleanup, bounded live preview and recipe/PNG export.

## Complete shadercn orb library

All 33 original orb programs and React wrappers are retained verbatim under `vendor/shadercn/components/orbs/`; exact registry payloads and SHA-256 hashes are in `vendor/shadercn/registry/` and `PROVENANCE.json`. Generated WGSL lives in `src/studio/orbs/shaders/`. Source: https://www.shadercn.run/. XorDev's shader notices require **non-commercial use with attribution** and remain in each generated shader. These shader programs are not relicensed under Hyalos's MIT license. The existing shadercn runtime license remains in `LICENSES/`. The studio's animation driver is adapted from the supplied runtime; thumbnails are actual native GPU renders of the original programs.
