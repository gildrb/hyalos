# Validation evidence

## Publication baseline: 22 September 2026

The TypeScript/Preact source was published to private `gildrb/exo-visuals`, PR #1. Main was not changed. The delivered archive's application and test trees matched the first publication commit byte-for-byte.

Baseline commit: `fdbb33f66f6d8b85e6e4e6b3203da7e3260e377c`.
GitHub Actions run: https://github.com/gildrb/exo-visuals/actions/runs/35749691816

Executed evidence:

- Local CPU/source tests: 100 passed, zero failed or skipped. This is not proof of GPU execution.
- GitHub Actions dependency install: passed on Ubuntu 24.04, Node 22.23.2, npm 10.9.8.
- Full strict TypeScript check and Vite+ production build: passed, job 106820285825.
- Production Preact/browser checks at root and subdirectory paths: passed in the same job. These tests deliberately disable WebGPU and verify usable fallback controls, styles, images, UTF-8 and asset-error diagnostics.
- Actual WebGPU pixel qualification: the first test in job 106820285570 passed, including WGSL compilation, deterministic repeated pixels, six presets, overlapped tiling and PNG recipe metadata at 192 x 108. It used Chromium 145.0.7632.6 with a software adapter, not a mocked renderer.
- Full live-editor GPU integration: the second test failed. Its error snapshot reported `A valid external Instance reference no longer exists.` The error alone does not prove the underlying cause. The baseline GPU job was not fully green.

The baseline UI job's only remaining failure was the missing committed lockfile. Its actual generated `package-lock.json` was retrieved from artifact 10703109985 and retained in commit `cf943196af804ca68b4931fe3b0dd8ff56bf69d5`. Its SHA-256 is `1bdde1004c64b50f6e34fa3b65da8e8abb4b0fb07e45c54b668e8527cfaefc0b`. CI now uses `npm ci` with read-only permissions. The temporary lock-retention workflow is removed.

## Follow-up qualification

The software-GPU suite disables Chromium's GPU watchdog while retaining a finite Playwright timeout, explicitly disposes the standalone renderer, attaches actual exported PNGs, and tests live-editor export rather than only state edits. This is a test-runner change, not a claim that production GPU loss or hardware performance has been fixed. Follow the PR's subsequent CI results for its actual outcome.

No hardware FPS, real-time performance, 8K device compatibility, cross-GPU pixel identity, or exhaustive physical correctness has been established. Numerical radiance/BRDF reference comparisons and target-device benchmarks remain separate qualification work. Read RENDERING.md for the renderer's actual approximations.

The six shipped thumbnails and docs/studies-cpu-preview.png are CPU reference illustrations. They must not be represented as WebGPU test outputs. Historical pre-migration reports are under docs/history/v0.1 and do not qualify the Preact revision.

## Reproduce

```sh
npm ci
npm test
npm run build
npx playwright install --with-deps chromium
npm run test:browser
npm run test:gpu
```

Missing adapters, wrong pixel buffers and failed GPU initialization must fail the GPU suite, never silently skip or pass. The local workspace could not reach the package registry; the successful full build and browser evidence above came from actual GitHub Actions execution.
