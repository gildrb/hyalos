# Local agent API

The editor exposes `window.exo` to browser automation. It does not expose a network service or send settings to a server.

```js
const live = await window.exo.ready;
if (!live) throw new Error('A real WebGPU renderer is required.');
const original = window.exo.getScene();
window.exo.setParameters({ seed: 240915, scene: 0, rotation: 38, time: 2.5 });
const png = await window.exo.exportPNG(3840, 2160);
// png is a Blob, with the settings and shader hash embedded as PNG text metadata.
window.exo.setScene(original);
```

`getScene()` returns an independent, validated project document. `setScene(document)` checks format, engine, version and parameter bounds. `setParameters(patch)` validates the complete merged model before applying it. Nested palette changes require a complete palette with `background`, `metal` and `energy` as `[L,C,H]` arrays. They do not accept RGB strings or hex values.

```js
window.exo.setParameters({ palette: {
  background: [0.115, 0.018, 270],
  metal: [0.79, 0.022, 240],
  energy: [0.84, 0.10, 235],
} });
```

`capabilities()` reports whether vGPU is live, the shader hash, maximum image pixel count, preview quality and export busy state. A thumbnail being visible is not evidence that `webgpu` is true. `ready` describes initial connection; after a device reconnect, query `capabilities()` for current status.

All writes pause playback. An active export rejects API writes and concurrent exports. Export snapshots time, settings and palette before work starts; it never advances animation time implicitly. Use the UI for cancellable exports. The simple agent `exportPNG` method currently does not expose an AbortSignal.

Use node tests for pure scene math and browser tests for GPU behavior. The real browser harness is `/tests/render.html` in the development server. It imports `src/gpu/renderer.js` and therefore the installed `vgpu` package, not a fake rendering adapter.
