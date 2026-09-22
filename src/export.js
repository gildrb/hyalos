import { validateExport, exportTiles, documentFor } from './model.js';
import { addPngProject, zip } from './binary.js';
export function download(blob, name) {
  const url = URL.createObjectURL(blob), a = document.createElement('a');
  a.href = url; a.download = name; a.click();
  // Delay revocation so Safari has time to consume the blob.
  setTimeout(() => URL.revokeObjectURL(url), 30000);
}
function abortIfNeeded(signal) { if (signal?.aborted) throw new DOMException('Export cancelled.', 'AbortError'); }
const breathe = () => new Promise((resolve) => setTimeout(resolve, 0));
export async function renderPixels(renderer, settings, width, height, { signal, onProgress = () => {}, tileSize = 1024, quality = 'final' } = {}) {
  validateExport(width, height);
  const snapshot = structuredClone(settings);
  // Halo covers the complete optical kernel AND displaced dot-centre sampling.
  const halo = Math.ceil((snapshot.bloomRadius * 3 + snapshot.spacing) * height / 1080) + 4;
  const safeTile = Math.min(tileSize, renderer.maxTexture - 2 * halo);
  if (safeTile < 32) throw new Error('GPU texture limit is too small for this output.');
  const tiles = [...exportTiles(width, height, safeTile, halo)];
  const pixels = new Uint8ClampedArray(width * height * 4);
  let done = 0;
  for (const tile of tiles) {
    abortIfNeeded(signal);
    const data = await renderer.readTile(snapshot, width, height, tile, quality);
    abortIfNeeded(signal);
    if (data.byteLength !== tile.width * tile.height * 4) throw new Error('Unexpected GPU readback size.');
    for (let row = 0; row < tile.h; row++) {
      const source = ((tile.y - tile.top + row) * tile.width + tile.x - tile.left) * 4;
      pixels.set(data.subarray(source, source + tile.w * 4), ((tile.y + row) * width + tile.x) * 4);
    }
    onProgress(++done / tiles.length); await breathe();
  }
  return pixels;
}
export async function encodePixels(pixels, width, height, type = 'image/png', quality = 0.95) {
  const canvas = document.createElement('canvas'); canvas.width = width; canvas.height = height;
  const context = canvas.getContext('2d', { colorSpace: 'srgb' });
  if (!context) throw new Error('Image encoder unavailable.');
  context.putImageData(new ImageData(pixels, width, height, { colorSpace: 'srgb' }), 0, 0);
  const blob = await new Promise((resolve, reject) => canvas.toBlob((b) => b ? resolve(b) : reject(new Error('Image encoding failed.')), type, quality));
  canvas.width = canvas.height = 1;
  if (blob.type !== type) throw new Error(`This browser cannot encode ${type}. Choose PNG.`);
  return blob;
}
export async function exportStill(renderer, settings, width, height, type, options = {}) {
  const snapshot = structuredClone(settings);
  const pixels = await renderPixels(renderer, snapshot, width, height, options);
  abortIfNeeded(options.signal);
  const encoded = await encodePixels(pixels, width, height, type);
  const metadata = JSON.stringify({ ...documentFor(snapshot, renderer.hash), output: { width, height, quality: options.quality || 'final', colorSpace: 'srgb' } });
  if (type === 'image/png') {
    const bytes = addPngProject(new Uint8Array(await encoded.arrayBuffer()), metadata);
    return new Blob([bytes], { type });
  }
  // JPEG/WebP exports include a lossless recipe sidecar rather than silently losing it.
  const extension = type === 'image/jpeg' ? 'jpg' : 'webp';
  return zip([[`visual.${extension}`, new Uint8Array(await encoded.arrayBuffer())], ['visual.exo.json', metadata]]);
}
export async function exportSequence(renderer, settings, width, height, fps, seconds, { signal, onProgress = () => {} } = {}) {
  validateExport(width, height);
  if (![fps, seconds].every(Number.isInteger) || fps < 1 || fps > 60 || seconds < 1 || seconds > 60 || fps * seconds > 600 || width * height > 2073600) throw new Error('Sequences: up to 1080p, 60 FPS, 60 seconds, and 600 frames.');
  const snapshot = structuredClone(settings), count = fps * seconds, files = [];
  const meta = { ...documentFor(snapshot, renderer.hash), output: { width, height, fps, count, startTime: snapshot.time, quality: 'final', colorSpace: 'srgb' } };
  files.push(['project.exo.json', JSON.stringify(meta, null, 2)]);
  files.push(['ENCODE.txt', `ffmpeg -framerate ${fps} -i frames/%05d.png -c:v libx264 -crf 16 -pix_fmt yuv420p visual.mp4\n\nPNG frames are exact-time samples, not a screen recording.\n`]);
  let total = 0;
  for (let i = 0; i < count; i++) {
    abortIfNeeded(signal);
    const s = { ...snapshot, time: (snapshot.time + i / fps) % snapshot.duration };
    const image = await exportStill(renderer, s, width, height, 'image/png', { signal, onProgress: (p) => onProgress((i + p) / count) });
    const data = new Uint8Array(await image.arrayBuffer()); total += data.length;
    if (total > 240 * 1024 * 1024) throw new Error('Sequence exceeds the 240 MiB safety budget. Reduce duration or resolution.');
    files.push([`frames/${String(i).padStart(5, '0')}.png`, data]);
  }
  abortIfNeeded(signal); return zip(files);
}
