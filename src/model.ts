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
  power: [0, 160, 1], radius: [0.06, 0.35, 0.005], keyAngle: [-180, 180, 1], fill: [0, 1, 0.01],
  beam: [0, 1, 0.01], beamAngle: [8, 60, 1],
  density: [0, 1, 0.01], anisotropy: [-0.6, 0.8, 0.01], turbulence: [0.3, 3, 0.01],
  exposure: [-3, 3, 0.05], contrast: [0.7, 2, 0.01], bloom: [0, 0.65, 0.01], bloomRadius: [1, 18, 0.5],
  grain: [0, 0.12, 0.001], vignette: [0, 0.6, 0.01], spacing: [3, 20, 0.25], dotSize: [0.15, 0.49, 0.01],
  dither: [0, 1, 0.01], sampleGrid: [1, 3, 1], time: [0, 60, 0.001], duration: [2, 60, 1],
};
export const DEFAULT: Settings = {
  seed: 240915, scene: 0, finish: 3, rotation: 43, twist: 0.88, spread: 1.26,
  thickness: 0.086, zoom: 1.16, panX: 0.04, panY: 0, yaw: -14, pitch: 6, nodes: 5,
  holeWarp: 0.9, holeFrequency: 5.25, holeSoftness: 0.42, perforation: 0,
  roughness: 0.3, metallic: 0.82, detail: 0.06,
  transmission: 0, ior: 1.5, dispersion: 0.004, absorption: 0.35,
  power: 55, radius: 0.12, keyAngle: -150, fill: 0.25, beam: 0.65, beamAngle: 26,
  density: 0.13, anisotropy: 0.3, turbulence: 0.85,
  exposure: -0.45, contrast: 1.18, bloom: 0.2, bloomRadius: 7,
  grain: 0.018, vignette: 0.24, spacing: 3.5, dotSize: 0.35, dither: 1, sampleGrid: 2,
  time: 0, duration: 12, palette: PALETTES.Nocturne,
};
export const PRESETS: readonly Study[] = [
  { id: 'the-gift', name: 'The gift', concept: 'A cyan relic, held between shadow and light.', settings: {} },
  { id: 'commons', name: 'The commons', concept: 'Cold glass carrying a shared light.', settings: { scene: 1, finish: 0, rotation: 24, twist: 0.3, spread: 1.12, zoom: 1.02, panX: 0, yaw: 20, pitch: -12, thickness: 0.07, nodes: 7, metallic: 0.02, roughness: 0.16, detail: 0.015, transmission: 0.92, ior: 1.46, dispersion: 0.004, absorption: 0.6, density: 0.07, anisotropy: 0.25, power: 48, radius: 0.14, keyAngle: 125, fill: 0.36, beam: 0.42, beamAngle: 34, grain: 0.014, bloom: 0.16, exposure: -0.25, contrast: 1.1, palette: PALETTES.Nocturne } },
  { id: 'hearth', name: 'An inner fire', concept: 'An amber knot, warm as a distant practical.', settings: { scene: 4, finish: 0, rotation: -28, twist: 0.45, spread: 1.05, thickness: 0.12, zoom: 1.04, panX: 0, yaw: -16, pitch: 10, nodes: 3, metallic: 0, roughness: 0.18, detail: 0.015, transmission: 0.88, ior: 1.52, dispersion: 0.005, absorption: 0.85, density: 0.06, anisotropy: 0.2, radius: 0.15, power: 46, keyAngle: -110, fill: 0.3, beam: 0.5, beamAngle: 34, bloom: 0.18, bloomRadius: 8, grain: 0.016, exposure: -0.25, contrast: 1.15, palette: PALETTES.Patina } },
  { id: 'relay', name: 'A shared signal', concept: 'Violet glass suspended in quiet smoke.', settings: { scene: 6, finish: 0, rotation: -38, spread: 1.24, twist: -0.25, thickness: 0.11, zoom: 1.02, panX: 0, yaw: 14, pitch: -8, nodes: 5, metallic: 0.04, roughness: 0.23, detail: 0.02, transmission: 0.68, ior: 1.4, dispersion: 0.003, absorption: 1.1, power: 44, radius: 0.16, keyAngle: 145, beam: 0.7, beamAngle: 36, density: 0.18, anisotropy: 0.35, turbulence: 0.65, fill: 0.26, exposure: -0.4, contrast: 1.16, bloom: 0.18, grain: 0.02, palette: { background: [0.065, 0.009, 290], metal: [0.64, 0.035, 295], energy: [0.75, 0.075, 290] } } },
  { id: 'memory', name: 'Material memory', concept: 'Ivory engraved out of the dark.', settings: { scene: 0, finish: 1, rotation: -8, twist: 1.45, spread: 1.12, zoom: 1.16, panX: 0.15, yaw: 8, pitch: -6, roughness: 0.42, metallic: 0.72, detail: 0.09, power: 64, keyAngle: -25, fill: 0.35, beam: 0.15, beamAngle: 40, density: 0.035, exposure: 0.1, contrast: 1.3, bloom: 0.08, bloomRadius: 4, spacing: 6, dotSize: 0.33, palette: PALETTES.Ivory, grain: 0.012 } },
  { id: 'ignition', name: 'Before ignition', concept: 'A dim ember at the edge of visibility.', settings: { scene: 2, finish: 2, rotation: 28, zoom: 1.08, panX: 0, twist: -0.4, spread: 1.12, roughness: 0.48, metallic: 0.62, detail: 0.055, exposure: -0.65, contrast: 1.2, dither: 0.72, spacing: 3, power: 28, radius: 0.1, keyAngle: -95, fill: 0.16, beam: 0.3, beamAngle: 40, density: 0.075, anisotropy: 0.2, bloom: 0.12, bloomRadius: 5, grain: 0.024, palette: { background: [0.06, 0.008, 40], metal: [0.57, 0.055, 48], energy: [0.7, 0.095, 52] } } },
  { id: 'selene', name: 'Selene', concept: 'A crescent reliquary cutting a cold diagonal through darkness.', settings: { seed: 713021, scene: 7, finish: 0, rotation: 32, twist: 0.38, spread: 1.12, thickness: 0.078, zoom: 1.6, panX: 0.05, panY: -0.02, yaw: -12, pitch: 5, nodes: 3, roughness: 0.25, metallic: 0.72, detail: 0.035, power: 95, radius: 0.09, keyAngle: -55, fill: 0.28, beam: 0.62, beamAngle: 30, density: 0.055, anisotropy: 0.38, turbulence: 0.7, exposure: -0.1, contrast: 1.24, bloom: 0.15, bloomRadius: 7, grain: 0.021, vignette: 0.28, palette: { background: [0.045, 0.008, 245], metal: [0.8, 0.018, 220], energy: [0.9, 0.075, 220] } } },
  { id: 'oracle', name: 'Oracle', concept: 'An ivory vault of folded arches, punctured by a silent void.', settings: { seed: 830117, scene: 8, finish: 1, rotation: -7, twist: 0.48, spread: 1.05, thickness: 0.095, zoom: 1.18, panX: 0.02, panY: 0.03, yaw: 22, pitch: -7, nodes: 5, roughness: 0.46, metallic: 0.54, detail: 0.085, power: 58, radius: 0.075, keyAngle: -32, fill: 0.17, beam: 0.12, beamAngle: 42, density: 0.018, anisotropy: 0.2, turbulence: 0.9, exposure: -0.05, contrast: 1.3, bloom: 0.065, bloomRadius: 3.5, grain: 0.014, vignette: 0.25, spacing: 6.5, dotSize: 0.32, palette: { background: [0.038, 0.004, 85], metal: [0.83, 0.026, 85], energy: [0.93, 0.045, 88] } } },
  { id: 'eidolon', name: 'Eidolon', concept: 'A blue-black sanctuary, its hollow held in luminous memory.', settings: { seed: 912403, scene: 8, finish: 2, rotation: 13, twist: -0.55, spread: 1.13, thickness: 0.069, zoom: 1.13, panX: -0.06, panY: -0.02, yaw: -26, pitch: 8, nodes: 3, roughness: 0.32, metallic: 0.64, detail: 0.07, power: 60, radius: 0.13, keyAngle: 80, fill: 0.3, beam: 0.52, beamAngle: 34, density: 0.06, anisotropy: 0.35, turbulence: 0.62, exposure: 0, contrast: 1.21, bloom: 0.18, bloomRadius: 10, grain: 0.032, vignette: 0.32, spacing: 3, dither: 0.3, palette: { background: [0.042, 0.009, 252], metal: [0.66, 0.034, 242], energy: [0.79, 0.083, 232] } } },
  { id: 'corona', name: 'Corona', concept: 'A silver-cyan shell, opened by XorDev’s ORB-31 warped-volume subtraction.', settings: { seed: 310031, scene: 9, finish: 0, rotation: -18, twist: 0, spread: 1, thickness: 0.086, zoom: 1.1, panX: 0, panY: 0, yaw: -18, pitch: 12, nodes: 3, holeWarp: 0.9, holeFrequency: 5.25, holeSoftness: 0.42, perforation: 0, roughness: 0.3, metallic: 0.25, detail: 0, transmission: 0, ior: 1.46, dispersion: 0, absorption: 0.28, power: 110, radius: 0.06, keyAngle: -25, fill: 0.7, beam: 0.2, beamAngle: 42, density: 0.012, anisotropy: 0.2, turbulence: 0.85, exposure: 0.65, contrast: 1.08, bloom: 0.075, bloomRadius: 4, grain: 0.012, vignette: 0.2, palette: { background: [0.045, 0.008, 240], metal: [0.92, 0.016, 218], energy: [0.93, 0.048, 220] } } },
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
