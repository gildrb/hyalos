# Validation evidence

## Publication baseline: 22 September 2026

The TypeScript/Preact source was published to private `gildrb/hyalos`, PR #1. Main was not changed. The delivered archive's application and test trees matched the first publication commit byte-for-byte.

Baseline commit: `fdbb33f66f6d8b85e6e4e6b3203da7e3260e377c`.
GitHub Actions run: https://github.com/gildrb/hyalos/actions/runs/35749691816

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

The shipped thumbnails are real 640 × 360 vGPU exports from the hardware qualifications below, with embedded recipes. `docs/studies-cpu-preview.png` remains a CPU reference illustration, not GPU evidence. Historical pre-migration reports under docs/history/v0.1 do not qualify this revision.

## Cinematic optics and bounded rendering qualification

Shader fingerprint for this earlier qualification: `77d71169a42d40a82415d4f7177b222051d65f9d7d5b6adf84cb99ac6b017b6d`.

An isolated, no-credentials Helium/Chromium 153.0.8010.52 profile executed installed vGPU 0.5.0 on Apple M4 / Metal 3. This was real WGSL execution, not a mock or CPU illustration:

- All six final 640 × 360 study PNGs exported with opaque, nonblack pixels and no reported GPU errors; the images were visually inspected. All seven forms also rendered at 96 × 96.
- Spectral glass with four primary samples completed, followed by a healthy opaque render; nine-sample spectral glass also completed. Primary samples are separate paced submissions with an f32 GPU accumulator. The earlier single-submission four-sample spectral path silently produced zero pixels and poisoned later draws; those earlier black-image comparisons are not passing evidence.
- Commons at 320 × 180 was byte-identical on repetition and with 64-pixel export tiles. After the final phosphor scanline filter, the hero at 192 × 108 again matched repeated and 64-pixel tiled output exactly: maximum channel difference zero, all alpha 255, 214 distinct channel values, no GPU errors. Its embedded recipe matched the final shader fingerprint.
- At a 1600 × 1000 CSS viewport and DPR 2, the actual editor used a 942 × 530 balanced canvas; playback used 640 × 360. Paused queue submissions remained unchanged over two separate 700 ms observations. Corrected playback advanced 1.4393 scene seconds over 1.5397 observed seconds. These are observations, not FPS or thermal guarantees.
- The live Beam controls, one-click 1920 × 1080 PNG download, matching recipe metadata, and cancellation (`Export cancelled.`) were exercised. The successful one-click download preceded the final scanline-only shader correction. A final live screenshot at 942 × 530 confirmed that the phosphor correction removed broad horizontal moiré bands.

Visibility qualification is limited: explicitly simulated hidden state plus `visibilitychange` stopped submissions over 600 ms. Opening another headless tab did not make the editor hidden, so native OS/background-tab behavior was not independently qualified.

Preview caps, pacing, cancellation and zero idle submissions reduce work; they cannot guarantee every device avoids driver failure or overheating. No 4K interactive, 8K compatibility, universal crash-safety, hardware FPS or exhaustive optical-accuracy claim is made. The user's existing browser had disabled its GPU after the earlier workload; it was not restarted or represented as recovered.

Local command results:

- `npm test`: 107 passed.
- `npm run build`: strict TypeScript and production build passed.
- `npm run test:browser`: 10 production root/subdirectory checks passed using a temporary config selecting installed Nix Chromium.
- `npm exec --no -- vp lint`: passed with two existing warnings (`src/binary.ts:23` control regex; `tests/export.test.mjs:43` useless spread).
- `npm run check`: failed formatting checks in 44 files (43 before this work); unrelated formatting was not rewritten.
- The software-adapter `npm run test:gpu` run failed both tests: the pixel test raised `OperationError: A valid external Instance reference no longer exists.`, and live-editor GPU initialization exceeded 20 seconds. The underlying cause is not established. Actual Metal evidence above does not turn this suite green.

## Staged startup and minimal editor qualification

The shader fingerprint above is unchanged. Startup now presents a genuine draft at no more than 320 pixels per side / 57,600 pixels before refining the same scene. Export-format compilation occurs on first export rather than blocking startup.

Measured using installed vGPU 0.5.0, the same Apple M4 / Metal 3 browser, a fresh temporary browser profile, a 1440 × 900 CSS viewport and DPR 2:

