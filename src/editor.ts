import { DEFAULT, PRESETS, documentFor, parseDocument, preset, validateSettings } from './model.ts';
import { download, exportSequence, exportStill } from './export.ts';
import type { Capabilities, ImageFormat, Quality, Recipe, Renderer, Settings } from './types.ts';

export type RendererState = 'idle' | 'connecting' | 'ready' | 'unavailable';
export type RendererFactory = (canvas: HTMLCanvasElement, onError: (error: unknown) => void) => Promise<Renderer>;
type HistoryEntry = { settings: Settings; selected: string };
export const messageOf = (error: unknown): string => error instanceof Error ? error.message : String(error);

/** The editor and GPU have separate lifetimes. Importing this module never initializes WebGPU. */
export class Editor {
  settings: Settings;
  selected = 'the-gift';
  quality: Quality = 'balanced';
  status: RendererState = 'idle';
  error = '';
  playing = false;
  busy = false;
  resolution = 'Not rendered';
  cadence = 'PAUSED';
  renderer: Renderer | null = null;
  ready: Promise<boolean> = Promise.resolve(false);
  private listeners = new Set<() => void>();
  private timeListeners = new Set<() => void>();
  private past: HistoryEntry[] = [];
  private future: HistoryEntry[] = [];
  private current: HistoryEntry;
  private canvas: HTMLCanvasElement | null = null;
  private observer: ResizeObserver | null = null;
  private generation = 0;
  private frame = 0;
  private dirty = true;
  private lastTime = 0;
  private count = 0;
  private cadenceStart = 0;
  private exportAbort: AbortController | null = null;
  private saveTimer: ReturnType<typeof setTimeout> | undefined;
  private readonly load: RendererFactory;
  private readonly save?: (recipe: Recipe) => void;

