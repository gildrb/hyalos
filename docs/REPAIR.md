# Startup repair and Preact migration

The reported screenshot showed browser-default layout, a broken poster, mangled symbols and a Connecting label. It does not include the serving URL, response headers or console. The exact hosting failure cannot be established from the screenshot alone. The original HTML already contained a UTF-8 meta declaration.

Confirmed weaknesses in the original source were root-absolute asset paths, string-generated interface markup, eager GPU dependency imports before editor initialization, and surface pipeline prewarming outside an explicit frame. These could make a startup failure look like an entirely broken page.

The revision uses actual TypeScript and Preact components, not JavaScript renamed to TypeScript. Vite+ targets the Preact JSX runtime through Oxc. CSS loads independently from the GPU; images are build-managed imports; the configured base is relative. SVG icons avoid dependence on incorrectly decoded symbol glyphs.

The minimal source HTML explains that it needs a development server or a complete production build. A startup stylesheet sentinel and module-load error boundary report failed CSS/chunk requests. The editor mounts before importing the GPU renderer. Unsupported contexts, initialization failures and timeouts leave the UI and JSON recipes available, while live-image export remains disabled. GPU resources are cleaned up on detach and lifecycle transitions. No poster is exported while pretending to be live rendering.

Production regression tests cover UTF-8, all images, CSS, UI execution, missing CSS and chunks, root/subdirectory deployment, control updates, undo/redo, saved time and the responsive study drawer. Read VALIDATION.md for actual executed results rather than treating source-level checks as GPU evidence.