- First live presentation: 548.2 ms from navigation, at 320 × 180. The adapter/device requests took approximately 3.2 ms total; asynchronous scene and display pipeline requests took approximately 13.6 and 9.4 ms. The selected balanced frame followed at 2,605.3 ms, at 936 × 526.
- A prior warm-profile run presented at 268.4 ms. The earlier pre-change startup took 17,866.9 ms at 883 × 496, but its compilation cost was not separately measured. These runs do not isolate driver/OS shader-cache state, so they are not a controlled cold-compile speedup ratio or a universal startup guarantee.
- The paused editor stayed at 214 queue submissions over an 800 ms observation. A 390 × 850 mobile viewport rendered at 370 × 208 without horizontal overflow. Desktop/mobile screenshots and both mobile drawers were inspected; useful controls, quality selection, import, recipes and export remain available without persistent marketing or GPU-status labels.
- Actual one-click PNG saving produced a 1920 × 1080 image with time 0, authored sample grid 2 and the unchanged shader fingerprint. The image was visually inspected. Cancelling a separate save displayed `Export cancelled.` and left the renderer usable.
- A deliberately delayed first queue-completion promise exercised the new deadline: readiness returned false at approximately 20.26 seconds, the UI showed the first-frame timeout, and the native device was destroyed once. This is injected-delay lifecycle evidence, not a naturally occurring GPU failure. Simulated hidden startup submitted no work and did not claim readiness; making it visible produced the tiny live frame and retained a power edit made while hidden. Native OS/background visibility remains unqualified.

After these changes, `npm test` again passed 107 tests, strict TypeScript/production build passed, and production root/subdirectory browser checks passed all 10 tests. Lint retained the two warnings above and formatting still failed in 44 files. The rerun software-GPU suite still failed both tests: the same external-Instance error at first pixel read, and the explicit first-live-frame startup timeout. No failing check was weakened or represented as passing. A separate read-only review found no concrete startup ownership, cancellation or export/refinement defects.

## Manual composition, branding and mythological studies

Earlier shader fingerprint: `27747ce01dab2649d8ea182da9436996913d3ef759d5dc500bdce0dd5d2e075a`. This historical section superseded interactive playback; the ORB-31 qualification below also removes its initial automatic frame. **Save PNG** exports current settings directly at 1920 × 1080, while **Export options** exposes format, dimensions, sequence and recipe choices.

Actual Apple M4 / Metal 3 observations:

- After initial refinement, rotation edits, twelve-step pointer dragging, undo/redo, preview-quality changes and viewport resizing left GPU submissions at **214 → 214**, presentations at **4 → 4**, and the old 936 × 526 canvas intact. The UI reported `Changes not rendered`. Explicit Render then produced the selected 640 × 360 draft, cleared pending state, and submissions stayed at **245 → 245** over another 800 ms.
- Editing during an explicit render cancelled at the next safe boundary: submissions **540 → 541**, no new presentation, then **541 → 541** over 600 ms. Already submitted native work cannot be preempted. Pending edits remained visible rather than silently publishing an outdated frame.
- Exporting staged power 81 on scene 7 preserved that value in PNG metadata without changing canvas presentation count (**10 → 10**) or clearing its pending status. The final direct Save PNG action downloaded `hyalos-selene-s713021-1920x1080.png` successfully while leaving the old canvas honestly marked pending.
- An injected delayed encoder callback plus synthetic pagehide/pageshow exercised the reviewed export/reconnect race. The old export rejected with `AbortError: Export cancelled.`, releasing its busy lock rearmed the already-authorized startup preview, and reconnect readiness resolved true without GPU errors. This is lifecycle injection evidence, not native BFCache qualification.
- All **nine** 640 × 360 study PNGs were regenerated on the actual GPU, with matching embedded recipes and no reported errors. The original six studies remain, with Selene, Oracle and Eidolon added. Selene's repeated 192 × 108 pixels matched exactly; a 64-pixel tiled export also matched exactly (maximum channel difference zero, 249 distinct channel values).

Desktop and 390-pixel mobile screenshots confirmed no timeline, distinct Render / Save PNG / Export options actions, stable pending-status layout, all nine study previews, and no horizontal overflow. At 390 × 850 the explicit canvas was 370 × 208 and pending status cleared without a layout-induced redraw. The unmodified logo and upstream Apache 2.0 license are bundled; see THIRD_PARTY_NOTICES.md.

