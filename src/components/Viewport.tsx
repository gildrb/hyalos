import { useEffect, useLayoutEffect, useMemo, useRef } from 'preact/hooks';
import { Editor } from '../editor.ts';
import { PRESETS, preset } from '../model.ts';
import { studyImages } from '../assets.ts';
import { Icon } from './Icon.tsx';

const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v));
export function Viewport({ editor, notify }: { editor: Editor; notify: (text: string) => void }) {
  const canvas = useRef<HTMLCanvasElement>(null), stage = useRef<HTMLDivElement>(null), studio = useRef<HTMLElement>(null);
  const drag = useRef<{ pointerId: number; x: number; y: number; sx: number; sy: number; height: number; changed: boolean } | null>(null);
  const savedSettings = useMemo(() => preset(editor.selected), [editor.selected]);
  useLayoutEffect(() => { if (canvas.current) return editor.attach(canvas.current); }, [editor]);
  useEffect(() => {
    const node = stage.current;
    if (!node) return;
    let timer: number | undefined;
    let wheelSettings = editor.settings;
    const cancel = (): void => { clearTimeout(timer); timer = undefined; };
    const finish = (): void => {
      if (timer === undefined) return;
      cancel();
      if (!editor.busy) editor.commit();
    };
    const unsubscribe = editor.subscribe(() => {
      // Another edit owns its own commit; never let an old wheel timer commit it.
      if (editor.settings !== wheelSettings) cancel();
      else if (editor.busy) finish();
    });
    const wheel = (e: WheelEvent): void => {
      if (!e.ctrlKey || editor.busy || drag.current) return;
      e.preventDefault();
      const zoom = clamp(editor.settings.zoom * Math.exp(-e.deltaY * .002), .65, 2);
      if (zoom === editor.settings.zoom) return;
      cancel();
      editor.update({ zoom }, false);
      wheelSettings = editor.settings;
      timer = window.setTimeout(finish, 180);
    };
    node.addEventListener('wheel', wheel, { passive: false });
    window.addEventListener('pointerdown', finish, true);
    window.addEventListener('keydown', finish, true);
    document.addEventListener('visibilitychange', finish);
    return () => {
      cancel(); unsubscribe();
      node.removeEventListener('wheel', wheel);
      window.removeEventListener('pointerdown', finish, true);
      window.removeEventListener('keydown', finish, true);
      document.removeEventListener('visibilitychange', finish);
    };
  }, [editor]);
  const endDrag = (pointerId: number): void => {
    const d = drag.current;
    if (!d || d.pointerId !== pointerId) return;
    drag.current = null;
    if (stage.current?.hasPointerCapture(pointerId)) stage.current.releasePointerCapture(pointerId);
    if (d.changed && !editor.busy) editor.commit();
  };
  const study = PRESETS.find(p => p.id === editor.selected);
  if (!study) throw new Error('The selected study is unavailable.');
  const live = editor.status === 'ready';
  // Disposing/reconnecting unconfigures the GPU canvas; the saved study remains usable.
  const hasFrame = live && editor.renderedSettings !== null;
  const baseline = (live ? editor.renderedSettings : null) ?? savedSettings;
  const settings = editor.settings;
  const framingChanged = settings.panX !== baseline.panX || settings.panY !== baseline.panY || settings.zoom !== baseline.zoom || settings.rotation !== baseline.rotation;
  // sceneRadiance uses height-normalized, Y-up coordinates: R(rotation) * (xy - pan/4) / zoom.
  // In CSS's Y-down coordinates the inverse camera mapping is T(pan) R(delta) S(ratio) T(-baselinePan).
  // cqh refers to the untransformed stage height, including after viewport/fullscreen resizing.
  const framing = framingChanged
    ? `translate(${settings.panX * 25}cqh, ${-settings.panY * 25}cqh) rotate(${settings.rotation - baseline.rotation}deg) scale(${settings.zoom / baseline.zoom}) translate(${-baseline.panX * 25}cqh, ${baseline.panY * 25}cqh)`
    : 'none';
  const startupLabel = editor.status === 'connecting' ? editor.startupPhase === 'compiling' ? 'Compiling shaders' : 'Loading renderer' : editor.refining ? 'Rendering preview' : '';
  return <section class="studio" ref={studio} aria-label="Visual canvas">
    <div class="canvas-toolbar"><span class="breadcrumb"><strong id="study-title">{study.name}</strong><span id="modified" hidden={!editor.modified}>Modified</span></span><div class="canvas-tools">
      <button id="undo" aria-label="Undo" title="Undo (Ctrl/Cmd Z)" disabled={!editor.canUndo || editor.busy} onClick={() => editor.undo()}><Icon name="undo" /></button>
      <button id="redo" aria-label="Redo" title="Redo (Ctrl/Cmd Shift Z)" disabled={!editor.canRedo || editor.busy} onClick={() => editor.redo()}><Icon name="redo" /></button><span class="separator" />
      <button class="text-button" disabled={editor.busy} onClick={() => editor.select(editor.selected)}>Reset</button>
      <button aria-label="Toggle fullscreen" onClick={async () => { try { if (document.fullscreenElement) await document.exitFullscreen(); else await studio.current?.requestFullscreen(); } catch { notify('Fullscreen is unavailable in this browser.'); } }}><Icon name="fullscreen" /></button>
    </div><div class="render-controls">
      <span id="pending-changes" class="render-status" role="status" title="Only position, scale and rotation have an immediate bitmap approximation. Form, light, orbit and finish changes require Render.">{editor.renderQueued ? 'Render queued' : editor.pendingChanges ? 'Changes not rendered' : ''}</span>
      <button id="render-preview" class="outline-button render-button" disabled={!live || editor.busy || editor.refining || editor.renderQueued} aria-busy={editor.refining || editor.renderQueued} aria-label={editor.refining ? 'Rendering preview' : editor.renderQueued ? 'Preview render queued' : 'Render current settings'} title="Render current settings at the selected preview quality" onClick={() => editor.renderPreview()}>{editor.refining ? 'Rendering…' : editor.renderQueued ? 'Queued…' : 'Render'}</button>
    </div></div>
    <div class="canvas-error" id="gpu-error" hidden={editor.status !== 'unavailable'} role="alert"><div><strong>Live rendering unavailable</strong><p>{editor.error}</p></div><button class="outline-button" disabled={editor.busy} onClick={() => editor.reconnect()}>Reconnect</button></div>
    <div class="stage-wrap"><div class="stage" id="stage" ref={stage} role="region" aria-label="Composition. Drag to move; control-scroll to zoom. Choose Render for an accurate image." aria-describedby={editor.pendingChanges ? 'pending-changes composition-status' : undefined} tabIndex={0} onPointerDown={e => {
      if (editor.busy || drag.current || !e.isPrimary || e.button !== 0 || e.target !== e.currentTarget) return;
      e.preventDefault();
      e.currentTarget.focus({ preventScroll: true });
      drag.current = { pointerId: e.pointerId, x: e.clientX, y: e.clientY, sx: editor.settings.panX, sy: editor.settings.panY, height: Math.max(1, e.currentTarget.clientHeight), changed: false };
      e.currentTarget.setPointerCapture(e.pointerId);
    }} onPointerMove={e => {
      const d = drag.current;
      if (!d || e.pointerId !== d.pointerId || editor.busy) return;
      const panX = clamp(d.sx + 4 * (e.clientX - d.x) / d.height, -1.8, 1.8);
      const panY = clamp(d.sy - 4 * (e.clientY - d.y) / d.height, -1.8, 1.8);
      if (panX === editor.settings.panX && panY === editor.settings.panY) return;
      d.changed = true;
      editor.update({ panX, panY }, false);
    }} onPointerUp={e => endDrag(e.pointerId)} onPointerCancel={e => endDrag(e.pointerId)} onLostPointerCapture={e => endDrag(e.pointerId)}>
      <div class="canvas-bitmap" style={{ transform: framing }}>
        <img id="poster" src={studyImages[editor.selected]} alt="Saved study preview. Not a live render." draggable={false} hidden={hasFrame} />
        <canvas id="canvas" ref={canvas} aria-label="Last completed render" aria-hidden={!hasFrame} style={{ opacity: hasFrame ? 1 : 0 }} />
      </div>
      <div class="canvas-feedback">
        <div class="canvas-loading" id="loading" hidden={!startupLabel} role="status"><span class="loader" /><span>{startupLabel}</span></div>
        <span class="reference-label" id="composition-status" hidden={hasFrame && !editor.pendingChanges && !framingChanged} title="This is a bitmap framing approximation only. Form, light, orbit and finish changes are not shown until Render.">{hasFrame ? framingChanged ? 'Composition approximation — Render for accuracy' : 'Last render — changes pending' : framingChanged ? 'Saved study — composition approximation' : 'Saved study — not a live render'}</span>
      </div>
    </div></div>
  </section>;
}
