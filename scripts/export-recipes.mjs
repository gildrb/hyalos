// Creates deterministic recipe examples. This does not render or validate a GPU image.
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { PRESETS, preset, documentFor } from '../src/model.ts';
const root = new URL('../', import.meta.url);
const read = path => readFile(new URL(path, root), 'utf8');
const common = await read('src/shaders/common.wgsl');
const scene = `${common}\n${await read('src/shaders/vendor/simplex3.wgsl')}\n${await read('src/shaders/vendor/orb31.wgsl')}\n${await read('src/shaders/scene.wgsl')}`;
const post = `${common}\n${await read('src/shaders/vendor/dither8.wgsl')}\n${await read('src/shaders/post.wgsl')}`;
const hash = createHash('sha256').update(scene + '\n---\n' + post).digest('hex');
await mkdir(new URL('examples/presets/', root), { recursive: true });
for (const p of PRESETS) await writeFile(new URL(`examples/presets/${p.id}.hyalos.json`, root), JSON.stringify(documentFor(preset(p.id), hash), null, 2) + '\n');
console.log(`Wrote ${PRESETS.length} recipes. Shader fingerprint: ${hash}`);