Final command results: **106 CPU tests passed**, strict TypeScript/production build passed, and **10 root/subdirectory browser checks passed**. Four source-text implementation checks and obsolete playback/fixed-study-count assertions were removed rather than re-pinned; the expanded preset data exercises three additional existing model cases. Lint passed with the same two warnings. Formatting failed in **47 files**, including three new generated recipes. The software-GPU suite still failed both tests with the external-Instance error and first-frame timeout described above; hardware evidence does not erase those failures. No native crash-safety, cold-driver-cache latency, FPS or universal-device guarantee is claimed.

## Exact ORB-31 and click-only rendering

Current shader fingerprint: `3e5a4965d496ee4e6d50fa2273117bfa5a4692fda365f56bbd2aed05b8f917a6`. Startup now initializes and prewarms only: **no initial frame, automatic refinement or edit-triggered render**. Earlier startup/presentation evidence above describes superseded behavior.

The requested shadcn registry command encountered an upstream unqualified `orb` dependency returning 404. The retained registry payload corrects only that dependency to `@shadercn/orb`; the actual shadcn installer then succeeded. Original ORB-31 `gpu.ts` remains byte-identical to the registry source, SHA-256 `13281ce0ac952dc3fb64c5729877a413e3d381d837c4206764e5cd8ed3f7f375`. The build compiles its original TypeGPU geometry functions into the shared vGPU shader. This is not a replacement renderer or a copied screenshot. XorDev's non-commercial-only attribution restriction is retained; see THIRD_PARTY_NOTICES.md.

An isolated Helium 153 profile on Apple M4 / Metal 3 executed installed vGPU 0.5.0:

- Fresh initialization, pointer dragging, numeric typing, undo/redo, Ctrl-scroll zoom, fullscreen and resizing submitted **zero GPU work**. Fullscreen contained the Render control. An 80 × 35 pixel drag immediately translated the saved bitmap approximately 79.92 × 34.97 pixels without rendering. With WebGPU deliberately unavailable, a 60 × 25 pixel drag still translated it approximately 59.94 × 24.98 pixels.
- Explicit draft Render completed at 639 × 360, cleared pending state and removed the bitmap approximation. Submissions stayed **31 → 31** over the following 800 ms. Focusing and leaving an unchanged numeric field did not cancel that render. No GPU errors were reported.
- Corona's actual 640 × 360 PNG was visually inspected and shipped with its matching recipe/hash. At 192 × 108, repeated and 64-pixel tiled Corona renders matched exactly: maximum channel difference **zero**, all alpha 255, 256 distinct RGB channel values, no GPU errors.
- Applying perforation to the existing Material memory sculpture changed 5,866 channel values at 192 × 108; its 480 × 360 render visibly contained openings and was inspected. This smoke check used opaque material and one primary sample; it does not qualify all glass/perforation combinations or extreme parameter settings.
- BrowserMCP inspected the user's existing editor without navigating or triggering a render. It still displayed the saved Commons composition with pending changes, Render enabled and ORB-31 controls present. The user's browser was not restarted. Hardware rendering occurred only in the isolated profile, which was closed afterward.

Current command results: **111 CPU tests passed**, strict TypeScript and production build passed, and **10 production root/subdirectory browser checks passed**. Lint passed with the same two warnings recorded above. Formatting failed in **54 files**, including unchanged upstream vendor files; no repository-wide formatting rewrite was applied. The software-GPU suite still failed both tests: first pixel read raised `A valid external Instance reference no longer exists.`, and editor initialization exceeded its 20-second deadline. The hardware checks do not convert these failures into passes.

The nine earlier thumbnails retain their historical embedded shader hashes; Corona is the new current-hash thumbnail. All ten example JSON recipes use the current model/hash. No FPS, universal crash-safety, exhaustive physical accuracy or commercial-use clearance is claimed.

## Reproduce

```sh
npm ci
npm test
npm run build
npx playwright install --with-deps chromium
npm run test:browser
npm run test:gpu
```

Missing adapters, wrong pixel buffers and failed GPU initialization must fail the GPU suite, never silently skip or pass. The publication baseline could not reach the package registry locally and used GitHub Actions for full build/browser evidence; the later qualification above includes local builds and isolated hardware execution.
