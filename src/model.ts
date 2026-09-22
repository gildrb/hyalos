import type { Settings, Study, Palette, NumericKey, Recipe, ExportTile } from './types.ts';
/** All authored color values are OKLCH: lightness 0..1, chroma, hue in degrees. */
export const ENGINE = 'hyalos-prometheus/1';
export const STORAGE_KEY = 'hyalos.visuals.v1';
export const SCENES = ['Prometheus', 'Commons', 'Hearth', 'Relay'];
export const FINISHES = ['Optical', 'Dot matrix', 'Ordered dither', 'Phosphor'];
export const PALETTES: Record<string, Palette> = {
  'Cold fire': { background: [0.115, 0.018, 270], metal: [0.79, 0.022, 240], energy: [0.84, 0.10, 235] },
  'Ivory': { background: [0.10, 0.008, 85], metal: [0.80, 0.026, 83], energy: [0.91, 0.06, 88] },
  'Ember': { background: [0.12, 0.018, 40], metal: [0.64, 0.08, 53], energy: [0.82, 0.13, 65] },
  'Ion': { background: [0.10, 0.016, 300], metal: [0.72, 0.045, 280], energy: [0.79, 0.12, 290] },
  'Silver': { background: [0.09, 0, 0], metal: [0.78, 0, 0], energy: [0.93, 0, 0] },
};
// [minimum, maximum, step]. Used by UI, import validation, and tests.
export const RANGES = {
  seed: [0, 16777215, 1], scene: [0, 3, 1], finish: [0, 3, 1],
  rotation: [-180, 180, 1], twist: [-2, 2, 0.01], spread: [0.5, 1.8, 0.01],
  thickness: [0.015, 0.16, 0.001], zoom: [0.65, 2, 0.01], panX: [-1.8, 1.8, 0.01], panY: [-1.8, 1.8, 0.01],
  yaw: [-55, 55, 1], pitch: [-40, 40, 1], nodes: [3, 9, 1],
  roughness: [0.06, 0.8, 0.01], metallic: [0, 1, 0.01], detail: [0, 0.35, 0.005],
  power: [0, 160, 1], radius: [0.06, 0.35, 0.005], keyAngle: [-180, 180, 1], fill: [0, 1, 0.01],
  density: [0, 1, 0.01], anisotropy: [-0.6, 0.8, 0.01], turbulence: [0.3, 3, 0.01],
  exposure: [-3, 3, 0.05], contrast: [0.7, 2, 0.01], bloom: [0, 0.65, 0.01], bloomRadius: [1, 18, 0.5],
  grain: [0, 0.12, 0.001], vignette: [0, 0.6, 0.01], spacing: [3, 20, 0.25], dotSize: [0.15, 0.49, 0.01],
  dither: [0, 1, 0.01], time: [0, 60, 0.001], duration: [2, 60, 1],
};
export const DEFAULT: Settings = {
  seed: 240915, scene: 0, finish: 0, rotation: 38, twist: 0.7, spread: 1.28,
  thickness: 0.095, zoom: 1.18, panX: 0.08, panY: 0, yaw: -8, pitch: 0, nodes: 5,
  roughness: 0.38, metallic: 0.7, detail: 0.055,
  power: 95, radius: 0.12, keyAngle: -35, fill: 0.7,
  density: 0.52, anisotropy: 0.35, turbulence: 1.15,
  exposure: 0.5, contrast: 1.05, bloom: 0.3, bloomRadius: 7,
  grain: 0.026, vignette: 0.24, spacing: 7, dotSize: 0.35, dither: 1,
  time: 0, duration: 12, palette: structuredClone(PALETTES['Cold fire']),
};
export const PRESETS: readonly Study[] = [
  { id: 'the-gift', name: 'The gift', concept: 'Knowledge, carried into reach.', settings: {} },
  { id: 'commons', name: 'The commons', concept: 'No centre. Many sources.', settings: { scene: 1, rotation: 12, spread: 1.12, zoom: 1.12, density: 0.25, nodes: 7, power: 62, yaw: 18, thickness: 0.042 } },
  { id: 'hearth', name: 'An inner fire', concept: 'Intelligence held close.', settings: { scene: 2, rotation: -25, twist: 0.25, zoom: 1.08, density: 0.24, radius: 0.12, power: 44, yaw: -12, roughness: 0.19, nodes: 3 } },
  { id: 'relay', name: 'A shared signal', concept: 'Each source lights another.', settings: { scene: 3, rotation: -52, spread: 1.13, twist: 0.4, power: 58, nodes: 4, density: 0.2, zoom: 0.95 } },
  { id: 'memory', name: 'Material memory', concept: 'A continuous idea, discretised.', settings: { scene: 0, finish: 1, rotation: -8, twist: 1.45, zoom: 1.45, panX: 0.6, exposure: 0.35, contrast: 1.35, spacing: 7.5, dotSize: 0.30, palette: PALETTES.Ivory, grain: 0.012 } },
  { id: 'ignition', name: 'Before ignition', concept: 'Potential before the first spark.', settings: { scene: 2, finish: 2, rotation: 28, zoom: 1.2, twist: -0.4, exposure: 0.25, dither: 0.85, spacing: 3, power: 80, palette: PALETTES.Ember } },
];
export function preset(id: string): Settings {
  const p = PRESETS.find((entry) => entry.id === id);
  if (!p) throw new Error('Unknown preset.');
  return { ...structuredClone(DEFAULT), ...structuredClone(p.settings) };
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
  return documentFor(validateSettings(value.settings), value.shaderHash);
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
