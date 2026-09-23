import type { Settings, Study, Palette, NumericKey, Recipe, ExportTile } from './types.ts';
/** All authored color values are OKLCH: lightness 0..1, chroma, hue in degrees. */
export const ENGINE = 'hyalos-prometheus/1';
export const STORAGE_KEY = 'hyalos.visuals.v1';
export const SCENES = ['Prometheus', 'Commons', 'Hearth', 'Relay', 'Knot', 'Gyroid', 'Droplets', 'Reliquary', 'Sanctum', 'Corona'];
export const FINISHES = ['Optical', 'Dot matrix', 'Ordered dither', 'Phosphor'];
export const PALETTES: Record<string, Palette> = {
  'Nocturne': { background: [0.065, 0.012, 265], metal: [0.69, 0.035, 220], energy: [0.79, 0.105, 220] },
  'Patina': { background: [0.075, 0.009, 245], metal: [0.71, 0.05, 74], energy: [0.79, 0.10, 65] },
  'Cold fire': { background: [0.115, 0.018, 270], metal: [0.79, 0.022, 240], energy: [0.84, 0.10, 235] },
  'Ivory': { background: [0.10, 0.008, 85], metal: [0.80, 0.026, 83], energy: [0.91, 0.06, 88] },
  'Ember': { background: [0.12, 0.018, 40], metal: [0.64, 0.08, 53], energy: [0.82, 0.13, 65] },
  'Ion': { background: [0.10, 0.016, 300], metal: [0.72, 0.045, 280], energy: [0.79, 0.12, 290] },
  'Silver': { background: [0.09, 0, 0], metal: [0.78, 0, 0], energy: [0.93, 0, 0] },
};
// [minimum, maximum, step]. Used by UI, import validation, and tests.
export const RANGES = {
  seed: [0, 16777215, 1], scene: [0, 9, 1], finish: [0, 3, 1],
  rotation: [-180, 180, 1], twist: [-2, 2, 0.01], spread: [0.5, 1.8, 0.01],
  thickness: [0.015, 0.16, 0.001], zoom: [0.65, 2, 0.01], panX: [-1.8, 1.8, 0.01], panY: [-1.8, 1.8, 0.01],
  holeWarp: [0.3, 10, 0.01], holeFrequency: [0.15, 30, 0.01], holeSoftness: [0.015, 4, 0.005], perforation: [0, 1, 0.01],
  yaw: [-55, 55, 1], pitch: [-40, 40, 1], nodes: [3, 9, 1],
  roughness: [0.06, 0.8, 0.01], metallic: [0, 1, 0.01], detail: [0, 0.35, 0.005],
  transmission: [0, 1, 0.01], ior: [1, 2.5, 0.01], dispersion: [0, 0.08, 0.001], absorption: [0, 4, 0.01],
  emitter: [0, 1, 0.01], power: [0, 160, 1], radius: [0.06, 0.35, 0.005], keyAngle: [-180, 180, 1], fill: [0, 1, 0.01],
  beam: [0, 1, 0.01], beamAngle: [8, 60, 1],
  density: [0, 1, 0.01], anisotropy: [-0.6, 0.8, 0.01], turbulence: [0.3, 3, 0.01],
  exposure: [-3, 3, 0.05], contrast: [0.7, 2, 0.01], bloom: [0, 0.65, 0.01], bloomRadius: [1, 18, 0.5],
  grain: [0, 0.12, 0.001], vignette: [0, 0.6, 0.01], spacing: [3, 20, 0.25], dotSize: [0.15, 0.49, 0.01],
  dither: [0, 1, 0.01], sampleGrid: [1, 3, 1], time: [0, 60, 0.001], duration: [2, 60, 1],
};
export const DEFAULT: Settings = {
  seed: 240915, scene: 4, finish: 0, rotation: 38, twist: 0.7, spread: 1.08,
  thickness: 0.11, zoom: 1.32, panX: 0.1, panY: 0, yaw: -24, pitch: 12, nodes: 5,
  holeWarp: 0.9, holeFrequency: 5.25, holeSoftness: 0.42, perforation: 0,
  roughness: 0.14, metallic: 0.92, detail: 0,
  transmission: 0, ior: 1.5, dispersion: 0.004, absorption: 0.35,
  emitter: 0, power: 95, radius: 0.12, keyAngle: -52, fill: 0.35, beam: 0.85, beamAngle: 18,
  density: 0.045, anisotropy: 0.3, turbulence: 0.65,
  exposure: 0.35, contrast: 1.12, bloom: 0.12, bloomRadius: 6,
  grain: 0.006, vignette: 0.18, spacing: 3.5, dotSize: 0.35, dither: 1, sampleGrid: 2,
  time: 0, duration: 12, palette: { background: [0.085, 0.014, 260], metal: [0.88, 0.014, 230], energy: [0.94, 0.045, 225] },
};
export const PRESETS: readonly Study[] = [
  { id: 'the-gift', name: 'The gift', concept: 'A silver knot caught in a shaft of cold light.', settings: {} },
  { id: 'commons', name: 'The commons', concept: 'A constellation of crystal vessels.', settings: { seed: 240916, scene: 1, rotation: 26, spread: 1.06, zoom: 1.17, panX: 0, yaw: 18, pitch: -14, thickness: 0.08, nodes: 5, metallic: 0, roughness: 0.1, detail: 0, transmission: 1, ior: 1.46, dispersion: 0.002, absorption: 0.12, density: 0.012, power: 110, keyAngle: 55, fill: 0.6, beam: 0.3, exposure: 0.45, contrast: 1.05 } },
  { id: 'hearth', name: 'An inner fire', concept: 'Molten amber folded into an endless knot.', settings: { seed: 530817, scene: 4, rotation: -32, twist: 0.45, spread: 1.05, thickness: 0.15, zoom: 1.28, panX: 0, yaw: -26, pitch: 18, nodes: 3, metallic: 0, roughness: 0.12, detail: 0, transmission: 1, ior: 1.48, dispersion: 0.003, absorption: 0.22, density: 0.018, power: 105, keyAngle: -65, fill: 0.45, beam: 0.55, exposure: 0.45, palette: { background: [0.08, 0.009, 55], metal: [0.92, 0.04, 78], energy: [0.95, 0.055, 75] } } },
  { id: 'relay', name: 'A shared signal', concept: 'Mercury suspended along an invisible current.', settings: { seed: 680127, scene: 6, rotation: -36, spread: 1.15, twist: 1.2, thickness: 0.16, zoom: 1.48, panX: 0, yaw: 25, pitch: -12, nodes: 5, metallic: 0.94, roughness: 0.1, detail: 0, transmission: 0, power: 110, keyAngle: 35, beam: 0.75, beamAngle: 20, density: 0.025, fill: 0.5, exposure: 0.3 } },
  { id: 'memory', name: 'Material memory', concept: 'An ivory membrane folded around empty space.', settings: { seed: 420793, scene: 5, rotation: -24, twist: 1.15, spread: 0.96, thickness: 0.07, zoom: 1.24, panX: 0.08, yaw: 32, pitch: -12, nodes: 3, roughness: 0.18, metallic: 0.88, detail: 0, power: 115, keyAngle: -45, fill: 0.42, beam: 0.3, density: 0.012, exposure: 0.3, palette: { background: [0.07, 0.005, 85], metal: [0.93, 0.016, 85], energy: [0.96, 0.023, 85] } } },
  { id: 'ignition', name: 'Before ignition', concept: 'A bronze eclipse with a molten edge.', settings: { seed: 361849, scene: 2, rotation: 35, zoom: 1.38, panX: 0, twist: -0.65, spread: 1.05, roughness: 0.15, metallic: 0.92, detail: 0, exposure: 0.15, contrast: 1.16, power: 110, keyAngle: -75, fill: 0.25, beam: 0.75, beamAngle: 20, density: 0.025, palette: { background: [0.075, 0.008, 40], metal: [0.84, 0.075, 55], energy: [0.94, 0.065, 55] } } },
  { id: 'selene', name: 'Selene', concept: 'A lunar relic emerging from a cold diagonal beam.', settings: { seed: 713021, scene: 7, rotation: 38, twist: 0.6, spread: 1.18, thickness: 0.11, zoom: 1.45, panX: 0.1, panY: -0.04, yaw: -18, pitch: 8, nodes: 3, roughness: 0.08, metallic: 0.98, detail: 0, power: 125, keyAngle: 45, fill: 0.12, beam: 0.95, beamAngle: 16, density: 0.038, anisotropy: 0.45, exposure: 0.3, contrast: 1.24, bloom: 0.13, bloomRadius: 8, palette: { background: [0.16, 0.025, 265], metal: [0.88, 0.02, 230], energy: [0.88, 0.1, 235] } } },
  { id: 'oracle', name: 'Oracle', concept: 'A suspended seed pod of interwoven crystal.', settings: { seed: 830117, scene: 8, rotation: -16, twist: 0.75, spread: 1.02, thickness: 0.12, zoom: 1.2, panX: 0, yaw: 32, pitch: -12, nodes: 4, roughness: 0.1, metallic: 0, detail: 0, transmission: 1, ior: 1.42, dispersion: 0.001, absorption: 0.12, power: 125, keyAngle: -35, fill: 0.6, beam: 0.4, density: 0.009, exposure: 0.5, palette: { background: [0.07, 0.006, 265], metal: [0.94, 0.012, 240], energy: [0.96, 0.025, 235] } } },
  { id: 'eidolon', name: 'Eidolon', concept: 'Black chrome folded around a blue-white void.', settings: { seed: 912403, scene: 5, rotation: 29, twist: -1.4, spread: 1.03, thickness: 0.06, zoom: 1.3, panX: -0.03, yaw: -35, pitch: 14, nodes: 5, roughness: 0.13, metallic: 0.97, detail: 0, power: 125, keyAngle: 70, fill: 0.25, beam: 0.8, beamAngle: 18, density: 0.025, exposure: 0.35, contrast: 1.18 } },
  { id: 'corona', name: 'Corona', concept: 'XorDev’s ORB-31, sculpted in polished silver.', settings: { seed: 310031, scene: 9, rotation: -18, twist: 0, spread: 1, thickness: 0.086, zoom: 1.1, panX: 0, panY: 0, yaw: -18, pitch: 12, nodes: 3, holeWarp: 0.9, holeFrequency: 5.25, holeSoftness: 0.42, perforation: 0, roughness: 0.14, metallic: 0.78, detail: 0, transmission: 0, ior: 1.46, dispersion: 0, absorption: 0.28, power: 110, radius: 0.06, keyAngle: -25, fill: 0.7, beam: 0.2, beamAngle: 42, density: 0.012, anisotropy: 0.2, turbulence: 0.85, exposure: 0.65, contrast: 1.08, bloom: 0.075, bloomRadius: 4, grain: 0.005, vignette: 0.2, palette: { background: [0.075, 0.012, 250], metal: [0.92, 0.016, 218], energy: [0.96, 0.03, 220] } } },
];
export function preset(id: string): Settings {
  const p = PRESETS.find((entry) => entry.id === id);
  if (!p) throw new Error('Unknown preset.');
  return validateSettings({ ...DEFAULT, ...p.settings });
}
export function validateSettings(value: unknown): Settings {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Invalid scene settings.');
  const input = value as Record<string, unknown>;
  const numbers = {} as Record<NumericKey, number>;
  for (const key of Object.keys(RANGES) as NumericKey[]) {
    const range = RANGES[key];
    const v = input[key];
    if (typeof v !== 'number' || !Number.isFinite(v) || v < range[0] || v > range[1]) throw new Error(`Invalid ${key}: expected ${range[0]} to ${range[1]}.`);
    if (range[2] === 1 && !Number.isInteger(v)) throw new Error(`${key} must be a whole number.`);
    numbers[key] = v;
  }
  const palette = input.palette;
  if (!palette || typeof palette !== 'object' || Array.isArray(palette)) throw new Error('Invalid OKLCH palette.');
  const result = {} as Palette;
  for (const key of ['background', 'metal', 'energy'] as const) {
    const color = (palette as Record<string, unknown>)[key];
    if (!Array.isArray(color) || color.length !== 3 || !color.every(v => typeof v === 'number' && Number.isFinite(v)) || color[0] < 0 || color[0] > 1 || color[1] < 0 || color[1] > 0.4 || color[2] < 0 || color[2] > 360) throw new Error(`Invalid OKLCH ${key} color.`);
    result[key] = [color[0], color[1], color[2]];
  }
  return { ...numbers, palette: result };
}
export function documentFor(settings: Settings, shaderHash = 'unverified'): Recipe {
  return { format: 'hyalos-visual', version: 1, engine: ENGINE, shaderHash, settings: validateSettings(settings) };
}
export function parseDocument(input: unknown): Recipe {
  if (typeof input !== 'string') throw new Error('Project metadata must be text.');
  if (input.length > 65536) throw new Error('Project metadata is too large.');
  const data: unknown = JSON.parse(input);
  if (!data || typeof data !== 'object') throw new Error('Unsupported project version.');
  const value = data as Record<string, unknown>;
  if (value.format !== 'hyalos-visual' || value.version !== 1 || value.engine !== ENGINE || typeof value.shaderHash !== 'string' || value.shaderHash.length > 128) throw new Error('Unsupported project version.');
  let settings = value.settings;
  if (settings && typeof settings === 'object' && !Array.isArray(settings) && !Object.hasOwn(settings, 'emitter')) {
    settings = { ...settings, emitter: 1 };
  }
  // Only the complete pre-glass schema is migrated. Partial optics remain invalid.
  if (settings && typeof settings === 'object' && !Array.isArray(settings)
    && !Object.hasOwn(settings, 'transmission') && !Object.hasOwn(settings, 'ior')
    && !Object.hasOwn(settings, 'dispersion') && !Object.hasOwn(settings, 'absorption')) {
    settings = { ...settings, transmission: 0, ior: 1.5, dispersion: 0.008, absorption: 0.35 };
  }
  // Recipes predating edge sampling use four deterministic rays per pixel.
  if (settings && typeof settings === 'object' && !Array.isArray(settings) && !Object.hasOwn(settings, 'sampleGrid')) {
    settings = { ...settings, sampleGrid: 2 };
  }
  // Only recipes with neither beam field predate the spotlight. Preserve their isotropic light.
  if (settings && typeof settings === 'object' && !Array.isArray(settings)
    && !Object.hasOwn(settings, 'beam') && !Object.hasOwn(settings, 'beamAngle')) {
    settings = { ...settings, beam: 0, beamAngle: 26 };
  }
  // Only the complete pre-perforation schema migrates; partial hole settings are invalid.
  if (settings && typeof settings === 'object' && !Array.isArray(settings)
    && !Object.hasOwn(settings, 'holeWarp') && !Object.hasOwn(settings, 'holeFrequency')
    && !Object.hasOwn(settings, 'holeSoftness') && !Object.hasOwn(settings, 'perforation')) {
    settings = { ...settings, holeWarp: 0.9, holeFrequency: 5.25, holeSoftness: 0.42, perforation: 0 };
  }
  return documentFor(validateSettings(settings), value.shaderHash);
}
export function nextSeed(seed: number): number {
  // Integer permutation, independent of wall time and Math.random().
  let x = (seed + 0x9e3779b9) >>> 0;
  x = Math.imul(x ^ (x >>> 16), 0x21f0aaad);
  x = Math.imul(x ^ (x >>> 15), 0x735a2d97);
  return (x ^ (x >>> 15)) & 0xffffff;
}
export function loopPhase(time: number, duration: number): number { return ((time % duration) / duration) * Math.PI * 2; }
export function validateExport(width: number, height: number): void {
  if (![width, height].every(Number.isSafeInteger) || width < 64 || height < 64 || width > 8192 || height > 8192 || width * height > 33554432) throw new Error('Use 64 to 8192 pixels per side, up to 33.5 megapixels.');
}
export function* exportTiles(width: number, height: number, tileSize = 1024, halo = 64): Generator<ExportTile> {
  validateExport(width, height);
  if (!Number.isSafeInteger(tileSize) || tileSize < 32 || !Number.isSafeInteger(halo) || halo < 0 || halo > 1024) throw new Error('Invalid tile geometry.');
  for (let y = 0; y < height; y += tileSize) for (let x = 0; x < width; x += tileSize) {
    const w = Math.min(tileSize, width - x), h = Math.min(tileSize, height - y);
    const left = Math.max(0, x - halo), top = Math.max(0, y - halo);
    const right = Math.min(width, x + w + halo), bottom = Math.min(height, y + h + halo);
    yield { x, y, w, h, left, top, width: right - left, height: bottom - top };
  }
}
export class History {
  past: Settings[] = [];
  future: Settings[] = [];
  current: Settings;
  constructor(settings: Settings) { this.past = []; this.future = []; this.current = structuredClone(settings); }
  commit(settings: Settings) {
    if (JSON.stringify(this.current) === JSON.stringify(settings)) return;
    this.past.push(this.current); if (this.past.length > 80) this.past.shift();
    this.current = structuredClone(settings); this.future = [];
  }
  undo() { if (!this.past.length) return structuredClone(this.current); this.future.push(this.current); this.current = this.past.pop()!; return structuredClone(this.current); }
  redo() { if (!this.future.length) return structuredClone(this.current); this.past.push(this.current); this.current = this.future.pop()!; return structuredClone(this.current); }
}
