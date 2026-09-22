import { DEFAULT, PRESETS, PALETTES, SCENES, FINISHES, RANGES, STORAGE_KEY, preset, nextSeed, validateSettings, documentFor, parseDocument, History } from './model.js';
import { cssOklch } from './color.js';
import { readPngProject } from './binary.js';
import { createRenderer } from './gpu/renderer.js';
import { download, exportStill, exportSequence } from './export.js';

const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => [...document.querySelectorAll(selector)];
const clamp = (n, min, max) => Math.min(max, Math.max(min, n));
let state = structuredClone(DEFAULT), selected = 'the-gift', renderer = null, playing = false, exporting = false;
let dirty = true, lastFrame = 0, raf = 0, frameCounter = 0, cadenceStart = 0, quality = 'balanced';
let persistTimer = 0, toastTimer = 0, abort = null, connecting = false;
let startupWarning = '';
try {
  const saved = location.hash.startsWith('#scene=') ? decodeURIComponent(location.hash.slice(7)) : localStorage.getItem(STORAGE_KEY);
  if (saved) state = parseDocument(saved).settings;
} catch (error) { startupWarning = `Saved scene was not loaded: ${error.message}`; }
const history = new History(state);
function toast(message) {
  $('#toast').textContent = message; $('#toast').hidden = false;
  clearTimeout(toastTimer); toastTimer = setTimeout(() => { $('#toast').hidden = true; }, 4500);
}
function persist() {
  clearTimeout(persistTimer);
  persistTimer = setTimeout(() => {
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(documentFor(state, renderer?.hash))); }
    catch { toast('Local storage is unavailable. Save a recipe to keep this scene.'); }
  }, 250);
}
function commit() { history.commit(state); updateHistory(); persist(); }
function updateHistory() { $('#undo').disabled = !history.past.length; $('#redo').disabled = !history.future.length; }
function invalidate() { dirty = true; if (!raf && !document.hidden && !exporting) raf = requestAnimationFrame(tick); }
function stopPlayback() { playing = false; $('#play').textContent = '▶'; $('#play').setAttribute('aria-label', 'Play animation'); $('#cadence').textContent = 'PAUSED'; lastFrame = 0; persist(); }
function updateModified() { $('#modified').hidden = JSON.stringify(state) === JSON.stringify(preset(selected)); }

