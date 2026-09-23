import { createOrbMaterial } from './orbs/material.ts';
import type { OrbSnapshot } from './orbs/drive.ts';
// Adapted from the verified vGPU Glass Sculpture example. See glass-sculpture/PROVENANCE.json.
import {
  effect,
  sampler,
  target,
  type Frame,
  type Gpu,
  type Surface,
  type Target,
} from 'vgpu';
import type { StudioCamera } from './model.ts';
import bloomBlurWgsl from '../../glass-sculpture/bloom-blur.wgsl?raw';
import bloomExtractWgsl from '../../glass-sculpture/bloom-extract.wgsl?raw';
import presentWgsl from './present.wgsl?raw';
import sculptureWgsl from './sculpture.wgsl?raw';

type Output = Surface | Target;
type Vec3 = readonly [number, number, number];

import { SHAPES, GLASS_TINTS, RENDER_SCALES, DEFAULT_CONTROLS, type SculptureControls, type LightRigName } from './controls.ts';
export type { SculptureControls } from './controls.ts';

interface LightRig {
  readonly keyColor: Vec3;
  readonly keyPower: number;
  readonly rimColor: Vec3;
  readonly rimPower: number;
  readonly backgroundTop: Vec3;
  readonly backgroundBottom: Vec3;
  readonly floorLuminance: number;
}

interface MutableLightRig {
  keyColor: [number, number, number];
  keyPower: number;
  rimColor: [number, number, number];
  rimPower: number;
  backgroundTop: [number, number, number];
  backgroundBottom: [number, number, number];
  floorLuminance: number;
}

const LIGHT_RIGS: Readonly<Record<LightRigName, LightRig>> = {
  custom: {
    keyColor: [0.56,0.8,1], keyPower: 16, rimColor: [0.3,0.55,1], rimPower: 9,
    backgroundTop: [0.009,0.025,0.06], backgroundBottom: [0.001,0.002,0.004], floorLuminance: 0.4,
  },
  lunar: {
    keyColor: [0.56, 0.8, 1], keyPower: 10,
    rimColor: [0.72, 0.86, 1], rimPower: 14,
    backgroundTop: [0.018, 0.026, 0.042], backgroundBottom: [0.003, 0.005, 0.009],
    floorLuminance: 0.2,
  },
  studio: {
    keyColor: [1, 0.92, 0.82],
    keyPower: 6,
    rimColor: [0.65, 0.8, 1],
    rimPower: 5,
    backgroundTop: [0.95, 0.96, 1],
    backgroundBottom: [0.3, 0.31, 0.34],
    floorLuminance: 1.4,
  },
  noir: {
    keyColor: [1, 0.97, 0.92],
    keyPower: 16,
    rimColor: [0.35, 0.45, 0.8],
    rimPower: 9,
    backgroundTop: [0.1, 0.1, 0.12],
    backgroundBottom: [0.02, 0.02, 0.03],
    floorLuminance: 1.6,
  },
  gel: {
    keyColor: [1, 0.4, 0.3],
    keyPower: 11,
    rimColor: [0.15, 0.8, 1],
    rimPower: 11,
    backgroundTop: [0.16, 0.08, 0.22],
    backgroundBottom: [0.04, 0.02, 0.07],
    floorLuminance: 1.3,
  },
  golden: {
    keyColor: [1, 0.72, 0.42],
    keyPower: 9,
    rimColor: [0.45, 0.55, 0.9],
    rimPower: 3,
    backgroundTop: [1, 0.78, 0.55],
    backgroundBottom: [0.36, 0.2, 0.14],
    floorLuminance: 1.25,
  },
};

const HDR_FORMAT: GPUTextureFormat = 'rgba16float';
const BLOOM_STRENGTH = 0.45;
const RIG_EASE_RATE = 2.45;

interface SceneTargets {
  readonly hdr: Target;
  readonly bloomA: Target;
  readonly bloomB: Target;
}

