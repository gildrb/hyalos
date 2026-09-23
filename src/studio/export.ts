import { frame, target, type Gpu } from 'vgpu';
import { validateExport } from '../model.ts';
import type { SculptureRecipe } from './model.ts';
import { createScene, type SculptureScene } from './scene.ts';

/** The browser and native export utility use the same overlapped GPU tiles. */
export async function renderSculpturePixels(
  gpu: Gpu,
  recipe: SculptureRecipe,
  progress: (value: number) => void = () => {},
  cancelled: () => boolean = () => false,
): Promise<Uint8ClampedArray> {
  const width = recipe.controls.exportWidth, height = recipe.controls.exportHeight;
  validateExport(width, height);
  const output = target(gpu, { size: [1, 1], format: 'rgba8unorm', label: 'glass-sculpture-export' });
  let scene: SculptureScene | undefined;
  try {
    const controls = { ...recipe.controls, renderScale: 1 as const };
    scene = createScene(gpu, output, controls, recipe.orbSnapshot, 1024);
    await scene.prepare(output);
    const pixels = new Uint8ClampedArray(width * height * 4);
    // Core + wide separable blur support is 72 full-resolution pixels per spread unit.
    // Round to a multiple of four so downsample grids stay aligned between tiles.
    const tileSize = 512, halo = Math.ceil((72*controls.glowRadius+8)/4)*4;
    const total = Math.ceil(width / tileSize) * Math.ceil(height / tileSize);
    let completed = 0;
    for (let y = 0; y < height; y += tileSize) {
      for (let x = 0; x < width; x += tileSize) {
        if (cancelled()) throw new Error('Export cancelled.');
        const left = Math.max(0, x - halo), top = Math.max(0, y - halo);
        const right = Math.min(width, x + tileSize + halo), bottom = Math.min(height, y + tileSize + halo);
        const tileWidth = right - left, tileHeight = bottom - top;
        output.resize([tileWidth, tileHeight]);
        scene.resize([tileWidth, tileHeight], 1);
        frame(gpu, current => scene!.render(current, output, recipe.camera, controls, {
          ...recipe, deltaTime: 0, renderMaterial: completed===0, region: { origin: [left, top], fullSize: [width, height] },
        }));
        await gpu.gpu.queue.onSubmittedWorkDone();
        await gpu.settled();
        const tile = new Uint8Array(await output.color.read({ mipLevel: 0, region: 'all' }));
        const copyWidth = Math.min(tileSize, width - x), copyHeight = Math.min(tileSize, height - y);
        for (let row = 0; row < copyHeight; row++) {
          const start = ((y - top + row) * tileWidth + x - left) * 4;
          pixels.set(tile.subarray(start, start + copyWidth * 4), ((y + row) * width + x) * 4);
        }
        progress(++completed / total);
        await new Promise(resolve => setTimeout(resolve, 0));
      }
    }
    if (cancelled()) throw new Error('Export cancelled.');
    return pixels;
  } finally {
    scene?.destroy();
    (output as typeof output & { destroy(): void }).destroy();
  }
}