function range(key, label, unit = '') {
  const [min, max, step] = RANGES[key];
  return `<div class="control"><div class="control-head"><label for="range-${key}">${label}</label><input class="value-input" aria-label="${label} value${unit ? ` (${unit})` : ''}" data-value="${key}" type="number" min="${min}" max="${max}" step="${step}" value="${state[key]}" /></div><input id="range-${key}" data-param="${key}" type="range" min="${min}" max="${max}" step="${step}" value="${state[key]}" title="Double-click to reset" /></div>`;
}
function section(name, content, suffix = '') { return `<section class="control-section"><h2>${name}<small>${suffix}</small></h2>${content}</section>`; }
function selector(key, label, options) { return `<div class="select-control"><label for="select-${key}">${label}</label><select id="select-${key}" data-select="${key}">${options.map((s, i) => `<option value="${i}"${state[key] === i ? ' selected' : ''}>${s}</option>`).join('')}</select></div>`; }
function colorControl(role, name) {
  const values = state.palette[role];
  return `<details class="color-details" data-color-details="${role}"><summary><span class="color-dot" data-color-swatch="${role}" style="--swatch:${cssOklch(values)}"></span>${name}</summary>${[['Lightness', 0, 1, 0.005], ['Chroma', 0, 0.4, 0.002], ['Hue', 0, 360, 1]].map(([label, min, max, step], index) => `<div class="control"><div class="control-head"><label for="color-${role}-${index}">${label}</label><input type="number" class="value-input" aria-label="${name} ${label} value" data-color="${role}" data-index="${index}" min="${min}" max="${max}" step="${step}" value="${values[index]}" /></div><input id="color-${role}-${index}" type="range" aria-label="${name} ${label}" data-color="${role}" data-index="${index}" min="${min}" max="${max}" step="${step}" value="${values[index]}" /></div>`).join('')}</details>`;
}
function renderControls() {
  const form = section('Structure', selector('scene', 'Form family', SCENES) + `<label class="control-help" for="seed">Seed</label><div class="seed-row"><input id="seed" aria-label="Seed" type="number" min="0" max="16777215" step="1" value="${state.seed}" /><button id="new-seed" aria-label="Generate next deterministic seed" title="Next variation">↗</button></div>` + range('twist', 'Torsion') + range('spread', 'Openness') + range('thickness', 'Shell thickness') + range('nodes', 'Local sources'), '01')
    + section('Composition', range('rotation', 'Rotation', 'degrees') + range('zoom', 'Scale') + range('panX', 'Position X') + range('panY', 'Position Y') + range('yaw', 'Orbit Y', 'degrees') + range('pitch', 'Orbit X', 'degrees'), '02')
    + '<p class="control-help">A seed changes the form, not its visual language. Drag the canvas to compose. Double-click a slider to reset it.</p>';
  const light = section('Material', range('roughness', 'Roughness') + range('metallic', 'Metallicity') + range('detail', 'Surface relief'), 'GGX')
    + section('Sources', range('power', 'Radiant power') + range('radius', 'Core radius') + range('keyAngle', 'Key-light angle') + range('fill', 'Fill ratio'), '1 / r²')
    + section('Participating medium', range('density', 'Extinction density') + range('anisotropy', 'Scattering direction') + range('turbulence', 'Density detail'), 'HG')
    + '<p class="control-help">Linear-light shading with finite source sampling and single scattering. The form is procedural, not a combustion simulation.</p>';
  const finish = section('Treatment', `<div class="finish-modes">${FINISHES.map((name, i) => `<button data-finish="${i}" aria-pressed="${state.finish === i}">${name}</button>`).join('')}</div><div id="print-controls"${state.finish === 0 ? ' hidden' : ''}>${range('spacing', 'Grid spacing')}${range('dotSize', 'Dot radius')}${range('dither', 'Dither mix')}</div>`, '03')
    + section('Palette', `<div class="palette-buttons">${Object.entries(PALETTES).map(([name, palette]) => `<button data-palette="${name}" class="palette-button" aria-label="${name} palette" title="${name}" style="--swatch:${cssOklch(palette.energy)}"></button>`).join('')}</div>${colorControl('background', 'Void')}${colorControl('metal', 'Matter')}${colorControl('energy', 'Fire')}`, 'OKLCH')
    + section('Optics', range('exposure', 'Exposure', 'stops') + range('contrast', 'Contrast') + range('bloom', 'Lens scattering') + range('bloomRadius', 'Scattering radius') + range('grain', 'Film grain') + range('vignette', 'Vignette'), 'LINEAR');
  $('#controls').innerHTML = `<div id="panel-form" role="tabpanel" aria-label="Form">${form}</div><div id="panel-light" role="tabpanel" aria-label="Light" hidden>${light}</div><div id="panel-finish" role="tabpanel" aria-label="Finish" hidden>${finish}</div>`;
  activateTab($('.inspector-tabs [aria-selected="true"]')?.dataset.tab || 'form');
}
function activateTab(name) {
  $$('.inspector-tabs button').forEach((button) => { const active = button.dataset.tab === name; button.setAttribute('aria-selected', String(active)); button.setAttribute('aria-controls', `panel-${button.dataset.tab}`); button.tabIndex = active ? 0 : -1; });
  for (const tab of ['form', 'light', 'finish']) $(`#panel-${tab}`).hidden = name !== tab;
}
function syncControls() {
  for (const input of $$('[data-param],[data-value],[data-select]')) {
    const key = input.dataset.param || input.dataset.value || input.dataset.select;
    if (input !== document.activeElement) input.value = String(state[key]);
  }
  if ($('#seed') !== document.activeElement) $('#seed').value = String(state.seed);
  for (const input of $$('[data-color]')) if (input !== document.activeElement) input.value = String(state.palette[input.dataset.color][Number(input.dataset.index)]);
  for (const swatch of $$('[data-color-swatch]')) swatch.style.setProperty('--swatch', cssOklch(state.palette[swatch.dataset.colorSwatch]));
  $$('[data-finish]').forEach((button) => button.setAttribute('aria-pressed', String(Number(button.dataset.finish) === state.finish)));
  $('#print-controls').hidden = state.finish === 0;
  updateTime(); updateModified(); updateHistory();
}
function updateTime() {
  $('#scrub').max = String(state.duration); $('#scrub').value = String(state.time % state.duration);
  $('#time-display').textContent = (state.time % state.duration).toFixed(3).padStart(6, '0');
  $('#duration-display').textContent = `${state.duration.toFixed(3)} s`; $('#loop-label').textContent = `${state.duration}s`;
}
function changePreset(id) {
  stopPlayback(); selected = id; state = preset(id); commit(); syncControls();
  const index = PRESETS.findIndex((p) => p.id === id), p = PRESETS[index];
  $('#study-number').textContent = String(index + 1).padStart(2, '0'); $('#study-title').textContent = p.name; $('#concept').textContent = p.concept;
  $('#poster').src = `/presets/${id}.png`;
  $$('.preset-card').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.preset === id)));
  delete document.body.dataset.panel; invalidate();
}
$('#presets').innerHTML = PRESETS.map((p, i) => `<button class="preset-card" data-preset="${p.id}" aria-pressed="${p.id === selected}"><img src="/presets/${p.id}.png" alt="" loading="lazy" /><span><span class="preset-name">${p.name}</span><small>${String(i + 1).padStart(2, '0')} / ${FINISHES[p.settings.finish || 0].toUpperCase()}</small></span></button>`).join('');
renderControls(); syncControls();
$('#presets').addEventListener('click', (event) => { const card = event.target.closest('[data-preset]'); if (card) changePreset(card.dataset.preset); });
$('.inspector-tabs').addEventListener('click', (event) => { const button = event.target.closest('[data-tab]'); if (button) activateTab(button.dataset.tab); });
$('.inspector-tabs').addEventListener('keydown', (event) => {
  if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return;
  const buttons = $$('.inspector-tabs button'); let index = buttons.indexOf(document.activeElement);
  index = event.key === 'Home' ? 0 : event.key === 'End' ? 2 : (index + (event.key === 'ArrowRight' ? 1 : 2)) % 3;
  activateTab(buttons[index].dataset.tab); buttons[index].focus(); event.preventDefault();
});
$('#controls').addEventListener('input', (event) => {
  const el = event.target; let value = Number(el.value); if (!Number.isFinite(value)) return;
  if (el.dataset.param || el.dataset.value || el.dataset.select || el.id === 'seed') {
    const key = el.dataset.param || el.dataset.value || el.dataset.select || 'seed';
    const [min, max, step] = RANGES[key]; value = clamp(value, min, max); if (step === 1) value = Math.round(value);
    state[key] = value;
  } else if (el.dataset.color) {
    state.palette[el.dataset.color][Number(el.dataset.index)] = clamp(value, Number(el.min), Number(el.max));
  } else return;
  syncControls(); invalidate();
});
$('#controls').addEventListener('change', () => { commit(); syncControls(); });
$('#controls').addEventListener('dblclick', (event) => {
  const key = event.target.dataset.param;
  if (key) { state[key] = preset(selected)[key]; commit(); syncControls(); invalidate(); }
});
$('#controls').addEventListener('click', (event) => {
  const button = event.target.closest('button'); if (!button) return;
  if (button.id === 'new-seed') state.seed = nextSeed(state.seed);
  else if (button.dataset.finish !== undefined) state.finish = Number(button.dataset.finish);
  else if (button.dataset.palette) state.palette = structuredClone(PALETTES[button.dataset.palette]);
  else return;
  commit(); syncControls(); invalidate();
});
$('#undo').onclick = () => { stopPlayback(); state = history.undo(); syncControls(); persist(); invalidate(); };
$('#redo').onclick = () => { stopPlayback(); state = history.redo(); syncControls(); persist(); invalidate(); };
$('#reset').onclick = () => changePreset(selected);
$('#play').onclick = () => {
  if (!renderer || exporting) return;
  if (playing) { stopPlayback(); commit(); } else { playing = true; lastFrame = 0; cadenceStart = performance.now(); frameCounter = 0; $('#play').textContent = 'Ⅱ'; $('#play').setAttribute('aria-label', 'Pause animation'); invalidate(); }
};
$('#scrub').oninput = () => { stopPlayback(); state.time = Number($('#scrub').value); updateTime(); updateModified(); invalidate(); };
$('#scrub').onchange = commit;
$('#loop-length').onclick = () => {
  const input = prompt('Loop duration in seconds (2 to 60)', String(state.duration));
  if (input === null) return; const value = Number(input);
  if (!Number.isInteger(value) || value < 2 || value > 60) { toast('Use a whole number from 2 to 60.'); return; }
  stopPlayback(); state.duration = value; state.time %= value; commit(); syncControls(); invalidate();
};
$('#quality').onchange = () => { quality = $('#quality').value; invalidate(); };
function tick(now) {
  raf = 0; if (document.hidden || exporting || !renderer) return;
  if (playing) {
    if (lastFrame) state.time = (state.time + Math.min((now - lastFrame) / 1000, 0.1)) % state.duration;
    lastFrame = now; dirty = true; updateTime(); frameCounter++;
    if (now - cadenceStart >= 1000) { $('#cadence').textContent = `${Math.round(frameCounter * 1000 / (now - cadenceStart))} FPS · CADENCE`; cadenceStart = now; frameCounter = 0; }
  }
  if (dirty) {
    const rect = $('#stage').getBoundingClientRect();
    const maxHeight = { draft: 360, balanced: 640, final: 1080 }[quality];
    const height = Math.max(64, Math.round(Math.min(rect.height * Math.min(devicePixelRatio || 1, 1.5), maxHeight)));
    const width = Math.max(64, Math.round(height * rect.width / Math.max(1, rect.height)));
    try { renderer.drawPreview(state, width, height, quality); dirty = false; $('#resolution-label').textContent = `${width} × ${height}`; }
    catch (error) { failGPU(error); return; }
  }
  if (playing) raf = requestAnimationFrame(tick);
}
new ResizeObserver(invalidate).observe($('#stage'));
document.addEventListener('visibilitychange', () => { if (document.hidden) { if (raf) cancelAnimationFrame(raf); raf = 0; lastFrame = 0; } else invalidate(); });
let drag = null;
$('#canvas').addEventListener('pointerdown', (e) => { if (exporting) return; drag = { x: e.clientX, y: e.clientY, sx: state.panX, sy: state.panY }; e.target.setPointerCapture(e.pointerId); });
$('#canvas').addEventListener('pointermove', (e) => {
  if (!drag) return;
  const rect = $('#canvas').getBoundingClientRect();
  state.panX = clamp(drag.sx + 4 * (e.clientX - drag.x) / rect.height, -1.8, 1.8);
  state.panY = clamp(drag.sy - 4 * (e.clientY - drag.y) / rect.height, -1.8, 1.8);
  syncControls(); invalidate();
});
function endDrag() { if (drag) { drag = null; commit(); } }
$('#canvas').addEventListener('pointerup', endDrag); $('#canvas').addEventListener('pointercancel', endDrag);
$('#canvas').addEventListener('wheel', (e) => { if (!e.ctrlKey || exporting) return; e.preventDefault(); state.zoom = clamp(state.zoom * Math.exp(-e.deltaY * 0.002), 0.65, 2); syncControls(); commit(); invalidate(); }, { passive: false });
$('#fullscreen').onclick = async () => {
  try { if (document.fullscreenElement) await document.exitFullscreen(); else await $('#stage').requestFullscreen(); }
  catch { toast('Fullscreen is unavailable in this browser.'); }
};
$$('[data-panel]').forEach((button) => { button.onclick = () => { document.body.dataset.panel = document.body.dataset.panel === button.dataset.panel ? '' : button.dataset.panel; }; });
document.addEventListener('keydown', (event) => {
  if ($('dialog[open]') || /INPUT|TEXTAREA|SELECT/.test(event.target.tagName)) return;
  if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'z') { event.preventDefault(); (event.shiftKey ? $('#redo') : $('#undo')).click(); }
  if (event.code === 'Space') { event.preventDefault(); $('#play').click(); }
  if (event.key === 'Escape') delete document.body.dataset.panel;
});
function currentDocument() { return documentFor(state, renderer?.hash); }
function saveRecipe() { const doc = currentDocument(); download(new Blob([JSON.stringify(doc, null, 2)], { type: 'application/json' }), `hyalos-${selected}-s${state.seed}.hyalos.json`); }
$('#save-recipe').onclick = saveRecipe;
$('#open-project').onclick = () => $('#project-file').click();
$('#project-file').onchange = async () => {
  const file = $('#project-file').files?.[0]; if (!file) return;
  try {
    if (file.size > 64 * 1024 * 1024) throw new Error('File exceeds the 64 MiB import budget.');
    const text = file.name.toLowerCase().endsWith('.png') ? readPngProject(new Uint8Array(await file.arrayBuffer())) : await file.text();
    const doc = parseDocument(text); stopPlayback(); state = doc.settings; commit(); syncControls(); invalidate();
    toast(doc.shaderHash && renderer && doc.shaderHash !== renderer.hash ? 'Recipe opened. Its shader revision differs from this build.' : 'Recipe restored. Playback is paused.');
  } catch (error) { toast(error.message); }
  finally { $('#project-file').value = ''; }
};
$('#copy-link').onclick = async () => {
  try { const url = new URL(location.href); url.hash = `scene=${encodeURIComponent(JSON.stringify(currentDocument()))}`; await navigator.clipboard.writeText(url.toString()); toast('Scene link copied. No project was uploaded.'); }
  catch { toast('Clipboard unavailable. Use Save this variation instead.'); }
};
$('#about').onclick = () => $('#about-dialog').showModal(); $('#close-about').onclick = () => $('#about-dialog').close();
$('#open-export').onclick = () => { stopPlayback(); updateExportUI(); $('#export-dialog').showModal(); };
$('#close-export').onclick = () => { if (!exporting) $('#export-dialog').close(); };
$('#export-dialog').addEventListener('cancel', (e) => { if (exporting) { e.preventDefault(); abort?.abort(); } });
$('#cancel-render').onclick = () => abort?.abort();
function exportSize() {
  return $('#export-size').value === 'custom' ? [Number($('#export-width').value), Number($('#export-height').value)] : $('#export-size').value.split(',').map(Number);
}
function updateExportUI() {
  const type = $('#export-format').value, [w, h] = exportSize();
  $('#custom-size').hidden = $('#export-size').value !== 'custom'; $('#sequence-options').hidden = type !== 'sequence';
  $('#export-summary').textContent = type === 'project' ? 'REPRODUCIBLE RECIPE' : `${w} × ${h} / sRGB`;
  $('#export-submit').textContent = type === 'project' ? 'Save recipe ↓' : type === 'sequence' ? 'Export frames ↗' : type === 'image/png' ? 'Export PNG ↗' : 'Export ZIP ↗';
  $('#export-submit').disabled = exporting || (!renderer && type !== 'project');
  $('#export-note').textContent = type === 'sequence' ? 'Exact-time PNG frames, up to 1080p and 600 frames. An FFmpeg command is included. Rendering can take several minutes.' : type === 'project' ? 'Contains every parameter, OKLCH palette, seed, time and shader fingerprint.' : 'Final-quality light transport. Tiled readback keeps GPU memory bounded.';
}
$('#export-format').onchange = updateExportUI; $('#export-size').onchange = updateExportUI; $('#export-width').oninput = updateExportUI; $('#export-height').oninput = updateExportUI;
function setExporting(value) {
  exporting = value; $('#workspace').inert = value; $('#close-export').disabled = value;
  $('#cancel-render').hidden = !value; $('#export-progress').hidden = !value;
  for (const element of $$('#export-form input,#export-form select')) element.disabled = value;
  updateExportUI(); if (!value) invalidate();
}
$('#export-form').onsubmit = async (event) => {
  event.preventDefault(); const type = $('#export-format').value;
  if (type === 'project') { saveRecipe(); $('#export-dialog').close(); return; }
  if (!renderer || exporting) return;
  $('#export-error').hidden = true; abort = new AbortController(); stopPlayback();
  const snapshot = structuredClone(state), [w, h] = exportSize(); const fps = Number($('#export-fps').value), seconds = Number($('#export-seconds').value);
  setExporting(true); $('#progress').value = 0;
  try {
    const options = { signal: abort.signal, onProgress(p) { $('#progress').value = p; $('#progress-label').textContent = `Rendering ${Math.floor(p * 100)}%`; } };
    const blob = type === 'sequence' ? await exportSequence(renderer, snapshot, w, h, fps, seconds, options) : await exportStill(renderer, snapshot, w, h, type, options);
    if (abort.signal.aborted) throw new DOMException('Export cancelled.', 'AbortError');
    const ext = type === 'image/png' ? 'png' : 'zip';
    download(blob, `hyalos-${selected}-s${snapshot.seed}-${w}x${h}.${ext}`);
    $('#export-dialog').close(); toast('Export ready. Your scene has not changed.');
  } catch (error) { $('#export-error').textContent = error.name === 'AbortError' ? 'Export cancelled. Your scene is unchanged.' : error.message; $('#export-error').hidden = false; }
  finally { abort = null; setExporting(false); }
};
function failGPU(error) {
  stopPlayback(); if (raf) cancelAnimationFrame(raf); raf = 0;
  renderer?.dispose(); renderer = null;
  $('#loading').hidden = true; $('#gpu-error').hidden = false; $('#gpu-error-message').textContent = error.message || String(error);
  $('#gpu-label').textContent = 'OFFLINE PREVIEW'; $('#inspector-state').textContent = 'LOCAL'; $('#gpu-dot').classList.remove('ready'); $('#play').disabled = true; $('#poster').hidden = false; $('#canvas').hidden = true;
  if (exporting) abort?.abort();
}
async function connect() {
  if (connecting) return false;
  connecting = true; $('#retry').disabled = true;
  $('#loading').hidden = false; $('#gpu-error').hidden = true;
  try {
    renderer = await createRenderer($('#canvas'), failGPU);
    $('#loading').hidden = true; $('#poster').hidden = true; $('#canvas').hidden = false;
    $('#gpu-label').textContent = 'WEBGPU / VGPU'; $('#inspector-state').textContent = 'LIVE'; $('#gpu-dot').classList.add('ready'); $('#play').disabled = false;
    $('#shader-version').textContent = `HYALOS / V1 · ${renderer.hash.slice(0, 8)}`; $('#about-hash').textContent = `Shader SHA-256: ${renderer.hash}`;
    invalidate(); return true;
  } catch (error) { failGPU(error); return false; }
  finally { connecting = false; $('#retry').disabled = false; }
}
$('#retry').onclick = connect;
window.addEventListener('pagehide', () => { abort?.abort(); if (raf) cancelAnimationFrame(raf); raf = 0; renderer?.dispose(); renderer = null; });
window.addEventListener('pageshow', (event) => { if (event.persisted) connect(); });
// Readable local agent API, inspired by Taxis. No endpoint or hidden network work.
const ready = connect();
window.hyalos = Object.freeze({
  ready,
  getScene() { return currentDocument(); },
  setScene(document) { if (exporting) throw new Error('An export is active.'); const value = parseDocument(JSON.stringify(document)); stopPlayback(); state = value.settings; commit(); syncControls(); invalidate(); },
  setParameters(patch) { if (exporting) throw new Error('An export is active.'); stopPlayback(); state = validateSettings({ ...state, ...patch }); commit(); syncControls(); invalidate(); },
  async exportPNG(width = 1920, height = 1080) {
    if (!renderer || exporting) throw new Error('Renderer unavailable or busy.'); stopPlayback(); setExporting(true);
    try { return await exportStill(renderer, structuredClone(state), width, height, 'image/png'); }
    finally { setExporting(false); }
  },
  capabilities() { return { webgpu: !!renderer, renderer: 'vgpu', shaderHash: renderer?.hash || null, maxImagePixels: 33554432, previewQuality: quality, exporting }; },
});
if (startupWarning) toast(startupWarning);
