import type { OrbSnapshot } from './orbs/drive.ts';
import { DEFAULT_CONTROLS, normalizeControls, type SculptureControls } from './controls.ts';
import { DEFAULT_YAW, DEFAULT_PITCH, DEFAULT_RADIUS, type CameraState } from '../../glass-sculpture/camera.ts';
export type StudioCamera = CameraState & { lens?: number };
export const STUDIO_STORAGE = 'hyalos.glass-sculpture.v1';
export interface SculptureRecipe {
  format: 'hyalos-glass-sculpture';
  version: 1;
  shaderHash?: string;
  orbSnapshot?: OrbSnapshot;
  controls: SculptureControls;
  camera: StudioCamera;
  light: { azimuth: number; elevation: number };
  sculptureTime: number;
  clockTime: number;
}
export function initialSculpture(): SculptureRecipe {
  return { format: 'hyalos-glass-sculpture', version: 1, controls: { ...DEFAULT_CONTROLS }, camera: { yaw: DEFAULT_YAW, pitch: DEFAULT_PITCH, radius: DEFAULT_RADIUS }, light: { azimuth: 0.9, elevation: 0.5 }, sculptureTime: 0, clockTime: 0 };
}
export function parseSculpture(text: string): SculptureRecipe {
  if (text.length > 65536) throw new Error('Recipe is too large.');
  const value = JSON.parse(text) as SculptureRecipe;
  if (value?.format !== 'hyalos-glass-sculpture' || value.version !== 1) throw new Error('This file is not a Glass Sculptures recipe.');
  if (!value.controls || !value.camera || !value.light) throw new Error('Incomplete sculpture recipe.');
  const normalized = normalizeControls(value.controls);
  for (const key of Object.keys(normalized) as (keyof SculptureControls)[]) {
    if (value.controls[key] === undefined && !['shape','glass','light','dispersion','spin','renderScale'].includes(key)) continue;
    if (key === 'orbValues' ? JSON.stringify(normalized[key]) !== JSON.stringify(value.controls[key]) : normalized[key] !== value.controls[key]) throw new Error(`Invalid ${key}.`);
  }
  if (normalized.exportWidth * normalized.exportHeight > 33554432) throw new Error('Export exceeds 32 megapixels.');
  const numbers = [value.camera.yaw, value.camera.pitch, value.camera.radius, value.light.azimuth, value.light.elevation, value.sculptureTime, value.clockTime];
  if (numbers.some(n => !Number.isFinite(n)) || value.camera.radius < 1.6 || value.camera.radius > 6.5 || value.camera.pitch < -0.2 || value.camera.pitch > 1.15 || value.sculptureTime < 0 || value.clockTime < 0) throw new Error('Invalid sculpture state.');
  if(value.camera.lens!==undefined && (!Number.isFinite(value.camera.lens) || value.camera.lens<1 || value.camera.lens>8)) throw new Error('Invalid lens zoom.');
  if(value.orbSnapshot) {
    const snapshot=value.orbSnapshot;
    if(typeof snapshot.key!=='string' || !['words','paramCur','paramVel','paramClock','colorVel'].every(key=>Array.isArray(snapshot[key as keyof OrbSnapshot]) && (snapshot[key as keyof OrbSnapshot] as number[]).length<1024 && (snapshot[key as keyof OrbSnapshot] as number[]).every(Number.isFinite)) || ![snapshot.seconds,snapshot.anim,snapshot.speed,snapshot.speedVel,snapshot.volume?.in,snapshot.volume?.out].every(Number.isFinite)) throw new Error('Invalid orb animation snapshot.');
  }
  return { ...value, controls: normalized };
}

export function composition(shape: SculptureControls['shape']): SculptureRecipe {
  const state = initialSculpture();
  state.controls.shape = shape;
  if (shape === 'vesper' || shape === 'reliquary') {
    state.controls = { ...state.controls, light: 'lunar', dispersion: false, spin: false, metalness: 0.6, coolness: 0.6, atmosphere: 0.3 };
    state.camera = { yaw: 0.12, pitch: 0.08, radius: shape === 'vesper' ? 2.8 : 3.5 };
    state.light = { azimuth: -0.8, elevation: 0.5 };
  }
  return state;
}
