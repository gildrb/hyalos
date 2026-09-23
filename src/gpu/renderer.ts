import type { Effect, Gpu, Surface, Target } from 'vgpu';
import type { Renderer, RendererInitOptions, Settings, TileRegion, Quality } from '../types.ts';
import { init, effect, frame, surface, target, texture, sampler, storage } from 'vgpu';
import { sceneShader, POST_SHADER, shaderFingerprint } from './shaders.ts';
import { uniforms } from './uniforms.ts';
import { DEFAULT } from '../model.ts';

/** One vGPU context, persistent pipelines, reusable HDR targets. No WebGL fallback. */
export async function createRenderer(canvas: HTMLCanvasElement | null, onError: (error: unknown) => void = console.error, options: RendererInitOptions & { gpu?: Gpu } = {}): Promise<Renderer> {
  const { signal, onPhase } = options;
  signal?.throwIfAborted();
  onPhase?.('loading');
  signal?.throwIfAborted();
  if (!options.gpu && !globalThis.isSecureContext) throw new Error('WebGPU needs HTTPS or localhost. An HTTP Tailnet address is not sufficient.');
  if (!options.gpu && !navigator.gpu) throw new Error('WebGPU is not available in this browser. Use a WebGPU-capable browser with hardware acceleration enabled.');
  const gpu = options.gpu ?? await init({ powerPreference: 'low-power' });
  // Device acquisition is not cancellable in vGPU/WebGPU. Release a late device
  // before it can acquire the canvas or create any renderer resources.
  if (signal?.aborted) { gpu.dispose(); signal.throwIfAborted(); }
  let failure: Error | null = null;
  const reportError = (error: Error): void => { failure ??= error; onError(error); };
  const unsubscribeLibrary = gpu.onError(reportError);
  // vGPU's error channel covers its own validation, not native queue failures.
  const reportNativeError = (event: GPUUncapturedErrorEvent): void => reportError(new Error(`WebGPU: ${event.error.message}`));
  gpu.gpu.addEventListener('uncapturederror', reportNativeError);
  const unsubscribe = (): void => {
    unsubscribeLibrary();
    gpu.gpu.removeEventListener('uncapturederror', reportNativeError);
  };
  let disposed = false;
  const lifetime = new AbortController();
  let ownedSurface: Surface | null = null;
  const dispose = (): void => {
    if (disposed) return;
    disposed = true;
    lifetime.abort();
    signal?.removeEventListener('abort', dispose);
    unsubscribe();
    ownedSurface?.dispose();
    gpu.dispose();
  };
  signal?.addEventListener('abort', dispose, { once: true });
  gpu.gpu.lost.then((info) => { if (!disposed) reportError(new Error(`GPU device lost: ${info.message}. Reconnect to retry.`)); });
  try {
    signal?.throwIfAborted();
    onPhase?.('compiling');
    signal?.throwIfAborted();
    const screen = canvas ? surface(gpu, canvas, { autoResize: false, dpr: 1, size: [320, 180], alphaMode: 'opaque', colorSpace: 'srgb' }) : target(gpu, { size: [320, 180], format: 'rgba8unorm' });
    if (canvas) ownedSurface = screen as Surface;
    // Independent small attachments bound scene work without relying on scissors.
    const chunk = target(gpu, { size: [128, 128], format: 'rgba16float', label: 'scene-chunk' });
    const sampleSums = storage(gpu, 128 * 128 * 16, 'read-write');
    let hdr = texture(gpu, { kind: '2d', size: [320, 180], format: 'rgba16float', usage: ['texture_binding', 'copy_dst'], label: 'scene-radiance' });
    const output = target(gpu, { size: [1, 1], format: 'rgba8unorm', label: 'export-display' });
    const linearSampler = sampler(gpu, { minFilter: 'linear', magFilter: 'linear', addressModeU: 'clamp-to-edge', addressModeV: 'clamp-to-edge' });
    const initial = uniforms(DEFAULT, 320, 180, { left: 0, top: 0, width: 320, height: 180 });
    const scenes = new Map<string, Effect>();
    // Assemble exact HDR texels before the one full-tile optical pass.
    const post = effect(gpu, POST_SHADER, { label: 'optics-and-print', set: { u: initial, sceneTex: hdr, linearSampler } });
    // First image needs only the scene and canvas signatures. Export prewarming
    // stays on the export path instead of holding the first live frame hostage.
    const [hash] = await Promise.all([shaderFingerprint(), post.compile({ colors: [screen.format], sampleCount: 1 })]);
    signal?.throwIfAborted();
    assertUsable();
    let exportCompiled = false;
    function assertUsable(): void {
      if (failure) throw failure;
      if (disposed) throw new Error('Renderer has been disposed.');
    }
    async function settled(): Promise<void> {
      assertUsable();
      await gpu.gpu.queue.onSubmittedWorkDone();
      await gpu.settled();
      assertUsable();
    }
    let nextChunkAt = 0;
    function rest(milliseconds: number, signal?: AbortSignal): Promise<void> {
      // The project's ES2022 runtime/lib does not include Promise.withResolvers.
      return new Promise((resolve) => {
        const finish = (): void => {
          clearTimeout(timer);
          signal?.removeEventListener('abort', finish);
          lifetime.signal.removeEventListener('abort', finish);
          resolve();
        };
        const timer = setTimeout(finish, milliseconds);
        signal?.addEventListener('abort', finish, { once: true });
        lifetime.signal.addEventListener('abort', finish, { once: true });
        if (signal?.aborted || disposed) finish();
      });
    }
    async function draw(s: Settings, w: number, h: number, tile: TileRegion, destination: Target, quality: Quality, signal?: AbortSignal): Promise<void> {
      const cancelled = (): boolean => disposed || !!signal?.aborted || (canvas !== null && destination === screen && document.hidden);
      if (cancelled()) return;
      try {
        assertUsable();
        const transmissive = s.transmission * (1 - s.metallic) > 0;
        const key = `${s.scene}:${transmissive}`;
        let scene = scenes.get(key);
        if (!scene) {
          scene = effect(gpu, sceneShader(s.scene, transmissive), { label: `scene-${key}`, set: { u: initial, sampleSums } });
          scenes.set(key, scene);
          await scene.compile(chunk);
          if (cancelled()) return;
        }
        const { width, height } = tile;
        if (width > gpu.gpu.limits.maxTextureDimension2D || height > gpu.gpu.limits.maxTextureDimension2D) throw new Error('Requested tile exceeds GPU texture limits.');
        if (hdr.size[0] !== width || hdr.size[1] !== height) {
          const previous = hdr;
          hdr = texture(gpu, { kind: '2d', size: [width, height], format: 'rgba16float', usage: ['texture_binding', 'copy_dst'], label: 'scene-radiance' });
          post.set({ sceneTex: hdr });
          previous.destroy();
        }
        // Capture settings before yielding. Post keeps the complete tile origin;
        // scene chunks use local targets with the same exact global pixel centers.
        const u = uniforms(s, w, h, tile, quality);
        post.set({ u });
        // Each submission traces one primary sample per pixel. Dispersion only
        // triples work on the active glass path; opaque recipes may retain its value.
        const grid = quality === 'draft' ? 1 : s.sampleGrid;
        const sampleCount = grid * grid;
        let chunkSide = 128;
        if (s.transmission * (1 - s.metallic) > 0) {
          chunkSide /= 2;
          if (s.dispersion > 0) chunkSide /= 2;
        }
        const sceneUniforms = { ...u, tile: [tile.left, tile.top, chunkSide, chunkSide], emit: [...u.emit] };
        // Cancellation ends the old promise promptly, but does not erase GPU rest
        // owed before a replacement preview or export uses the shared context.
        const remainingRest = nextChunkAt - performance.now();
        if (remainingRest > 0) await rest(remainingRest, signal);
        // No scene neighbors are sampled: only the final optical pass needs the
        // export tile's halo. Every HDR texel is copied once before it is sampled.
        for (let y = 0; y < height; y += chunkSide) {
          for (let x = 0; x < width; x += chunkSide) {
            if (cancelled()) return;
            assertUsable();
            const chunkWidth = Math.min(chunkSide, width - x), chunkHeight = Math.min(chunkSide, height - y);
            chunk.resize([chunkWidth, chunkHeight]);
            sceneUniforms.tile[0] = tile.left + x; sceneUniforms.tile[1] = tile.top + y;
            sceneUniforms.tile[2] = chunkWidth; sceneUniforms.tile[3] = chunkHeight;
            for (let sampleIndex = 0; sampleIndex < sampleCount; sampleIndex++) {
              if (cancelled()) return;
              assertUsable();
              sceneUniforms.emit[1] = sampleIndex;
              scene.set({ u: sceneUniforms });
              const started = performance.now();
              frame(gpu, (f) => f.pass(chunk, scene!));
              if (sampleIndex === sampleCount - 1) {
                // OffscreenTarget textures lack COPY_DST in vGPU 0.5; the assembled
                // sampled texture above explicitly supports native exact texel copies.
                const copy = gpu.gpu.createCommandEncoder({ label: 'assemble-radiance' });
                copy.copyTextureToTexture({ texture: chunk.color.gpu }, { texture: hdr.gpu, origin: { x, y } }, { width: chunkWidth, height: chunkHeight });
                gpu.gpu.queue.submit([copy.finish()]);
              }
              // Drain every sample, then yield a macrotask with real idle time. Do not
              // cap the rest below slow sample cost. This is wall time, not a GPU query.
              await settled();
              const finished = performance.now();
              const delay = Math.max(4, (finished - started) * 2);
              nextChunkAt = finished + delay;
              if (cancelled()) return;
              await rest(delay, signal);
            }
          }
        }
        if (cancelled()) return;
        assertUsable();
        // Resizing a surface clears it: retain the previous preview until complete.
        destination.resize([width, height]);
        frame(gpu, (f) => f.pass(destination, post));
        await settled();
      } catch (error) {
        // Device teardown may reject an in-flight wait; it is not a preview failure.
        if (!disposed) throw error;
      }
    }
    return {
      hash,
      maxTexture: gpu.gpu.limits.maxTextureDimension2D,
      drawPreview(s, width, height, quality = 'balanced', signal) {
        return draw(s, width, height, { left: 0, top: 0, width, height }, screen, quality, signal);
      },
      async readTile(s, width, height, tile, quality = 'final', signal) {
        signal?.throwIfAborted();
        assertUsable();
        if (!exportCompiled) {
          await post.compile(output);
          signal?.throwIfAborted();
          assertUsable();
          exportCompiled = true;
        }
        await draw(s, width, height, tile, output, quality, signal);
        signal?.throwIfAborted();
        assertUsable();
        // The library removes row padding and returns RGBA byte order.
        const data = await output.color.read({ mipLevel: 0, region: 'all' });
        signal?.throwIfAborted();
        assertUsable();
        // Post writes alpha 1 everywhere. Do not export incomplete native submissions.
        for (let i = 3; i < data.length; i += 4) {
          if (data[i] !== 255) {
            const error = new Error(`Invalid GPU output: expected opaque pixels, received alpha ${data[i]} at pixel ${(i - 3) / 4}. Rendering stopped; reconnect to retry.`);
            reportError(error);
            throw error;
          }
        }
        return data;
      },
      settled,
      dispose,
    };
  } catch (error) { dispose(); throw error; }
}
