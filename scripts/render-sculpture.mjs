import { registerHooks } from 'node:module';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { PNG } from 'pngjs';
import { init } from 'vgpu/node';
import { composition, parseSculpture } from '../src/studio/model.ts';
import { addPngProject, readPngProject } from '../src/binary.ts';
import { createHash } from 'node:crypto';
registerHooks({ load(url, context, next) {
  if (url.endsWith('.wgsl?raw')) return { format: 'module', source: `export default ${JSON.stringify(readFileSync(new URL(url), 'utf8'))}`, shortCircuit: true };
  return next(url, context);
} });
const { ORB_SHADERS } = await import('../src/studio/orbs/shaders.ts');
const { renderSculpturePixels } = await import('../src/studio/export.ts');
const args = process.argv.slice(2);
const directory = resolve(args.find(x => x.startsWith('--out='))?.slice(6) ?? 'work/sculptures');
const width = Number(args.find(x => x.startsWith('--width='))?.slice(8) ?? 960), height = Math.round(width*9/16);
const names = args.filter(x => !x.startsWith('--'));
mkdirSync(directory,{ recursive:true });
const gpu = await init();
try {
  for (const name of names.length ? names : ['vesper','reliquary']) {
    const input = args.find(x => x.startsWith('--recipe='))?.slice(9);
    const recipe = input ? parseSculpture(readPngProject(readFileSync(input))) : composition(name);
    recipe.controls.renderScale = 1;
    const surface = args.find(x => x.startsWith('--surface='))?.slice(10);
    if(surface==='chrome') {recipe.controls.metalness=1;recipe.controls.roughness=0.28;}
    if(surface==='polished') {recipe.controls.metalness=0.65;recipe.controls.roughness=0.18;}
    if(surface==='glass') {recipe.controls.metalness=0;recipe.controls.roughness=0.08;}
    const light = args.find(x => x.startsWith('--light='))?.slice(8);
    if (light) recipe.controls.light = light;
    const orb = args.find(x => x.startsWith('--orb='))?.slice(6); if(orb)recipe.controls.orb=orb;
    recipe.controls.exportWidth=width; recipe.controls.exportHeight=height;
    try {
      const pixels = await renderSculpturePixels(gpu,recipe);
      const png = new PNG({width,height}); png.data.set(new Uint8Array(pixels));
      recipe.shaderHash = createHash('sha256').update(['src/studio/sculpture.wgsl','src/studio/bloom-extract.wgsl','glass-sculpture/bloom-blur.wgsl','src/studio/present.wgsl'].map(p=>readFileSync(p,'utf8')).concat(Object.values(ORB_SHADERS)).join('\n---\n')).digest('hex');
      const data = addPngProject(PNG.sync.write(png),JSON.stringify({...recipe,output:{width,height}}));
      writeFileSync(resolve(directory,`${name}.png`),data); console.log(`${name}: ${data.length} bytes`);
    } finally { /* Targets are released by the shared exporter. */ }
  }
} finally { gpu.dispose(); }