export interface SculptureScene {
  prepare(output: Output): Promise<void>;
  prepareMaterial(controls: SculptureControls): Promise<void>;
  orbSnapshot(): OrbSnapshot | undefined;
  restoreOrb(snapshot?: OrbSnapshot): void;
  resize(outputSize: readonly [number, number], renderScale: number): void;
  render(
    currentFrame: Frame,
    output: Output,
    camera: StudioCamera,
    controls: Readonly<SculptureControls>,
    state: {
      readonly renderMaterial?: boolean;
      readonly region?: { readonly origin: readonly [number,number]; readonly fullSize: readonly [number,number] };
      readonly sculptureTime: number;
      readonly clockTime: number;
      readonly deltaTime: number;
      readonly light: { readonly azimuth: number; readonly elevation: number };
    },
  ): void;
  destroy(): void;
}

export function createScene(
  gpu: Gpu,
  output: Output,
  controls: Readonly<SculptureControls>,
  savedOrb?: OrbSnapshot,
  materialResolution = 384,
): SculptureScene {
  const orbMaterial = createOrbMaterial(gpu,savedOrb,materialResolution);
  const linearSampler = sampler(gpu, {
    minFilter: 'linear',
    magFilter: 'linear',
    addressModeU: 'clamp-to-edge',
    addressModeV: 'clamp-to-edge',
  });
  const sculpture = effect(gpu, sculptureWgsl, { label: 'glass-sculpture' });
  const extract = effect(gpu, bloomExtractWgsl, { label: 'glass-sculpture-bloom-extract' });
  const blurHorizontal = effect(gpu, bloomBlurWgsl, { label: 'glass-sculpture-bloom-horizontal' });
  const blurVertical = effect(gpu, bloomBlurWgsl, { label: 'glass-sculpture-bloom-vertical' });
  const present = effect(gpu, presentWgsl, { label: 'glass-sculpture-present' });
  const targets = createTargets(gpu, output.size, controls.renderScale);
  const rig = copyRig(selectedRig(controls));
  let destroyed = false;

  try {
    bindTargets();
  } catch (error) {
    destroyTarget(targets.bloomB);
    destroyTarget(targets.bloomA);
    destroyTarget(targets.hdr);
    throw error;
  }

  return {
    async prepare(currentOutput) {
      await Promise.all([
        orbMaterial.prepare(controls),
        sculpture.compile(targets.hdr),
        extract.compile(targets.bloomA),
        blurHorizontal.compile(targets.bloomB),
        blurVertical.compile(targets.bloomA),
        present.compile({ colors: [currentOutput.format] }),
      ]);
    },
    prepareMaterial: orbMaterial.prepare,
    orbSnapshot: orbMaterial.snapshot,
    restoreOrb: orbMaterial.restore,
    resize(outputSize, renderScale) {
      if (destroyed) return;
      const [width, height] = scaledSize(outputSize, renderScale);
      targets.hdr.resize([width, height]);
      const bloomSize: [number, number] = [
        Math.max(1, Math.floor(width / 4)),
        Math.max(1, Math.floor(height / 4)),
      ];
      targets.bloomA.resize(bloomSize);
      targets.bloomB.resize(bloomSize);
      bindTargets();
    },
    render(currentFrame, currentOutput, camera, currentControls, state) {
      if (destroyed) return;
      if(state.renderMaterial !== false) orbMaterial.render(currentFrame,currentControls,state.deltaTime);
      easeRig(rig, selectedRig(currentControls), state.deltaTime);
      const keyDirection = lightDirection(camera.yaw + state.light.azimuth, state.light.elevation);
      const rimDirection = lightDirection(camera.yaw + state.light.azimuth + Math.PI * 0.85, 0.35);
      sculpture.set({
        params: {
          resolution: state.region?.fullSize ?? targets.hdr.size,
          tile_origin: state.region?.origin ?? [0,0],
          tile_size: targets.hdr.size,
          orb_enabled: currentControls.orb === 'none' ? 0 : 1,
          orb_mode: ['surface','emission','reflection'].indexOf(currentControls.orbMode),
          orb_mapping: ['triplanar','normal','screen'].indexOf(currentControls.orbMapping),
          orb_strength: currentControls.orbStrength, orb_scale: currentControls.orbScale,
          shape: SHAPES.indexOf(currentControls.shape),
          tint: GLASS_TINTS.indexOf(currentControls.glass),
          time: state.sculptureTime,
          quality: currentControls.renderScale,
          yaw: camera.yaw,
          pitch: camera.pitch,
          radius: camera.radius,
          focal_length: 2.2*(camera.lens ?? 1),
          atmosphere_color: [...linearHex(currentControls.atmosphereColor),currentControls.environmentPower],
          reflection_color: [...linearHex(currentControls.reflectionColor),currentControls.reflectionPower],
          custom_tint: [...linearHex(currentControls.glassColor),currentControls.tintDensity],
          dispersion: currentControls.dispersion ? 1 : 0,
          strip_angle: 0.8 + state.clockTime * 0.1,
          floor_luminance: rig.floorLuminance,
          metalness: currentControls.metalness,
          visible_lights: currentControls.visibleLights ? 1 : 0,
          atmosphere: currentControls.atmosphere,
          key: [...keyDirection, rig.keyPower],
          key_color: [...rig.keyColor, 0],
          rim: [...rimDirection, rig.rimPower],
          rim_color: [...rig.rimColor, 0],
          background_top: [...rig.backgroundTop, 0],
          background_bottom: [...rig.backgroundBottom, 0],
        },
      });
      present.set({ params: {
        time: state.clockTime,
        full_size: state.region?.fullSize ?? targets.hdr.size,
        tile_origin: state.region?.origin ?? [0,0], tile_size: targets.hdr.size,
        antialias: currentControls.antialias ? 1 : 0,
        bloom_strength: currentControls.effects ? currentControls.bloom : 0,
        grain: currentControls.effects ? currentControls.grain : 0,
        texture: currentControls.effects ? currentControls.texture : 0,
        grade_color: [...linearHex(currentControls.gradeColor),0],
        coolness: currentControls.effects ? currentControls.coolness : 0,
        exposure: currentControls.exposure, vignette: currentControls.effects ? 0.7 : 0,
      } });
      blurHorizontal.set({ params: { direction: [targets.bloomA.texelSize[0]*currentControls.glowRadius,0] } });
      blurVertical.set({ params: { direction: [0,targets.bloomB.texelSize[1]*currentControls.glowRadius] } });
      currentFrame.pass(targets.hdr, sculpture);
      currentFrame.pass(targets.bloomA, extract);
      currentFrame.pass(targets.bloomB, blurHorizontal);
      currentFrame.pass(targets.bloomA, blurVertical);
      currentFrame.pass(currentOutput, present);
    },
    destroy() {
      if (destroyed) return;
      destroyed = true;
      orbMaterial.destroy();
      destroyTarget(targets.bloomB);
      destroyTarget(targets.bloomA);
      destroyTarget(targets.hdr);
    },
  };

  function bindTargets() {
    sculpture.set({orb_texture:orbMaterial.output,orb_sampler:orbMaterial.sampler});
    extract.set({
      params: {
        texel: targets.hdr.texelSize,
        threshold: 1,
        padding: 0,
      },
      source: targets.hdr,
      linear_sampler: linearSampler,
    });
    blurHorizontal.set({
      params: { direction: [targets.bloomA.texelSize[0], 0], padding: [0, 0] },
      source: targets.bloomA,
      linear_sampler: linearSampler,
    });
    blurVertical.set({
      params: { direction: [0, targets.bloomB.texelSize[1]], padding: [0, 0] },
      source: targets.bloomB,
      linear_sampler: linearSampler,
    });
    present.set({
      params: { bloom_strength: BLOOM_STRENGTH, time: 0, grain: 0.012, texture: 0, coolness: 0, grade_color: [1,1,1,0], exposure: 1.05, vignette: 0.7, antialias: 1, full_size: targets.hdr.size, tile_origin: [0,0], tile_size: targets.hdr.size },
      scene_texture: targets.hdr,
      bloom_texture: targets.bloomA,
      linear_sampler: linearSampler,
    });
  }
}

