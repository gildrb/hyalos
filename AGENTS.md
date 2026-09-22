# Hyalos

Read README.md, docs/RENDERING.md and docs/VALIDATION.md before changing rendering or claiming verification.

Use the installed vGPU documentation, not a memorized API:

    npx vgpu docs find effect
    npx vgpu docs find target
    npx vgpu docs find performance
    npx vgpu examples search raymarching

Use `vgpu` itself. Do not replace it with a lookalike, a WebGL fallback, an AI image or a static image while claiming live rendering. `public/presets` contains clearly documented CPU reference illustrations only.

Keep all authored colors in OKLCH. Convert once to linear RGB for physical light transport; apply the display transfer function once after post-processing. Do not mix gamma-encoded colors as light.

Scene model: src/model.js. Binding layout: 16 vec4f slots, src/gpu/uniforms.js and src/shaders/common.wgsl. Preview, agent API, still export and exact-time sequences must share this model and shaders. No Math.random, wall-clock seeds or hidden renderer time.

Keep entire offscreen Targets bound when they can resize. Prewarm pipelines. Never add per-frame GPU readback. Stop drawing while paused, hidden or exporting. Keep full-frame coordinates and sufficient filter halos in all tiled exports. Save exact scene time and shader hash in every recipe.

Preserve MIT notices and source provenance when adapting third-party shaders. A Shadertoy example is not automatically MIT licensed.

Run `npm test`, `npm run build`, and `npm run test:browser`. A static source check or mocked renderer is not proof of WGSL compilation or actual vGPU operation. Record test failures and unavailable capabilities without converting them to passing tests. Benchmark hardware explicitly before making FPS claims.
