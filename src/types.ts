export type Oklch = [number, number, number];
export type Vec4 = [number, number, number, number];
export type ColorRole = 'background' | 'metal' | 'energy';
export type Palette = Record<ColorRole, Oklch>;
export type Quality = 'draft' | 'balanced' | 'final';
export type Tab = 'form' | 'light' | 'finish';
export type NumericKey = keyof typeof import('./model.ts').RANGES;
export type Settings = Record<NumericKey, number> & { palette: Palette };
export interface Recipe {
  format: 'hyalos-visual';
  version: 1;
  engine: string;
  shaderHash: string;
  settings: Settings;
}
export interface Study {
  id: string;
  name: string;
  concept: string;
  settings: Partial<Settings>;
}
export interface TileRegion { left: number; top: number; width: number; height: number }
export interface ExportTile extends TileRegion { x: number; y: number; w: number; h: number }
export interface PixelRenderer {
  readonly hash: string;
  readonly maxTexture: number;
  readTile(settings: Settings, width: number, height: number, tile: TileRegion, quality?: Quality): Promise<Uint8Array>;
}
export interface Renderer extends PixelRenderer {
  drawPreview(settings: Settings, width: number, height: number, quality?: Quality): void;
  settled(): Promise<void>;
  dispose(): void;
}
export type ImageFormat = 'image/png' | 'image/webp' | 'image/jpeg';
export interface RenderOptions {
  signal?: AbortSignal;
  onProgress?: (progress: number) => void;
  tileSize?: number;
  quality?: Quality;
}
export interface Capabilities {
  webgpu: boolean;
  renderer: 'vgpu';
  shaderHash: string | null;
  maxImagePixels: number;
  previewQuality: Quality;
  exporting: boolean;
}
export interface HyalosAPI {
  readonly ready: Promise<boolean>;
  getScene(): Recipe;
  setScene(recipe: unknown): void;
  setParameters(patch: Partial<Settings>): void;
  exportPNG(width?: number, height?: number): Promise<Blob>;
  capabilities(): Capabilities;
}
