// Native GPU thumbnail generator; no substitute artwork or CPU shader implementation.
import { registerHooks } from 'node:module';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { PNG } from 'pngjs';
import { init } from 'vgpu/node';
import { frame } from 'vgpu';
import { ORB_CATALOG } from '../src/studio/orbs/catalog.ts';
import { initialSculpture } from '../src/studio/model.ts';
registerHooks({load(url,ctx,next){if(url.endsWith('.wgsl?raw'))return{format:'module',source:`export default ${JSON.stringify(readFileSync(new URL(url),'utf8'))}`,shortCircuit:true};return next(url,ctx);}});
const {createOrbMaterial}=await import('../src/studio/orbs/material.ts');
const destination=resolve('src/studio/orbs/previews');mkdirSync(destination,{recursive:true});
const gpu=await init();
try {
 for(const orb of ORB_CATALOG) {
  const material=createOrbMaterial(gpu,undefined,192,'rgba8unorm');
  try {
   const controls={...initialSculpture().controls,orb:orb.key};
   await material.prepare(controls);
   frame(gpu,f=>material.render(f,controls,0));
   await gpu.gpu.queue.onSubmittedWorkDone();await gpu.settled();
   const pixels=new Uint8Array(await material.output.color.read({mipLevel:0,region:'all'}));
   const png=new PNG({width:192,height:192});png.data.set(pixels);
   writeFileSync(resolve(destination,`${orb.key}.png`),PNG.sync.write(png));
   console.log(`${orb.key}: compiled and rendered (${pixels.filter((v,i)=>i%4!==3&&v>0).length} nonzero channels)`);
  } finally {material.destroy();}
 }
 writeFileSync('src/studio/orbs/previews.ts',ORB_CATALOG.map((v,i)=>`import preview${i} from './previews/${v.key}.png';`).join('\n')+'\nexport const ORB_PREVIEWS:Readonly<Record<string,string>>={'+ORB_CATALOG.map((v,i)=>`'${v.key}':preview${i}`).join(',')+'};\n');
} finally {gpu.dispose();}
