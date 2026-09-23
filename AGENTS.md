# Hyalos

Read README.md, docs/RENDERING.md and docs/VALIDATION.md before changing rendering or claiming verification.

Use the installed vGPU documentation, not a memorized API:

    npx vgpu docs find effect
    npx vgpu docs find target
    npx vgpu docs find performance
    npx vgpu examples search raymarching

Use `vgpu` itself. Do not replace it with a lookalike, a WebGL fallback, an AI image or a static image while claiming live rendering. `src/assets/presets` contains saved GPU study renders, clearly labeled as references until a live preview completes. Regenerate them with `npm run render:studies`; never present a reference as a newly rendered scene.

Keep all authored colors in OKLCH. Convert once to linear RGB for physical light transport; apply the display transfer function once after post-processing. Do not mix gamma-encoded colors as light.

Scene model: src/model.ts. Binding layout: 16 vec4f slots, src/gpu/uniforms.ts and src/shaders/common.wgsl. Preview, agent API, still export and exact-time sequences must share this model and shaders. No Math.random, wall-clock seeds or hidden renderer time.

Keep entire offscreen Targets bound when they can resize. Prewarm pipelines. Never add per-frame GPU readback. Stop drawing while paused, hidden or exporting. Keep full-frame coordinates and sufficient filter halos in all tiled exports. Save exact scene time and shader hash in every recipe.

Preserve MIT notices and source provenance when adapting third-party shaders. A Shadertoy example is not automatically MIT licensed.

Run `npm test`, `npm run build`, and `npm run test:browser`. A static source check or mocked renderer is not proof of WGSL compilation or actual vGPU operation. Record test failures and unavailable capabilities without converting them to passing tests. Benchmark hardware explicitly before making FPS claims.

Version 0.2 uses real TypeScript and Preact. UI components are in src/components and src/App.tsx; editor state and GPU lifetime are in src/editor.ts. Do not reintroduce string-generated interface markup, eager renderer imports or root-absolute asset paths. Vite+ uses its native Oxc transform with the Preact JSX runtime.

Read docs/REPAIR.md before changing startup. Keep source-file instructions and explicit CSS/chunk error reporting. Run npm run build before npm run test:browser: the latter tests the production artifact at root and subdirectory paths. npm run test:gpu is separate and uses real vGPU. Old offline DOM tests do not qualify the Preact UI.
