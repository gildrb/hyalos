import { useEffect, useLayoutEffect, useState, useRef } from 'preact/hooks';
import { Editor } from '../editor.ts';
import { PRESETS } from '../model.ts';
import { studyImages } from '../assets.ts';
import type { Quality } from '../types.ts';
import { Icon } from './Icon.tsx';

const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v));
function Timeline({ editor }: { editor: Editor }) {
  const [, setRevision] = useState(0);
  useLayoutEffect(() => {
    const refresh = () => setRevision(n => n + 1);
    const unsubscribe = editor.subscribeTime(refresh);
    refresh();
    return unsubscribe;
  }, [editor]);
  const s = editor.settings;
  return <>
    <div class="transport">
      <button id="play" class="play-button" disabled={editor.status !== 'ready' || editor.busy} aria-label={editor.playing ? 'Pause animation' : 'Play animation'} onClick={() => editor.togglePlay()}><Icon name={editor.playing ? 'pause' : 'play'} /></button>
      <span id="time-display" class="timecode">{(s.time % s.duration).toFixed(3).padStart(6, '0')}</span>
      <input id="scrub" aria-label="Animation time" type="range" min={0} max={s.duration} step={.001} value={s.time % s.duration} disabled={editor.busy} onInput={e => { editor.stop(); editor.update({ time: Number(e.currentTarget.value) }, false); }} onChange={() => editor.commit()} />
      <label class="duration-field">Loop <select aria-label="Loop duration" value={s.duration} disabled={editor.busy} onChange={e => { const duration = Number(e.currentTarget.value); editor.stop(); editor.update({ duration, time: s.time % duration }); }}>{[...new Set([6, 12, 24, 36, 60, s.duration])].sort((a, b) => a - b).map(n => <option key={n} value={n}>{n}s</option>)}</select></label>
    </div>
    <div class="studio-bottom"><span><span class={`status-dot ${editor.status === 'ready' ? 'ready' : ''}`} /><span id="gpu-label">{editor.status === 'ready' ? 'WEBGPU / VGPU' : editor.status === 'connecting' ? 'CONNECTING' : 'REFERENCE ONLY'}</span><span class="divider">/</span><span id="resolution-label">{editor.resolution}</span></span><span id="cadence">{editor.cadence}</span><label class="quality-selector">Preview <select id="quality" value={editor.quality} disabled={editor.busy} onChange={e => editor.setQuality(e.currentTarget.value as Quality)}><option value="draft">Draft</option><option value="balanced">Balanced</option><option value="final">Final</option></select></label></div>
  </>;
}
export function Viewport({ editor, notify }: { editor: Editor; notify: (text: string) => void }) {
  const canvas = useRef<HTMLCanvasElement>(null), stage = useRef<HTMLDivElement>(null);
  const drag = useRef<{ x: number; y: number; sx: number; sy: number } | null>(null);
  useLayoutEffect(() => { if (canvas.current) return editor.attach(canvas.current); }, [editor]);
  useEffect(() => {
    const node = canvas.current;
    if (!node) return;
    const wheel = (e: WheelEvent): void => {
      if (!e.ctrlKey || editor.busy || editor.status !== 'ready') return;
      e.preventDefault(); editor.update({ zoom: clamp(editor.settings.zoom * Math.exp(-e.deltaY * .002), .65, 2) });
    };
    node.addEventListener('wheel', wheel, { passive: false });
    return () => node.removeEventListener('wheel', wheel);
  }, [editor]);
  const endDrag = (): void => { if (drag.current) { drag.current = null; if (!editor.busy) editor.commit(); } };
  const index = PRESETS.findIndex(p => p.id === editor.selected), study = PRESETS[index];
  return <section class="studio" aria-label="Visual canvas">
    <div class="canvas-toolbar"><span class="breadcrumb">STUDY <span>{String(index + 1).padStart(2, '0')}</span><i>/</i><strong id="study-title">{study.name}</strong><span id="modified" hidden={!editor.modified}>Modified</span></span><div class="canvas-tools">
      <button id="undo" aria-label="Undo" title="Undo (Ctrl/Cmd Z)" disabled={!editor.canUndo || editor.busy} onClick={() => editor.undo()}><Icon name="undo" /></button>
      <button id="redo" aria-label="Redo" title="Redo (Ctrl/Cmd Shift Z)" disabled={!editor.canRedo || editor.busy} onClick={() => editor.redo()}><Icon name="redo" /></button><span class="separator" />
      <button class="text-button" disabled={editor.busy} onClick={() => editor.select(editor.selected)}>Reset</button>
      <button aria-label="Toggle fullscreen" onClick={async () => { try { if (document.fullscreenElement) await document.exitFullscreen(); else await stage.current?.requestFullscreen(); } catch { notify('Fullscreen is unavailable in this browser.'); } }}><Icon name="fullscreen" /></button>
    </div></div>
    <div class="stage-wrap"><div class="stage" id="stage" ref={stage}>
      <img id="poster" src={studyImages[editor.selected]} alt="Approximate CPU study illustration. Not a live shader render." hidden={editor.status === 'ready'} />
      <canvas id="canvas" ref={canvas} aria-label="Procedural study. Drag to compose; control-scroll to zoom." tabIndex={0} style={{ opacity: editor.status === 'ready' ? 1 : 0 }} onPointerDown={e => {
        if (editor.busy || editor.status !== 'ready') return;
        drag.current = { x: e.clientX, y: e.clientY, sx: editor.settings.panX, sy: editor.settings.panY };
        e.currentTarget.setPointerCapture(e.pointerId);
      }} onPointerMove={e => {
        const d = drag.current;
        if (!d || editor.busy) return;
        const height = Math.max(1, e.currentTarget.getBoundingClientRect().height);
        editor.update({ panX: clamp(d.sx + 4 * (e.clientX - d.x) / height, -1.8, 1.8), panY: clamp(d.sy - 4 * (e.clientY - d.y) / height, -1.8, 1.8) }, false);
      }} onPointerUp={endDrag} onPointerCancel={endDrag} onLostPointerCapture={endDrag} />
      <div class="canvas-loading" id="loading" hidden={editor.status !== 'idle' && editor.status !== 'connecting'} role="status"><span class="loader" /><span>Preparing light transport</span></div>
      <div class="canvas-error" id="gpu-error" hidden={editor.status !== 'unavailable'} role="status"><span class="eyebrow">RENDERER UNAVAILABLE</span><strong>The editor is ready. The GPU is not.</strong><p>{editor.error}</p><button class="outline-button" onClick={() => editor.reconnect()}>Reconnect</button><small>Reference illustration only. Live image export is disabled.</small></div>
    </div></div>
    <div class="stage-caption"><span>{study.concept}</span><span class="caption-right">DRAG TO COMPOSE / CTRL + SCROLL TO ZOOM</span></div>
    <Timeline editor={editor} />
  </section>;
}
