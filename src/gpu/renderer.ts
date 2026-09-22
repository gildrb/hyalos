import type { Target } from 'vgpu';
import type { Renderer, Settings, TileRegion, Quality } from '../types.ts';
import { init, effect, frame, surface, target, sampler } from 'vgpu';
import { SCENE_SHADER, POST_SHADER, shaderFingerprint } from './shaders.ts';
import { uniforms } from './uniforms.ts';
import { DEFAULT } from '../model.ts';

/** One vGPU context, persistent pipelines, reusable HDR targets. No WebGL fallback. */
export async function createRenderer(canvas: HTMLCanvasElement, onError: (error: unknown) => void = console.error): Promise<Renderer> {
  if (!globalThis.isSecureContext) throw new Error('WebGPU needs HTTPS or localhost. An HTTP Tailnet address is not sufficient.');
  if (!navigator.gpu) throw new Error('WebGPU is not available in this browser. Use a WebGPU-capable browser with hardware acceleration enabled.');
  const gpu = await init({ powerPreference: 'high-performance' });
  const unsubscribe = gpu.onError(onError);
  let disposed = false;
  gpu.gpu.lost.then((info) => { if (!disposed) onError(new Error(`GPU device lost: ${info.message}. Reload to reconnect.`)); });
  try {
    const screen = surface(gpu, canvas, { autoResize: false, dpr: 1, size: [640, 360], alphaMode: 'opaque', colorSpace: 'srgb' });
    const hdr = target(gpu, { size: [640, 360], format: 'rgba16float', label: 'scene-radiance' });
    const output = target(gpu, { size: [640, 360], format: 'rgba8unorm', label: 'export-display' });
    const linearSampler = sampler(gpu, { minFilter: 'linear', magFilter: 'linear', addressModeU: 'clamp-to-edge', addressModeV: 'clamp-to-edge' });
    const initial = uniforms(DEFAULT, 640, 360, { left: 0, top: 0, width: 640, height: 360 });
    const scene = effect(gpu, SCENE_SHADER, { label: 'promethean-radiance', set: { u: initial } });
    // Bind the Target, not hdr.color: vGPU tracks replacement textures on resize.
    const post = effect(gpu, POST_SHADER, { label: 'optics-and-print', set: { u: initial, sceneTex: hdr, linearSampler } });
    await Promise.all([scene.compile(hdr), post.compile({ colors: [screen.format], sampleCount: 1 }), post.compile(output)]);
    const hash = await shaderFingerprint();
    function draw(s: Settings, w: number, h: number, tile: TileRegion, destination: Target, quality: Quality) {
      if (disposed) throw new Error('Renderer has been disposed.');
      if (tile.width > gpu.gpu.limits.maxTextureDimension2D || tile.height > gpu.gpu.limits.maxTextureDimension2D) throw new Error('Requested tile exceeds GPU texture limits.');
      hdr.resize([tile.width, tile.height]);
      destination.resize([tile.width, tile.height]);
      const u = uniforms(s, w, h, tile, quality);
      scene.set({ u }); post.set({ u });
      frame(gpu, (f) => { f.pass(hdr, scene); f.pass(destination, post); });
    }
    return {
      hash,
      maxTexture: gpu.gpu.limits.maxTextureDimension2D,
      drawPreview(s, width, height, quality = 'balanced') {
        draw(s, width, height, { left: 0, top: 0, width, height }, screen, quality);
      },
      async readTile(s, width, height, tile, quality = 'final') {
        draw(s, width, height, tile, output, quality);
        // The library removes row padding and returns RGBA byte order.
        return output.color.read({ mipLevel: 0, region: 'all' });
      },
      async settled() { await gpu.gpu.queue.onSubmittedWorkDone(); await gpu.settled(); },
      dispose() { if (disposed) return; disposed = true; unsubscribe(); screen.dispose(); gpu.dispose(); },
    };
  } catch (error) { disposed = true; unsubscribe(); gpu.dispose(); throw error; }
}
