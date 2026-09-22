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

`getScene()` returns an independent, validated document. `setScene(document)` checks format, engine, version and parameter bounds. `setParameters(patch)` validates the complete merged model. Nested palette changes require a complete palette with `background`, `metal` and `energy` as `[L,C,H]` arrays, not RGB strings or hex values.

```js
window.hyalos.setParameters({ palette: {
  background: [0.115, 0.018, 270],
  metal: [0.79, 0.022, 240],
  energy: [0.84, 0.10, 235],
} });
```

`capabilities()` reports live vGPU availability, shader hash, maximum image pixel count, preview quality and export busy state. A visible thumbnail is not evidence that `webgpu` is true. `ready` is a getter for the current connection promise. Wait for `window.hyalos` to exist: Preact publishes it after mounting.

API writes pause playback. An active export rejects writes and concurrent exports. Export snapshots time, settings and palette without advancing time implicitly. Use the UI for cancellable exports; `exportPNG` does not expose an AbortSignal.

The real browser harness is `/tests/render.html` on the development server. It imports `src/gpu/renderer.ts` and the installed `vgpu` package, not a mock adapter. See VALIDATION.md for the distinction between CPU tests, GPU-less UI tests and actual WebGPU qualification.
