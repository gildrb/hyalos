import { registerHooks } from 'node:module';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { PNG } from 'pngjs';
import { init } from 'vgpu/node';
import { PRESETS, preset, documentFor, validateExport } from '../src/model.ts';
import { addPngProject } from '../src/binary.ts';
import { renderPixels } from '../src/export.ts';

registerHooks({
  load(url, context, nextLoad) {
    if (url.endsWith('.wgsl?raw')) return { format: 'module', source: `export default ${JSON.stringify(readFileSync(new URL(url), 'utf8'))}`, shortCircuit: true };
    return nextLoad(url, context);
  },
});
const { createRenderer } = await import('../src/gpu/renderer.ts');
const args = process.argv.slice(2);
const width = Number(args.find(a => a.startsWith('--width='))?.split('=')[1] ?? 640);
const height = Math.round(width * 9 / 16);
validateExport(width, height);
const quality = args.find(a => a.startsWith('--quality='))?.split('=')[1] ?? 'final';
if (!['draft', 'balanced', 'final'].includes(quality)) throw new Error('Use draft, balanced or final quality.');
const directory = resolve(args.find(a => a.startsWith('--out='))?.slice(6) ?? 'work/renders');
const ids = args.filter(a => !a.startsWith('--'));
const studies = ids.length ? ids.map(id => {
  const study = PRESETS.find(p => p.id === id);
  if (!study) throw new Error(`Unknown study: ${id}`);
  return study;
}) : PRESETS;
mkdirSync(directory, { recursive: true });
const gpu = await init({ powerPreference: 'low-power' });
console.log(JSON.stringify({ adapter: gpu.adapter, width, height, quality }));
let renderer;
try {
  renderer = await createRenderer(null, error => console.error(error), { gpu });
  for (const study of studies) {
    const start = performance.now();
    const settings = preset(study.id);
    const pixels = await renderPixels(renderer, settings, width, height, { quality });
    const png = new PNG({ width, height });
    png.data.set(pixels);
    const recipe = { ...documentFor(settings, renderer.hash), output: { width, height, quality, colorSpace: 'srgb' } };
    const bytes = addPngProject(PNG.sync.write(png), JSON.stringify(recipe));
    writeFileSync(resolve(directory, `${study.id}.png`), bytes);
    console.log(`${study.id}: ${bytes.length} bytes, ${Math.round(performance.now() - start)} ms`);
  }
} finally {
  if (renderer) renderer.dispose();
  else gpu.dispose();
}
