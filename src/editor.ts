import { DEFAULT, PRESETS, documentFor, parseDocument, preset, validateSettings } from './model.ts';
import { download, exportSequence, exportStill } from './export.ts';
import type { Capabilities, ImageFormat, Quality, Recipe, Renderer, RendererInitOptions, Settings, StartupPhase } from './types.ts';

export type RendererState = 'idle' | 'connecting' | 'ready' | 'unavailable';
export type RendererFactory = (canvas: HTMLCanvasElement, onError: (error: unknown) => void, options?: RendererInitOptions) => Promise<Renderer>;
type HistoryEntry = { settings: Settings; selected: string };
export const messageOf = (error: unknown): string => error instanceof Error ? error.message : String(error);
const PREVIEW_LIMITS = {
  draft: { side: 640, pixels: 230400 },
  balanced: { side: 1024, pixels: 500000 },
  final: { side: 1440, pixels: 1000000 },
};
const PREVIEW_INTERVAL = 1000 / 15;

/** The editor and GPU have separate lifetimes. Importing this module never initializes WebGPU. */
export class Editor {
  settings: Settings;
  selected = 'the-gift';
  quality: Quality = 'balanced';
  status: RendererState = 'idle';
  startupPhase: StartupPhase = 'idle';
  refining = false;
  pendingChanges = true;
  renderedSettings: Settings | null = null;
  error = '';
  busy = false;
  resolution = 'Not rendered';
  renderer: Renderer | null = null;
  ready: Promise<boolean> = Promise.resolve(false);
  private listeners = new Set<() => void>();
  private past: HistoryEntry[] = [];
  private future: HistoryEntry[] = [];
  private current: HistoryEntry;
  private canvas: HTMLCanvasElement | null = null;
  private observer: ResizeObserver | null = null;
  private viewportWidth = 0;
  private viewportHeight = 0;
  private viewportDpr = 1;
  private generation = 0;
  private connectionAbort: AbortController | null = null;
  private previewTimer: number | undefined;
  private previewAbort: AbortController | null = null;
  private nextPreviewAt = 0;
  private interacting = false;
  private previewPending: Promise<void> | null = null;
  // A staged revision is not permission to submit GPU work.
  private previewRequested = false;
  private revision = 0;
  private exportAbort: AbortController | null = null;
  private saveTimer: ReturnType<typeof setTimeout> | undefined;
  private readonly load: RendererFactory;
  private readonly save?: (recipe: Recipe) => void;

