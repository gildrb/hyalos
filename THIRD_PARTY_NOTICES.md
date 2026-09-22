# Third-party notices

## Vendored shader code

**Ashima Arts and Stefan Gustavson, webgl-noise.** MIT. Source: https://github.com/ashima/webgl-noise/blob/master/src/noise3D.glsl. Original Git blob SHA-1: `0d5858780b7edcededdc2bff9e2c9d4d369fe1ed`. License: `LICENSES/ashima.txt`. Local: `src/shaders/vendor/simplex3.wgsl`. Changes: GLSL translated to WGSL, helper functions renamed to avoid collisions, normalization inlined. Used for surface micro-normal detail and volumetric density. Not an unused dependency.

**Hugh Kennedy, glsl-dither.** MIT. Source: https://github.com/hughsk/glsl-dither/blob/master/8x8.glsl. Original Git blob SHA-1: `8c795e52124a93c7307df16523cd9a266941408b`. License: https://github.com/hughsk/glsl-dither/blob/master/LICENSE.md, retained in `LICENSES/glsl-dither.txt`. Local: `src/shaders/vendor/dither8.wgsl`. Changes: WGSL port, the original 64 thresholds stored as a constant array rather than a branch chain. Used by the Ordered dither finish.

## Runtime and tools

**vGPU 0.5.0.** MIT, Copyright (c) 2025 Vercel, Inc. https://github.com/vercel-labs/vgpu. License retained in `LICENSES/vgpu.txt`. The actual library owns WebGPU contexts, effect compilation, target resources and frame submission. It is not replaced by a compatibility facade.

**Vite+ 0.3.3.** MIT, VoidZero Inc. https://github.com/voidzero-dev/vite-plus/releases/tag/v0.3.3. Build/dev tool, not a runtime renderer. Installed dependencies carry their own notices. The lockfile must be resolved on the first connected installation; it is not fabricated in this source archive.

## Original work and inspiration

The compositions, scene model, editor, optical/dot-matrix/phosphor finishes and export implementation are original to this project. Taxis inspired the shared deterministic model, local agent API and recipe-based workflow. No Taxis implementation or reference-image pixels have been copied. No Paper shaders are bundled; the two MIT WGSL ports above were selected for a single native-WebGPU pipeline. The reference images supplied in the request are not redistributed.

`public/presets/*.png` are original, approximate CPU-rendered study illustrations, not outputs claimed to validate the GPU shader. `scripts/reference-previews.py` records their construction. No font files, external images, paid assets or noncommercial-only shader code are included.
