# Delivery validation

Recorded in the delivery environment, 2026-09-22.

## Executed

- **87 Node tests passed**, zero skipped and zero failed. They cover every numeric parameter bound, preset completeness, recipe round trips, malformed inputs, immutable undo/redo, deterministic seeds, periodic phase, gamut mapping, uniform layout, raster limits, tile coverage/cropping, RGBA ordering, cancellation, readback errors, CRC32, deterministic ZIP metadata and embedded PNG recipe checksums.
- **11 offline DOM checks passed** in Chromium with zero page JavaScript errors. They cover the explicit no-WebGPU state, preset selection, inspector tabs, parameter editing, undo, redo, export dialog, agent API and accessible 800px/390px responsive layouts. This used an in-memory test bundle, not a Vite+ build. The missing package was represented only by an import placeholder that throws if called. No renderer call was executed or claimed to be executed.
- JavaScript syntax checks and `bash -n scripts/publish-private.sh` passed.
- Six original approximate CPU study illustrations were generated and inspected. They validate composition direction only. Their volume/micro-normal noise is simplified relative to the actual WGSL and their PNG metadata identifies them as CPU illustrations.

The detailed local test transcripts are included under `docs/validation-local.txt` and `docs/dom-validation.json`.

## Not executed or not completed

- Package installation and lockfile resolution: network/DNS access to package registries was unavailable. Direct versions come from upstream package/release sources. No lockfile was fabricated.
- Vite+ production build, `vp check`, actual vGPU shader compilation and shader validation: unavailable without the dependencies.
- Real WebGPU/browser end-to-end tests: browser navigation to localhost/file test pages was blocked by the environment administrator. The allowed in-memory DOM test context was not secure and did not expose WebGPU. No attempt to bypass those restrictions is part of this project.
- Hardware profiling: no RTX 3090, Apple GPU or mobile-GPU FPS measurements were obtained. Preview quality controls and resource bounds are implemented, but performance is not certified.
- Private repository creation and push: the connected GitHub tool exposes read operations only, and no authenticated write-capable CLI was available. `gildrb/hyalos` was not created. The user-run private publication script is provided instead and is syntax-checked, not execution-verified.

## Required next verification on a connected machine

1. `npm install`, then retain the generated `package-lock.json`.
2. `npm test` and `npm run build`.
3. `npx playwright install chromium`, then `npm run test:browser` against the actual vGPU library.
4. Check all four form families and extreme parameters on the intended GPU. Inspect tiled 4K/8K exports for seams and device-memory behavior. Compare repeated exports at fixed dimensions and time.
5. Profile frame delivery on the target hardware before claiming a frame-rate target. The editor's cadence display is browser frame cadence, not GPU timestamp-query timing.

The real-GPU tests intentionally fail when a backend is missing. They do not silently skip hardware coverage. CI also requires the real installation lockfile and runs GPU checks separately from CPU tests.
