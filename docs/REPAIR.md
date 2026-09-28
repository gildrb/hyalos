# Startup repair and Preact migration

The reported screenshot showed browser-default layout, a broken poster, mangled symbols and a Connecting label. It does not include the serving URL, response headers or console. The exact hosting failure cannot be established from the screenshot alone. The original HTML already contained a UTF-8 meta declaration.

Confirmed weaknesses in the original source were root-absolute asset paths, string-generated interface markup, eager GPU dependency imports before editor initialization, and surface pipeline prewarming outside an explicit frame. These could make a startup failure look like an entirely broken page.

The revision uses actual TypeScript and Preact components, not JavaScript renamed to TypeScript. Vite+ targets the Preact JSX runtime through Oxc. CSS loads independently from the GPU; images are build-managed imports; the configured base is relative. SVG icons avoid dependence on incorrectly decoded symbol glyphs.

The minimal source HTML explains that it needs a development server or a complete production build. A startup stylesheet sentinel and module-load error boundary report failed CSS/chunk requests. The editor mounts before importing the GPU renderer. Unsupported contexts, initialization failures and timeouts leave the UI and JSON recipes available, while GPU-image export remains disabled. Readiness means device initialization and pipeline prewarming completed, not that a frame was rendered. Startup and Reconnect do not draw or present a preview. An explicit Render requests a canvas frame; an explicit export can render staged settings as soon as initialization succeeds. GPU resources are cleaned up on detach and lifecycle transitions. No poster is exported while pretending to be live rendering.

Before the first completed explicit preview, the canvas area retains a labeled saved study reference. Thereafter it retains the last completed frame. Drag-to-pan, Ctrl-scroll-to-zoom and in-plane rotation provide only CSS bitmap framing approximations, including when WebGPU is unavailable; form, perforation, light, orbit and finish edits remain pending until Render. Resize and visibility return do not create render requests (visibility may resume an outstanding explicit request). Queued and actively rendering states are distinct, and edits cancel obsolete preview requests without presenting partial work.

Corona and optional perforation use the attributed non-commercial ORB-31 geometry by XorDev, not a replacement poster or a post-processing hole mask. The exact installed TypeGPU helpers are generated into `src/shaders/vendor/orb31.wgsl` and imported into the shared preview/export shader. The four controls, all-fields-absent recipe migration, unchanged uniform layout and geometry/license boundaries are documented in [RENDERING.md](RENDERING.md) and [AGENT_API.md](AGENT_API.md). These source contracts are not evidence of a completed GPU render.

Production regression tests cover UTF-8, all images, CSS, UI execution, missing CSS and chunks, root/subdirectory deployment, control updates, undo/redo, saved time and the responsive study drawer. Read VALIDATION.md for actual executed results rather than treating source-level checks as GPU evidence.

## Smaller pipelines and recoverable composition

Startup now prewarms only the display pass. The active form and opaque/glass surface pipeline compile on first explicit render or export and remain cached. The UI exposes preview quality and cancellation directly beside Render. Numeric fields display useful decimal precision without committing a rounded value merely on focus/blur. Saved modified recipes select the corresponding family/seed rather than an unrelated default poster.

A browser whose GPU process has already crashed may return a null adapter even after application code is fixed. The error now describes saving the recipe and restarting the browser; Reconnect retries device acquisition without reloading settings. This is a recovery instruction, not a promise that JavaScript can reset a crashed driver.


## Verified Glass Sculpture integration

The official nine-file example is preserved, with CLI verification recorded in `glass-sculpture/PROVENANCE.json`. `/?glass` mounts its adapted vGPU pipeline inside the existing Preact app. Original studies and their recipes remain at `/?classic`. The original example shapes are accompanied by Vesper and Reliquary, authored toward the user's blue/silver reference. Preview resolution and frame starts are bounded; all settings update the live render. Exports use the same shader and preserve canvas framing, with a scoped GPU context disposed in finally. The original editor also now automatically previews edits after a debounce.

## Expanded Glass studio, 2026-09-23

The current implementation supersedes earlier fixed-size export and two-shape composition notes: 16 forms, 33 source shadercn materials, persistent controls, reversed horizontal orbit, 8× macro lens, custom glass and light colors, configurable effects and tiled 4K/custom PNG export. The shadercn programs are projected animated materials, not arbitrary-shape physical volume simulations. Zero-strength materials bypass sampling; full-metal shading skips transmission; bounded HDR prevents overflow blocks. See README and RENDERING for the current behavior.

## Main workspace and environment controls

Glass Sculptures is now the sole mounted interface, independent of old workspace preferences and query flags. Retired source is retained unmounted. The environment exposes key/rim/gradient/beam/card/grade colors and background/card/beam intensity. New scenes are neutral; saved scenes preserve choices and offer a Neutral preset to remove environmental blue. The atmosphere is independent of the finish master switch.