function createTargets(gpu: Gpu, outputSize: readonly [number, number], renderScale: number): SceneTargets {
  const owned: Target[] = [];
  const own = (created: Target) => {
    owned.push(created);
    return created;
  };
  try {
    const [width, height] = scaledSize(outputSize, renderScale);
    const bloomSize: [number, number] = [
      Math.max(1, Math.floor(width / 4)),
      Math.max(1, Math.floor(height / 4)),
    ];
    return {
      hdr: own(target(gpu, { size: [width, height], format: HDR_FORMAT, label: 'glass-sculpture-hdr' })),
      bloomA: own(target(gpu, { size: bloomSize, format: HDR_FORMAT, label: 'glass-sculpture-bloom-a' })),
      bloomB: own(target(gpu, { size: bloomSize, format: HDR_FORMAT, label: 'glass-sculpture-bloom-b' })),
    };
  } catch (error) {
    for (const resource of owned.reverse()) destroyTarget(resource);
    throw error;
  }
}

function scaledSize(size: readonly [number, number], renderScale: number): [number, number] {
  const scale = Number.isFinite(renderScale)
    ? Math.max(RENDER_SCALES[0], Math.min(RENDER_SCALES.at(-1)!, renderScale))
    : DEFAULT_CONTROLS.renderScale;
  return [
    Math.max(1, Math.floor(size[0] * scale)),
    Math.max(1, Math.floor(size[1] * scale)),
  ];
}

