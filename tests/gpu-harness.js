import { createRenderer } from '../src/gpu/renderer.js';
import { preset } from '../src/model.js';
import { renderPixels, exportStill } from '../src/export.js';
const errors = [];
window.gpuHarness = { errors, ready: false };
try {
  const renderer = await createRenderer(document.querySelector('canvas'), error => errors.push(String(error)));
  window.gpuHarness = {
    renderer, errors, ready: true, preset,
    async pixels(id = 'the-gift', tileSize = 1024) {
      return Array.from(await renderPixels(renderer, preset(id), 192, 108, { tileSize }));
    },
    async png(id = 'the-gift') { return Array.from(new Uint8Array(await (await exportStill(renderer, preset(id), 192, 108, 'image/png')).arrayBuffer())); },
  };
} catch (error) { errors.push(String(error)); window.gpuHarness.failed = true; }