  constructor(settings: Settings = DEFAULT, options: { load?: RendererFactory; save?: (recipe: Recipe) => void } = {}) {
    this.settings = validateSettings(settings);
    this.selected = this.findStudy(settings);
    this.current = this.capture();
    this.load = options.load ?? (async (canvas, onError) => {
      // Failure to load the GPU chunk is caught by connect(), not by the application entry.
      const { createRenderer } = await import('./gpu/renderer.ts');
      return createRenderer(canvas, onError);
    });
    this.save = options.save;
  }
  subscribe = (listener: () => void): (() => void) => {
    this.listeners.add(listener);
    return () => { this.listeners.delete(listener); };
  };
  subscribeTime = (listener: () => void): (() => void) => {
    this.timeListeners.add(listener);
    return () => { this.timeListeners.delete(listener); };
  };
  get canUndo(): boolean { return this.past.length > 0; }
  get canRedo(): boolean { return this.future.length > 0; }
  get modified(): boolean { return JSON.stringify(this.settings) !== JSON.stringify(preset(this.selected)); }
  get hash(): string | null { return this.renderer?.hash ?? null; }
  private capture(): HistoryEntry { return { settings: structuredClone(this.settings), selected: this.selected }; }
  private findStudy(settings: Settings): string {
    return PRESETS.find(p => JSON.stringify(preset(p.id)) === JSON.stringify(settings))?.id ?? 'the-gift';
  }
  private emit(): void { this.listeners.forEach(listener => listener()); }
  private emitTime(): void { this.timeListeners.forEach(listener => listener()); }
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
    this.stop();
    this.settings = recipe.settings;
    this.selected = this.findStudy(this.settings);
    this.commit();
  }
  update(patch: Partial<Settings>, commit = true): void {
    this.assertEditable();
    this.settings = validateSettings({ ...this.settings, ...patch });
    if (commit) this.commit();
    else { this.invalidate(); this.emit(); this.emitTime(); }
  }
  setParameters(patch: Partial<Settings>): void { this.stop(); this.update(patch); }
  select(id: string): void {
    this.assertEditable();
    const settings = preset(id);
    this.stop();
    this.selected = id;
    this.settings = settings;
    this.commit();
  }
  commit(): void {
    this.assertEditable();
    const next = this.capture();
    if (JSON.stringify(next) !== JSON.stringify(this.current)) {
      this.past.push(this.current);
      if (this.past.length > 80) this.past.shift();
      this.future = [];
      this.current = next;
    }
    this.persist(); this.invalidate(); this.emit(); this.emitTime();
  }
  undo(): void {
    this.assertEditable(); this.stop();
    const previous = this.past.pop();
    if (!previous) return;
    this.future.push(this.current);
    this.current = previous;
    this.settings = structuredClone(previous.settings);
    this.selected = previous.selected;
    this.persist(); this.invalidate(); this.emit(); this.emitTime();
  }
  redo(): void {
    this.assertEditable(); this.stop();
    const next = this.future.pop();
    if (!next) return;
    this.past.push(this.current);
    this.current = next;
    this.settings = structuredClone(next.settings);
    this.selected = next.selected;
    this.persist(); this.invalidate(); this.emit(); this.emitTime();
  }
  setQuality(quality: Quality): void {
    this.assertEditable(); this.quality = quality; this.invalidate(); this.emit();
  }
  togglePlay(): void {
    if (this.status !== 'ready' || this.busy) return;
    if (this.playing) { this.stop(); this.commit(); }
    else { this.playing = true; this.lastTime = 0; this.count = 0; this.cadenceStart = performance.now(); this.invalidate(); this.emit(); }
  }
  stop(): void {
    if (!this.playing) return;
    this.playing = false; this.lastTime = 0; this.cadence = 'PAUSED';
    this.persist(); this.emit(); this.emitTime();
  }
  attach(canvas: HTMLCanvasElement): () => void {
    this.detach();
    this.canvas = canvas;
    this.observer = new ResizeObserver(() => this.invalidate());
    this.observer.observe(canvas);
    document.addEventListener('visibilitychange', this.visibility);
    window.addEventListener('pagehide', this.pageHide);
    window.addEventListener('pageshow', this.pageShow);
    this.ready = this.connect();
    return () => this.detach();
  }
  private visibility = (): void => {
    if (document.hidden) { cancelAnimationFrame(this.frame); this.frame = 0; this.lastTime = 0; }
    else this.invalidate();
  };
  private pageHide = (): void => {
    this.stop(); this.cancelExport();
    this.save?.(this.getScene());
    this.generation++; cancelAnimationFrame(this.frame); this.frame = 0;
    this.renderer?.dispose(); this.renderer = null; this.status = 'idle';
  };
  private pageShow = (event: PageTransitionEvent): void => { if (event.persisted) this.ready = this.connect(); };
  detach(): void {
    if (this.canvas) this.save?.(this.getScene());
    this.generation++;
    this.playing = false;
    clearTimeout(this.saveTimer);
    if (typeof cancelAnimationFrame === 'function') cancelAnimationFrame(this.frame);
    this.frame = 0;
    this.cancelExport();
    this.observer?.disconnect(); this.observer = null;
    this.renderer?.dispose(); this.renderer = null;
    if (typeof document !== 'undefined') document.removeEventListener('visibilitychange', this.visibility);
    if (typeof window !== 'undefined') { window.removeEventListener('pagehide', this.pageHide); window.removeEventListener('pageshow', this.pageShow); }
    this.canvas = null;
    this.status = 'idle';
  }
  reconnect(): void { if (this.status !== 'connecting' && !this.busy) this.ready = this.connect(); }
  private async connect(): Promise<boolean> {
    const canvas = this.canvas;
    if (!canvas) return false;
    const serial = ++this.generation;
    this.renderer?.dispose(); this.renderer = null;
    this.status = 'connecting'; this.error = ''; this.emit();
    let active = true;
    let timer: ReturnType<typeof setTimeout> | undefined;
    let fatal: unknown = null;
    const handleError = (error: unknown): void => {
      if (serial !== this.generation || !active) return;
      fatal = error;
      this.fail(error);
    };
    try {
      // Detect unsupported contexts before importing shader/dependency chunks.
      if (!isSecureContext) throw new Error('WebGPU needs HTTPS or localhost. The interface still works; use a secure URL to render.');
      if (!navigator.gpu) throw new Error('This browser does not expose WebGPU. Enable hardware acceleration or use a WebGPU-capable browser.');
      const pending = this.load(canvas, handleError).then(renderer => {
        if (!active || serial !== this.generation) { renderer.dispose(); throw new Error('Renderer connection superseded.'); }
        return renderer;
      });
      const renderer = await Promise.race([
        pending,
        new Promise<never>((_, reject) => { timer = setTimeout(() => reject(new Error('GPU initialization timed out. The editor remains available; reconnect to retry.')), 20000); }),
      ]);
      if (fatal) { renderer.dispose(); throw fatal; }
      this.renderer = renderer;
      this.draw();
      await renderer.settled();
      if (fatal) throw fatal;
      if (serial !== this.generation) return false;
      this.status = 'ready'; this.emit(); this.invalidate();
      return true;
    } catch (error) {
      active = false;
      if (serial === this.generation) this.fail(error);
      return false;
    } finally { clearTimeout(timer); }
  }
  private fail(error: unknown): void {
    this.stop(); this.cancelExport();
    if (typeof cancelAnimationFrame === 'function') cancelAnimationFrame(this.frame);
    this.frame = 0;
    this.renderer?.dispose(); this.renderer = null;
    this.status = 'unavailable'; this.error = messageOf(error); this.cadence = 'PAUSED';
    this.emit();
  }
  invalidate(): void {
    this.dirty = true;
    if (!this.frame && this.canvas && this.status === 'ready' && !document.hidden && !this.busy) this.frame = requestAnimationFrame(this.tick);
  }
  private draw(): void {
    if (!this.renderer || !this.canvas) return;
    const rect = this.canvas.getBoundingClientRect();
    const cap = { draft: 360, balanced: 640, final: 1080 }[this.quality];
    const height = Math.max(64, Math.round(Math.min(rect.height * Math.min(devicePixelRatio || 1, 1.5), cap)));
    const width = Math.max(64, Math.round(height * Math.max(1, rect.width) / Math.max(1, rect.height)));
    this.renderer.drawPreview(this.settings, width, height, this.quality);
    const resolution = `${width} \u00d7 ${height}`;
    if (resolution !== this.resolution) { this.resolution = resolution; this.emitTime(); }
    this.dirty = false;
  }
  private tick = (now: number): void => {
    this.frame = 0;
    if (document.hidden || this.busy || this.status !== 'ready') return;
    if (this.playing) {
      const delta = this.lastTime ? Math.min((now - this.lastTime) / 1000, 0.1) : 0;
      this.settings = { ...this.settings, time: (this.settings.time + delta) % this.settings.duration };
      this.lastTime = now; this.dirty = true; this.count++;
      if (now - this.cadenceStart >= 1000) {
        this.cadence = `${Math.round(this.count * 1000 / (now - this.cadenceStart))} FPS / CADENCE`;
        this.count = 0; this.cadenceStart = now;
      }
      this.emitTime();
    }
    try { if (this.dirty) this.draw(); }
    catch (error) { this.fail(error); return; }
    if (this.playing) this.frame = requestAnimationFrame(this.tick);
  };
  cancelExport(): void { this.exportAbort?.abort(); }
  async exportImage(width: number, height: number, format: ImageFormat | 'sequence', options: { fps?: number; seconds?: number; onProgress?: (progress: number) => void } = {}): Promise<Blob> {
    if (!this.renderer || this.status !== 'ready' || this.busy) throw new Error('Renderer unavailable or busy.');
    this.stop();
    const renderer = this.renderer, snapshot = structuredClone(this.settings);
    this.busy = true;
    this.exportAbort = new AbortController(); this.emit();
    try {
      const opts = { signal: this.exportAbort.signal, onProgress: options.onProgress };
      return format === 'sequence'
        ? await exportSequence(renderer, snapshot, width, height, options.fps ?? 24, options.seconds ?? 5, opts)
        : await exportStill(renderer, snapshot, width, height, format, opts);
    } finally { this.busy = false; this.exportAbort = null; this.emit(); this.invalidate(); }
  }
  exportPNG(width = 1920, height = 1080): Promise<Blob> { return this.exportImage(width, height, 'image/png'); }
  saveRecipe(): void {
    download(new Blob([JSON.stringify(this.getScene(), null, 2)], { type: 'application/json' }), `exo-${this.selected}-s${this.settings.seed}.exo.json`);
  }
}
