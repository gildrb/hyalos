import { useEffect, useRef, useState } from 'preact/hooks';
import type { ComponentChildren } from 'preact';
import { Editor, messageOf } from '../editor.ts';
import { download } from '../export.ts';
import type { ImageFormat } from '../types.ts';
import { Icon } from './Icon.tsx';

function Dialog({ open, onClose, busy = false, titleId, children }: { open: boolean; onClose: () => void; busy?: boolean; titleId: string; children: ComponentChildren }) {
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const node = ref.current;
    if (open && node && !node.open) node.showModal();
    else if (!open && node?.open) node.close();
  }, [open]);
  return <dialog ref={ref} aria-labelledby={titleId} onCancel={e => { e.preventDefault(); if (!busy) onClose(); }} onClose={() => { if (!busy) onClose(); }}>{children}</dialog>;
}
export function ExportDialog({ editor, open, onClose, notify }: { editor: Editor; open: boolean; onClose: () => void; notify: (text: string) => void }) {
  const [format, setFormat] = useState<ImageFormat | 'project' | 'sequence'>('image/png');
  const [size, setSize] = useState('1920,1080'), [width, setWidth] = useState(1920), [height, setHeight] = useState(1080);
  const [fps, setFps] = useState(24), [seconds, setSeconds] = useState(5), [progress, setProgress] = useState(0), [error, setError] = useState('');
  useEffect(() => { if (open) { setError(''); editor.stop(); } }, [open, editor]);
  const dimensions = size === 'custom' ? [width, height] : size.split(',').map(Number);
  return <Dialog open={open} onClose={onClose} busy={editor.busy} titleId="export-heading">
    <form id="export-form" onSubmit={async e => {
      e.preventDefault(); setError('');
      if (format === 'project') { editor.saveRecipe(); onClose(); return; }
      const [w, h] = dimensions;
      const filename = `hyalos-${editor.selected}-s${editor.settings.seed}-${w}x${h}.${format === 'image/png' ? 'png' : 'zip'}`;
      setProgress(0);
      try { const blob = await editor.exportImage(w, h, format, { fps, seconds, onProgress: setProgress }); download(blob, filename); onClose(); notify('Export ready. The recipe is preserved.'); }
      catch (error) { setError(messageOf(error)); }
    }}>
      <div class="dialog-heading"><div><span class="eyebrow">TAKE IT WITH YOU</span><h1 id="export-heading">Export the study.</h1></div><button type="button" class="close-button" aria-label="Close export" disabled={editor.busy} onClick={onClose}><Icon name="close" /></button></div>
      <p class="dialog-copy">The visual only. No interface, no watermark.<br />PNG files carry their recipe inside.</p>
      <fieldset class="export-fields" disabled={editor.busy}>
        <label class="field">Format<select id="export-format" value={format} onChange={e => setFormat(e.currentTarget.value as typeof format)}><option value="image/png">PNG / image + embedded recipe</option><option value="image/webp">WebP + recipe / ZIP</option><option value="image/jpeg">JPEG + recipe / ZIP</option><option value="sequence">PNG sequence / ZIP</option><option value="project">Recipe / JSON</option></select></label>
        <label class="field" hidden={format === 'project'}>Dimensions<select value={size} onChange={e => setSize(e.currentTarget.value)}>{[['1920,1080', 'Landscape / 1920 x 1080'], ['3840,2160', '4K / 3840 x 2160'], ['7680,4320', '8K / 7680 x 4320'], ['2048,2048', 'Square / 2048 x 2048'], ['1080,1920', 'Portrait / 1080 x 1920'], ['1500,500', 'Social header / 1500 x 500'], ['custom', 'Custom']].map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></label>
        <div class="field-row" hidden={size !== 'custom' || format === 'project'}><label class="field">Width<input type="number" disabled={size !== 'custom' || format === 'project'} min={64} max={8192} value={width} onInput={e => setWidth(Number(e.currentTarget.value))} /></label><label class="field">Height<input type="number" disabled={size !== 'custom' || format === 'project'} min={64} max={8192} value={height} onInput={e => setHeight(Number(e.currentTarget.value))} /></label></div>
        <div class="field-row" hidden={format !== 'sequence'}><label class="field">Frames per second<input type="number" disabled={format !== 'sequence'} min={1} max={60} value={fps} onInput={e => setFps(Number(e.currentTarget.value))} /></label><label class="field">Seconds<input type="number" disabled={format !== 'sequence'} min={1} max={60} value={seconds} onInput={e => setSeconds(Number(e.currentTarget.value))} /></label></div>
      </fieldset>
      <p class="export-note">{format === 'project' ? 'Every parameter, OKLCH palette, seed, time and shader fingerprint.' : format === 'sequence' ? 'Exact-time PNG frames, up to 1080p and 600 frames. An FFmpeg command is included.' : 'Final-quality light transport. Tiled readback keeps GPU memory bounded.'}</p>
      {editor.status !== 'ready' && format !== 'project' && <p class="error-text">Live rendering is unavailable. You can still save a JSON recipe.</p>}
      <div class="export-progress" hidden={!editor.busy}><progress max={1} value={progress} /><span>Rendering {Math.floor(progress * 100)}%</span></div>
      <p class="error-text" role="alert" hidden={!error}>{error}</p>
      <div class="dialog-actions"><span>{format === 'project' ? 'REPRODUCIBLE RECIPE' : `${dimensions[0]} x ${dimensions[1]} / sRGB`}</span>{editor.busy && <button type="button" class="outline-button" onClick={() => editor.cancelExport()}>Cancel render</button>}<button type="submit" class="primary" id="export-submit" disabled={editor.busy || (editor.status !== 'ready' && format !== 'project')}>{format === 'project' ? 'Save recipe' : 'Export'}<Icon name="download" /></button></div>
    </form>
  </Dialog>;
}
export function AboutDialog({ editor, open, onClose }: { editor: Editor; open: boolean; onClose: () => void }) {
  return <Dialog open={open} onClose={onClose} titleId="about-heading"><div class="dialog-heading"><div><span class="eyebrow">THE RENDERER</span><h1 id="about-heading">Light, not a filter.</h1></div><button class="close-button" aria-label="Close information" onClick={onClose}><Icon name="close" /></button></div><p>WGSL runs through vGPU directly on WebGPU. GGX microfacet shading, inverse-square light sources, visibility queries and single-scattering integration light the procedural forms.</p><p>These are finite-budget approximations, not simulated combustion, indirect-bounce path tracing or a physically exact solver.</p><p>Colors are authored in OKLCH, converted to linear light, then display-encoded once. Noise and dithering ports retain their MIT notices.</p><p>A fixed seed, recipe, time and shader revision reproduce a study on the same renderer. Cross-GPU floating-point results can differ.</p><small>Shader SHA-256: {editor.hash ?? 'Not compiled'}</small></Dialog>;
}