  constructor(settings: Settings = DEFAULT, options: { load?: RendererFactory; save?: (recipe: Recipe) => void } = {}) {
    this.settings = validateSettings(settings);
    this.selected = this.findStudy(this.settings);
    this.current = this.capture();
    this.load = options.load ?? (async (canvas, onError, initOptions) => {
      // Keep the failure boundary lazy: a static GPU import would make dependency
      // or shader-chunk loading failure prevent the recipe editor from mounting.
      const { createRenderer } = await import('./gpu/renderer.ts');
      initOptions?.signal?.throwIfAborted();
      return createRenderer(canvas, onError, initOptions);
    });
    this.save = options.save;
  }
  subscribe = (listener: () => void): (() => void) => {
    this.listeners.add(listener);
    return () => { this.listeners.delete(listener); };
  };
  get canUndo(): boolean { return this.past.length > 0; }
  get canRedo(): boolean { return this.future.length > 0; }
  get modified(): boolean { return JSON.stringify(this.settings) !== JSON.stringify(preset(this.selected)); }
  get hash(): string | null { return this.renderer?.hash ?? null; }
  get renderQueued(): boolean { return this.status === 'ready' && this.previewRequested && !this.refining; }
  private capture(): HistoryEntry { return { settings: structuredClone(this.settings), selected: this.selected }; }
  private findStudy(settings: Settings): string {
    return PRESETS.find(p => JSON.stringify(preset(p.id)) === JSON.stringify(settings))?.id ?? 'the-gift';
  }
  private emit(): void { this.listeners.forEach(listener => listener()); }
  private persist(): void {
    clearTimeout(this.saveTimer);
    this.saveTimer = setTimeout(() => { this.save?.(this.getScene()); }, 250);
  }
  private assertEditable(): void { if (this.busy) throw new Error('An export is active.'); }
  getScene(): Recipe { return documentFor(this.settings, this.renderer?.hash); }
  capabilities(): Capabilities {
    return { webgpu: this.status === 'ready', renderer: 'vgpu', shaderHash: this.hash, maxImagePixels: 33554432, previewQuality: this.quality, exporting: this.busy };
  }
  setScene(value: unknown): void {
    this.assertEditable();
    const recipe = parseDocument(JSON.stringify(value));
    this.settings = recipe.settings;
    this.selected = this.findStudy(this.settings);
    this.invalidate();
    this.commit();
  }
  update(patch: Partial<Settings>, commit = true): void {
    this.assertEditable();
    this.settings = validateSettings({ ...this.settings, ...patch });
    this.invalidate();
    if (commit) this.commit();
    else { this.interacting = true; this.emit(); }
  }
  setParameters(patch: Partial<Settings>): void { this.update(patch); }
  select(id: string): void {
    this.assertEditable();
    const settings = preset(id);
    this.selected = id;
    this.settings = settings;
    this.invalidate();
    this.commit();
  }
  commit(): void {
    this.assertEditable();
    this.interacting = false;
    const next = this.capture();
    if (JSON.stringify(next) !== JSON.stringify(this.current)) {
      this.past.push(this.current);
      if (this.past.length > 80) this.past.shift();
      this.future = [];
      this.current = next;
    }
    this.persist(); this.emit();
  }
  undo(): void {
    this.assertEditable();
    this.interacting = false;
    const previous = this.past.pop();
    if (!previous) return;
    this.future.push(this.current);
    this.current = previous;
    this.settings = structuredClone(previous.settings);
    this.selected = previous.selected;
    this.persist(); this.invalidate(); this.emit();
  }
  redo(): void {
    this.assertEditable();
    this.interacting = false;
    const next = this.future.pop();
    if (!next) return;
    this.past.push(this.current);
    this.current = next;
    this.settings = structuredClone(next.settings);
    this.selected = next.selected;
    this.persist(); this.invalidate(); this.emit();
  }
  setQuality(quality: Quality): void {
    this.assertEditable();
    if (this.quality === quality) return;
    this.quality = quality; this.invalidate(); this.emit();
  }
  renderPreview(): void {
    if (this.status !== 'ready' || this.busy || this.refining || this.renderQueued) return;
    this.previewRequested = true;
    this.schedule();
    this.emit();
  }
  attach(canvas: HTMLCanvasElement): () => void {
    this.detach();
    this.canvas = canvas;
    this.viewportWidth = canvas.clientWidth; this.viewportHeight = canvas.clientHeight; this.viewportDpr = this.pixelRatio();
    this.observer = new ResizeObserver(() => {
      const width = canvas.clientWidth, height = canvas.clientHeight, dpr = this.pixelRatio();
      if (width === this.viewportWidth && height === this.viewportHeight && dpr === this.viewportDpr) return;
      this.viewportWidth = width; this.viewportHeight = height; this.viewportDpr = dpr;
      this.invalidate(); this.emit();
    });
    this.observer.observe(canvas);
    document.addEventListener('visibilitychange', this.visibility);
    window.addEventListener('pagehide', this.pageHide);
    window.addEventListener('pageshow', this.pageShow);
    this.ready = this.connect();
    return () => this.detach();
  }
  private visibility = (): void => {
    if (document.hidden) this.suspendPreview();
    else this.schedule();
  };
  private pageHide = (): void => {
    this.cancelExport();
    this.save?.(this.getScene());
    this.generation++; this.suspendPreview(); clearTimeout(this.saveTimer);
    this.connectionAbort?.abort(); this.connectionAbort = null;
    this.renderer?.dispose(); this.renderer = null; this.status = 'idle'; this.startupPhase = 'idle'; this.refining = false;
    this.renderedSettings = null;
    this.previewRequested = false; this.pendingChanges = true;
  };
  private pageShow = (event: PageTransitionEvent): void => { if (event.persisted) this.ready = this.connect(); };
  detach(): void {
    if (this.canvas) this.save?.(this.getScene());
    this.generation++;
    this.connectionAbort?.abort(); this.connectionAbort = null;
    this.interacting = false;
    clearTimeout(this.saveTimer);
    this.suspendPreview();
    this.cancelExport();
    this.observer?.disconnect(); this.observer = null;
    this.renderer?.dispose(); this.renderer = null;
    if (typeof document !== 'undefined') document.removeEventListener('visibilitychange', this.visibility);
    if (typeof window !== 'undefined') { window.removeEventListener('pagehide', this.pageHide); window.removeEventListener('pageshow', this.pageShow); }
    this.canvas = null; this.renderedSettings = null;
    this.status = 'idle'; this.startupPhase = 'idle'; this.refining = false;
    this.previewRequested = false; this.pendingChanges = true;
  }
  reconnect(): void { if (this.status !== 'connecting' && !this.busy) this.ready = this.connect(); }
  private async connect(): Promise<boolean> {
    const canvas = this.canvas;
    if (!canvas) return false;
    const serial = ++this.generation;
    this.connectionAbort?.abort();
    const connection = new AbortController();
    const { signal } = connection;
    this.connectionAbort = connection;
    this.suspendPreview();
    this.previewRequested = false; this.pendingChanges = true;
    this.renderer?.dispose(); this.renderer = null;
    this.renderedSettings = null;
    this.status = 'connecting'; this.startupPhase = 'loading'; this.refining = false; this.error = ''; this.emit();
    const timer = window.setTimeout(() => connection.abort(new Error('Renderer initialization timed out. Reconnect to retry.')), 20000);
    let rejectConnection: (() => void) | undefined;
    const cancelled = new Promise<never>((_, reject) => {
      rejectConnection = (): void => { reject(signal.reason); };
      signal.addEventListener('abort', rejectConnection, { once: true });
    });
    const handleError = (error: unknown): void => {
      if (serial === this.generation && !signal.aborted) this.fail(error);
    };
    try {
      const startup = async (): Promise<void> => {
        await this.previewPending;
        signal.throwIfAborted();
        // Detect unsupported contexts before importing shader/dependency chunks.
        if (!isSecureContext) throw new Error('WebGPU needs HTTPS or localhost. The interface still works; use a secure URL to render.');
        if (!navigator.gpu) throw new Error('This browser does not expose WebGPU. Enable hardware acceleration or use a WebGPU-capable browser.');
        const renderer = await this.load(canvas, handleError, {
          signal,
          onPhase: phase => {
            if (serial !== this.generation || signal.aborted) return;
            this.startupPhase = phase; this.emit();
          },
        });
        if (signal.aborted || serial !== this.generation) {
          renderer.dispose();
          throw signal.reason ?? new Error('Renderer connection superseded.');
        }
        this.renderer = renderer;
        // Initialization authorizes no frame. Only Render may request a preview.
        this.status = 'ready'; this.startupPhase = 'ready';
        this.emit();
      };
      await Promise.race([startup(), cancelled]);
      return true;
    } catch (error) {
      if (serial === this.generation && this.connectionAbort === connection) this.fail(error);
      return false;
    } finally {
      clearTimeout(timer);
      if (rejectConnection) signal.removeEventListener('abort', rejectConnection);
    }
  }
  private fail(error: unknown): void {
    this.cancelExport();
    this.suspendPreview();
    this.connectionAbort?.abort(error); this.connectionAbort = null;
    this.renderer?.dispose(); this.renderer = null;
    this.renderedSettings = null;
    this.status = 'unavailable'; this.startupPhase = 'idle'; this.refining = false; this.error = messageOf(error);
    this.previewRequested = false; this.pendingChanges = true;
    this.emit();
  }
  invalidate(): void {
    this.revision++; this.pendingChanges = true;
    this.previewRequested = false; this.suspendPreview();
  }
  private suspendPreview(): void {
    clearTimeout(this.previewTimer);
    this.previewTimer = undefined;
    this.previewAbort?.abort();
    if (this.refining) { this.refining = false; this.emit(); }
  }
  private schedule(): void {
    if (!this.previewRequested || this.previewTimer !== undefined || this.previewPending || !this.canvas || !this.renderer || this.status !== 'ready' || document.hidden || this.busy) return;
    this.previewTimer = window.setTimeout(this.tick, Math.max(0, Math.ceil(this.nextPreviewAt - performance.now())));
  }
  private pixelRatio(): number {
    return Number.isFinite(window.devicePixelRatio) && window.devicePixelRatio > 0 ? Math.min(1, window.devicePixelRatio) : 1;
  }
  private async draw(): Promise<void> {
    if (this.previewPending) return this.previewPending;
    const renderer = this.renderer, canvas = this.canvas, serial = this.generation, revision = this.revision;
    if (!renderer || !canvas || document.hidden || this.busy) return;
    // CSS framing transforms the bitmap, never its layout or the render budget.
    const layoutWidth = canvas.clientWidth, layoutHeight = canvas.clientHeight;
    if (layoutWidth <= 0 || layoutHeight <= 0) {
      this.previewRequested = false; this.emit();
      return;
    }
    const quality = this.quality;
    const limits = PREVIEW_LIMITS[quality];
    const dpr = this.pixelRatio();
    const side = Math.min(limits.side, renderer.maxTexture);
    const scale = Math.min(1, dpr, side / layoutWidth, side / layoutHeight, Math.sqrt(limits.pixels / layoutWidth / layoutHeight));
    const width = Math.max(1, Math.floor(layoutWidth * scale));
    const height = Math.max(1, Math.floor(layoutHeight * scale));
    // Quality controls draft's single ray in the renderer; the recipe is untouched.
    const settings = structuredClone(this.settings);
    const abort = new AbortController();
    this.previewAbort = abort;
    this.refining = true; this.emit();
    const started = performance.now();
    // The promise covers every scene chunk and the final postprocess submission.
    let pending: Promise<void> | undefined;
    try {
      pending = renderer.drawPreview(settings, width, height, quality, abort.signal);
      this.previewPending = pending;
      await pending;
      if (!abort.signal.aborted && !document.hidden && serial === this.generation && renderer === this.renderer) {
        this.renderedSettings = settings;
        if (revision === this.revision) {
          this.previewRequested = false;
          this.pendingChanges = quality !== this.quality || canvas.clientWidth !== layoutWidth || canvas.clientHeight !== layoutHeight || this.pixelRatio() !== dpr;
        }
        this.resolution = `${width} \u00d7 ${height} px`;
        this.emit();
      }
    } finally {
      const finished = performance.now();
      // Never exceed 15 fps; even slow/aborted frames get at least their elapsed time off.
      this.nextPreviewAt = Math.max(started + PREVIEW_INTERVAL, finished + (finished - started));
      if (this.previewAbort === abort) this.previewAbort = null;
      if (this.previewPending === pending) this.previewPending = null;
      if (serial === this.generation && renderer === this.renderer) {
        if (this.refining) { this.refining = false; this.emit(); }
      }
    }
  }
  private tick = (): void => {
    this.previewTimer = undefined;
    if (document.hidden || this.busy || !this.renderer || this.status !== 'ready' || this.previewPending) return;
    const now = performance.now();
    if (now < this.nextPreviewAt) { this.schedule(); return; }
    if (!this.previewRequested) return;
    const renderer = this.renderer, serial = this.generation;
    void this.draw().then(() => {
      if (serial === this.generation && renderer === this.renderer) this.schedule();
    }, error => {
      if (serial === this.generation && renderer === this.renderer) this.fail(error);
    });
  };
  cancelExport(): void { this.exportAbort?.abort(new DOMException('Export cancelled.', 'AbortError')); }
  async exportImage(width: number, height: number, format: ImageFormat | 'sequence', options: { fps?: number; seconds?: number; onProgress?: (progress: number) => void } = {}): Promise<Blob> {
    if (!this.renderer || this.status !== 'ready' || this.busy) throw new Error('Renderer unavailable or busy.');
    if (this.interacting) this.commit();
    const renderer = this.renderer, snapshot = structuredClone(this.settings), serial = this.generation;
    this.busy = true;
    this.previewRequested = false;
    this.suspendPreview();
    const abort = new AbortController();
    this.exportAbort = abort; this.emit();
    try {
      await this.previewPending;
      abort.signal.throwIfAborted();
      if (serial !== this.generation || renderer !== this.renderer) throw new Error('Renderer changed before export.');
      const opts = { signal: abort.signal, onProgress: options.onProgress };
      const result = format === 'sequence'
        ? await exportSequence(renderer, snapshot, width, height, options.fps ?? 24, options.seconds ?? 5, opts)
        : await exportStill(renderer, snapshot, width, height, format, opts);
      abort.signal.throwIfAborted();
      if (serial !== this.generation || renderer !== this.renderer) throw new Error('Renderer changed during export.');
      return result;
    } finally {
      this.busy = false; this.exportAbort = null; this.emit();
    }
  }
  exportPNG(width = 1920, height = 1080): Promise<Blob> { return this.exportImage(width, height, 'image/png'); }
  saveRecipe(): void {
    download(new Blob([JSON.stringify(this.getScene(), null, 2)], { type: 'application/json' }), `hyalos-${this.selected}-s${this.settings.seed}.hyalos.json`);
  }
}
