import { d } from 'typegpu';
import { sampler, target, type Frame, type Gpu } from 'vgpu';
import { ORB_CATALOG } from './catalog.ts';
import { ORB_SHADERS } from './shaders.ts';
import { createOrbScene, type OrbScene, type OrbSnapshot, type OrbUniformStruct } from './drive.ts';
import type { SculptureControls } from '../controls.ts';

export function createOrbMaterial(gpu: Gpu, initial?: OrbSnapshot, resolution = 384, format: GPUTextureFormat = 'rgba16float') {
  const output = target(gpu, { size: [resolution,resolution], format, label:'orb-material' });
  const linear = sampler(gpu,{minFilter:'linear',magFilter:'linear',addressModeU:'clamp-to-edge',addressModeV:'clamp-to-edge'});
  const pending = new Map<string,Promise<unknown>>();
  const scenes = new Map<string,OrbScene>();
  let active: string | undefined;
  let destroyed=false;
  let saved=initial;
  const drive = (controls:SculptureControls) => ({state:controls.orbState,paused:!controls.orbAnimate,params:controls.orbValues[controls.orb]?.params,colors:controls.orbValues[controls.orb]?.colors});
  async function prepare(controls:SculptureControls) {
    if(controls.orb==='none') return;
    if(scenes.has(controls.orb)) { await pending.get(controls.orb); return; }
    const definition=ORB_CATALOG.find(item=>item.key===controls.orb);
    if(!definition) throw new Error('Unknown orb material.');
    const schema=d.struct(Object.fromEntries(Object.entries(definition.schema).map(([key,type])=>[key,d[type]]))) as OrbUniformStruct;
    const scene=createOrbScene(gpu,{...definition,shader:ORB_SHADERS[definition.key],uniforms:schema},output.size,drive(controls));
    scenes.set(controls.orb,scene);
    if(saved?.key===controls.orb) { scene.restore(saved); scene.resize(output.size); saved=undefined; }
    const compilation=scene.shader.compile(output); pending.set(controls.orb,compilation);
    try { await compilation; } catch(error) { scenes.delete(controls.orb);scene.dispose();throw error; } finally { pending.delete(controls.orb); }
  }
  return {
    output, sampler:linear, prepare,
    render(current:Frame,controls:SculptureControls,dt:number) {
      if(destroyed || controls.orb==='none') { active=undefined; return; }
      const scene=scenes.get(controls.orb);
      if(!scene) throw new Error('Orb material is not prepared.');
      active=controls.orb;
      scene.advance(Math.min(dt,0.05),drive(controls));
      current.pass(output,scene.shader);
    },
    snapshot() { return active ? scenes.get(active)?.snapshot() : undefined; },
    restore(next?:OrbSnapshot) { saved=next; if(next && scenes.has(next.key)) { scenes.get(next.key)!.restore(next);scenes.get(next.key)!.resize(output.size);saved=undefined; } },
    destroy() { if(destroyed)return;destroyed=true;for(const scene of scenes.values())scene.dispose();scenes.clear();(output as typeof output & {destroy():void}).destroy(); },
  };
}
