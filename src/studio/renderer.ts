import { ORB_SHADERS } from './orbs/shaders.ts';
// Based on vGPU Glass Sculpture, concept and visual design by Kazuyuki Chinda (@ckazu).
import { clock, frameLoop, init, surface, type Gpu } from 'vgpu';
import { installPointerInput } from './pointer-input.ts';
import { createScene, type SculptureScene } from './scene.ts';
import { normalizeControls, type SculptureControls } from './controls.ts';
import { initialSculpture, type SculptureRecipe } from './model.ts';
import { addPngProject } from '../binary.ts';
import { validateExport } from '../model.ts';
import { renderSculpturePixels } from './export.ts';
import { encodePixels } from '../export.ts';
import sculpture from './sculpture.wgsl?raw';
import extract from '../../glass-sculpture/bloom-extract.wgsl?raw';
import blur from '../../glass-sculpture/bloom-blur.wgsl?raw';
import present from './present.wgsl?raw';

export function createSculptureRenderer(canvas: HTMLCanvasElement, initial = initialSculpture(), onError: (error: unknown) => void = console.error) {
  let disposed = false, exporting = false, inFlight = false, exportCancelled = false;
  let preparingMaterial = false, materialRevision = 0;
  let gpu: Gpu | undefined;
  let exportGpu: Gpu | undefined;
  let input: ReturnType<typeof installPointerInput> | undefined;
  let activeScene: SculptureScene | undefined;
  let resizeScene = () => {};
  let state = structuredClone(initial);
  let controls = normalizeControls(initial.controls);
  let shaderHash = '';
  const cleanups: Array<() => void> = [];
  const snapshot = (): SculptureRecipe => ({ ...structuredClone(state), shaderHash, orbSnapshot: activeScene?.orbSnapshot() ?? state.orbSnapshot, controls: { ...controls }, camera: input?.camera ?? state.camera, light: input?.light ?? state.light });
  const dispose = () => {
    if (disposed) return;
    disposed = true;
    let failure: unknown;
    for (const cleanup of cleanups.reverse()) { try { cleanup(); } catch (error) { failure ??= error; } }
    cleanups.length = 0;
    try { exportGpu?.dispose(); gpu?.dispose(); } catch (error) { failure ??= error; }
    if (failure) throw failure;
  };
  const fail = (error: unknown) => { if (disposed) return; try { dispose(); } catch {} onError(error); };
  const ready = (async () => {
    const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode([sculpture, extract, blur, present, ...Object.values(ORB_SHADERS)].join('\n---\n')));
    shaderHash = [...new Uint8Array(digest)].map(n => n.toString(16).padStart(2, '0')).join('');
    const context = await init();
    if (disposed) { context.dispose(); return; }
    gpu = context;
    cleanups.push(context.onError(fail));
    const nativeError = (event: GPUUncapturedErrorEvent) => fail(new Error(event.error.message));
    context.gpu.addEventListener('uncapturederror', nativeError);
    cleanups.push(() => context.gpu.removeEventListener('uncapturederror', nativeError));
    void context.gpu.lost.then(info => { if (!disposed) fail(new Error(`GPU device lost: ${info.message}`)); });
    const previewSize = (): [number, number] => {
      const width = Math.max(1,canvas.clientWidth), height = Math.max(1,canvas.clientHeight);
      const scale = Math.min(window.devicePixelRatio || 1,1920/width,1920/height,Math.sqrt(2073600/(width*height)));
      return [Math.max(1,Math.round(width*scale)),Math.max(1,Math.round(height*scale))];
    };
    const output = surface(context, canvas, { autoResize: false, size: previewSize(), dpr: 1 });
    const observer = new ResizeObserver(() => { if (!disposed) { try { output.resize(previewSize()); } catch (error) { fail(error); } } });
    observer.observe(canvas);
    cleanups.push(() => observer.disconnect());
    cleanups.push(() => output.dispose());
    activeScene = createScene(context, output, controls, state.orbSnapshot, 768);
    cleanups.push(() => activeScene?.destroy());
    await activeScene.prepare(output);
    if (disposed) return;
    input = installPointerInput(canvas, state);
    cleanups.push(() => input?.dispose());
    resizeScene = () => { if (!disposed) activeScene?.resize(output.size, controls.renderScale); };
    cleanups.push(output.onResize(resizeScene));
    const time = clock(context);
    let previousFrame = 0;
    frameLoop(context, currentFrame => {
      if (disposed || exporting || preparingMaterial || inFlight || document.hidden) return;
      const now = time.time;
      if (now - previousFrame < 1/24) return;
      try {
        const dt = Math.max(0, Math.min(now - previousFrame, 0.1));
        previousFrame = now;
        input!.advance(dt);
        if (controls.spin) state.sculptureTime += dt;
        state.clockTime += dt;
        activeScene!.render(currentFrame, output, input!.camera, controls, { ...state, deltaTime: dt, light: input!.light });
        inFlight = true;
        queueMicrotask(() => { if (!disposed) void context.gpu.queue.onSubmittedWorkDone().then(() => { inFlight = false; }, fail); });
      } catch (error) { fail(error); }
    });
  })().catch(error => { fail(error); throw error; });

  return {
    ready, dispose, snapshot,
    setControls(next: SculptureControls) {
      const scale = controls.renderScale;
      controls = normalizeControls(next);
      if (scale !== controls.renderScale) resizeScene();
      const revision=++materialRevision;
      preparingMaterial=true;
      void ready.then(()=>activeScene?.prepareMaterial(controls)).then(()=>{if(revision===materialRevision)preparingMaterial=false;},fail);
    },
    restore(next: SculptureRecipe) {
      state = structuredClone(next); controls = normalizeControls(next.controls);
      input?.restore(next); activeScene?.restoreOrb(next.orbSnapshot); resizeScene();
      const revision=++materialRevision; preparingMaterial=true;
      void ready.then(()=>activeScene?.prepareMaterial(controls)).then(()=>{if(revision===materialRevision)preparingMaterial=false;},fail);
    },
    cancelExport() { exportCancelled = true; },
    async exportPNG(progress: (value: number) => void = () => {}): Promise<Blob> {
      await ready;
      if (!gpu || disposed || exporting) throw new Error('Renderer unavailable or already exporting.');
      const recipe = snapshot();
      const width = recipe.controls.exportWidth, height = recipe.controls.exportHeight;
      validateExport(width,height);
      exporting = true; exportCancelled = false;
      try {
        await gpu.gpu.queue.onSubmittedWorkDone();
        if (disposed) throw new Error('Renderer was closed.');
        const context = await init(); exportGpu = context;
        if (disposed) { context.dispose(); throw new Error('Renderer was closed.'); }
        const pixels = await renderSculpturePixels(context, recipe, progress, () => disposed || exportCancelled);
        const encoded = await encodePixels(pixels, width, height);
        const metadata = JSON.stringify({ ...recipe, output: { width, height } });
        return new Blob([new Uint8Array(addPngProject(new Uint8Array(await encoded.arrayBuffer()), metadata)).buffer], { type: 'image/png' });
      } finally {
        exportGpu?.dispose(); exportGpu = undefined;
        exporting = false;
      }
    },
  };
}
export type SculptureRenderer = ReturnType<typeof createSculptureRenderer>;