function lightDirection(azimuth: number, elevation: number): Vec3 {
  const radius = Math.cos(elevation);
  return [Math.sin(azimuth) * radius, Math.sin(elevation), Math.cos(azimuth) * radius];
}

function copyRig(source: LightRig): MutableLightRig {
  return {
    keyColor: [...source.keyColor],
    keyPower: source.keyPower,
    rimColor: [...source.rimColor],
    rimPower: source.rimPower,
    backgroundTop: [...source.backgroundTop],
    backgroundBottom: [...source.backgroundBottom],
    floorLuminance: source.floorLuminance,
  };
}

function easeRig(current: MutableLightRig, goal: LightRig, deltaTime: number): void {
  const blend = 1 - Math.exp(-RIG_EASE_RATE * Math.max(0, Math.min(0.1, deltaTime)));
  for (let channel = 0; channel < 3; channel++) {
    current.keyColor[channel] += (goal.keyColor[channel] - current.keyColor[channel]) * blend;
    current.rimColor[channel] += (goal.rimColor[channel] - current.rimColor[channel]) * blend;
    current.backgroundTop[channel] += (goal.backgroundTop[channel] - current.backgroundTop[channel]) * blend;
    current.backgroundBottom[channel] += (goal.backgroundBottom[channel] - current.backgroundBottom[channel]) * blend;
  }
  current.keyPower += (goal.keyPower - current.keyPower) * blend;
  current.rimPower += (goal.rimPower - current.rimPower) * blend;
  current.floorLuminance += (goal.floorLuminance - current.floorLuminance) * blend;
}

function destroyTarget(resource: Target): void {
  (resource as Target & { destroy(): void }).destroy();
}


function linearHex(hex: string): Vec3 {
  const value=parseInt(hex.slice(1),16);
  return [value>>16,(value>>8)&255,value&255].map(n=>{const v=n/255;return v<=0.04045?v/12.92:Math.pow((v+0.055)/1.055,2.4);}) as unknown as Vec3;
}
function selectedRig(controls: Readonly<SculptureControls>): LightRig {
  if(controls.light!=='custom')return LIGHT_RIGS[controls.light];
  return {keyColor:linearHex(controls.keyColor),keyPower:controls.keyPower,rimColor:linearHex(controls.rimColor),rimPower:controls.rimPower,backgroundTop:linearHex(controls.skyColor),backgroundBottom:linearHex(controls.groundColor),floorLuminance:0.4};
}
