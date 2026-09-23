import { ORB_PREVIEWS } from './orbs/previews.ts';
import { ORB_CATALOG } from './orbs/catalog.ts';
import { useEffect, useRef, useState } from 'preact/hooks';
import { normalizeControls, DEFAULT_CONTROLS, FINISH_RANGES, type FinishControl, SHAPES, GLASS_TINTS, LIGHT_RIG_NAMES, RENDER_SCALES, type SculptureControls } from './controls.ts';
import { initialSculpture, parseSculpture, STUDIO_STORAGE, type SculptureRecipe } from './model.ts';
import type { SculptureRenderer } from './renderer.ts';
import { download } from '../export.ts';
import { readPngProject } from '../binary.ts';
import './studio.css';

const label = (value: string) => value === 'mobius' ? 'Möbius' : value[0].toUpperCase() + value.slice(1);
const finishLabels: Record<FinishControl,string> = { bloom: 'Bloom', glowRadius: 'Glow spread', grain: 'Grain', texture: 'Scan texture', coolness: 'Color grade', metalness: 'Silver reflection', exposure: 'Exposure' };
export function StudioApp() {
  const canvas = useRef<HTMLCanvasElement>(null), fileInput = useRef<HTMLInputElement>(null), renderer = useRef<SculptureRenderer>();
  const initial = useRef<SculptureRecipe>();
  if (!initial.current) {
    try { const saved = localStorage.getItem(STUDIO_STORAGE); initial.current = saved ? parseSculpture(saved) : initialSculpture(); if(!saved && window.matchMedia('(prefers-reduced-motion: reduce)').matches){initial.current.controls.spin=false;initial.current.controls.orbAnimate=false;} }
    catch { initial.current = initialSculpture(); }
  }
  const beforeReset = useRef<SculptureRecipe>();
  const [canUndoReset, setCanUndoReset] = useState(false);
  const [galleryOpen, setGalleryOpen] = useState(false);
  const [controls, setControls] = useState(initial.current.controls);
  const selectedOrb=ORB_CATALOG.find(item=>item.key===controls.orb);
  const [status, setStatus] = useState<'loading' | 'ready' | 'error'>('loading');
  const [error, setError] = useState(''), [notice, setNotice] = useState(''), [saving, setSaving] = useState(false), [connection, setConnection] = useState(0);
  const persist = (recipe: SculptureRecipe) => { try { localStorage.setItem(STUDIO_STORAGE, JSON.stringify(recipe)); } catch { /* Saving a file remains available. */ } };
  useEffect(() => {
    let cancelled = false, failed = false;
    setStatus('loading'); setError('');
    const fail = (error: unknown) => { failed = true; if (!cancelled) { setStatus('error'); setError(error instanceof Error ? error.message : String(error)); } };
    void import('./renderer.ts').then(async ({ createSculptureRenderer }) => {
      if (cancelled || !canvas.current) return;
      const instance = createSculptureRenderer(canvas.current, initial.current!, fail);
      renderer.current = instance;
      await instance.ready;
      if (!cancelled && !failed) setStatus('ready');
    }).catch(fail);
    const save = () => { if (renderer.current) { initial.current = renderer.current.snapshot(); persist(initial.current); } };
    const saveTimer = window.setInterval(save, 1500);
    window.addEventListener('pagehide', save);
    return () => { cancelled = true; window.clearInterval(saveTimer); window.removeEventListener('pagehide', save); save(); try { renderer.current?.dispose(); } catch (error) { console.error(error); } renderer.current = undefined; };
  }, [connection]);
  const update = (patch: Partial<SculptureControls>) => {
    setCanUndoReset(false);
    const next = normalizeControls({ ...controls, ...patch });
    setControls(next); renderer.current?.setControls(next);
    if (renderer.current) { initial.current = renderer.current.snapshot(); persist(initial.current); }
    else { initial.current = { ...initial.current!, controls: next }; persist(initial.current); }
  };
  const setOrbValue = (key: string, value: number | string) => {
    const stored=controls.orbValues[controls.orb] ?? {};
    const group=typeof value==='number' ? 'params' : 'colors';
    update({orbValues:{...controls.orbValues,[controls.orb]:{...stored,[group]:{...stored[group],[key]:value}}}});
  };
  const choose = (shape: SculptureControls['shape']) => update({ shape });
  const reset = () => {
    const current = renderer.current?.snapshot() ?? initial.current!;
    const next = { ...current, camera: initialSculpture().camera };
    initial.current = next; renderer.current?.restore(next); persist(next);
  };
  const restoreAll = (recipe: SculptureRecipe) => {
    initial.current = structuredClone(recipe);
    setControls(initial.current.controls);
    renderer.current?.restore(initial.current);
    persist(initial.current);
  };
  const resetAll = () => {
    beforeReset.current = renderer.current?.snapshot() ?? structuredClone(initial.current!);
    restoreAll(initialSculpture());
    setCanUndoReset(true);
    setNotice('All settings restored to defaults.');
  };
  return <div class="editor glass-editor">
    <a class="glass-skip" href="#sculpture-controls">Skip to sculpture controls</a>
    <header class="topbar">
      <a class="brand" href="./">Hyalos</a>
      <span class="glass-workspace-name">Glass Sculptures</span>
      <div class="header-actions">
        <button class="text-button" disabled={saving} title="Reset scene, camera, colors, materials, effects and export size" onClick={resetAll}>Reset all</button>
        {canUndoReset && <button class="text-button" disabled={saving} onClick={()=>{if(beforeReset.current)restoreAll(beforeReset.current);setCanUndoReset(false);setNotice('Previous scene restored.');}}>Undo reset</button>}
        <button class="text-button" disabled={saving} onClick={() => fileInput.current?.click()}>Open recipe</button>
        <button class="text-button" onClick={() => { const recipe = renderer.current?.snapshot() ?? initial.current!; download(new Blob([JSON.stringify(recipe, null, 2)], { type: 'application/json' }), `hyalos-glass-${controls.shape}.hyalos.json`); setNotice('Recipe saved.'); }}>Save recipe</button>
        {saving && <button class="text-button" onClick={() => renderer.current?.cancelExport()}>Cancel export</button>}
        <button class="primary" disabled={status !== 'ready' || saving} onClick={async () => {
          setSaving(true); setNotice('Rendering full-resolution PNG…');
          try { const image = await renderer.current!.exportPNG(value => setNotice(`Rendering PNG · ${Math.round(value*100)}%`)); download(image, `hyalos-glass-${controls.shape}-${controls.exportWidth}x${controls.exportHeight}.png`); setNotice('PNG saved with its recipe.'); }
          catch (error) { setNotice(error instanceof Error ? error.message : String(error)); }
          finally { setSaving(false); }
        }}>{saving ? 'Saving…' : 'Save PNG'}</button>
      </div>
    </header>
    <main class="glass-workspace">
      <section class="glass-view" aria-label="Glass sculpture canvas">
        <div class="glass-view-toolbar"><span><strong>{label(controls.shape)}</strong><span class="glass-view-subtitle"> / {label(controls.glass)} glass</span></span><span class="glass-live" role="status">{status === 'ready' ? 'Live · WebGPU' : status === 'loading' ? 'Preparing WebGPU…' : 'Renderer unavailable'}</span></div>
        <div class="glass-canvas-host"><div class="glass-canvas-wrap" style={{ '--ratio': controls.exportWidth / controls.exportHeight }}>
          <canvas ref={canvas} tabIndex={0} aria-describedby="canvas-help" class="glass-canvas" aria-label="Interactive Glass Sculpture. Drag or use arrow keys to orbit. Scroll or use plus and minus to zoom." />
          {status === 'loading' && <div class="glass-message" role="status">Preparing the Glass Sculpture renderer…</div>}
          {status === 'error' && <div class="glass-message" role="alert"><strong>Rendering unavailable</strong><p>{error}</p><button class="outline-button" onClick={() => setConnection(n => n + 1)}>Reconnect</button></div>}
        </div>
        </div>
        <div class="glass-canvas-footer"><span id="canvas-help">Drag or use arrow keys to orbit · Scroll or +/− to zoom</span><button class="text-button" disabled={saving} onClick={reset}>Reset view</button></div>
      </section>
      <aside id="sculpture-controls" tabIndex={-1} class="glass-inspector" aria-label="Sculpture controls">
        <div class="panel-header">Sculpture</div>
        <fieldset disabled={saving} class="glass-fields">
          <label class="glass-field">Shape<select aria-label="Shape" value={controls.shape} onChange={e => choose(e.currentTarget.value as SculptureControls['shape'])}>{SHAPES.map(s => <option key={s} value={s}>{label(s)}</option>)}</select></label>
          <div class="glass-shape-picker">{SHAPES.map(shape => <button key={shape} aria-pressed={controls.shape === shape} onClick={() => choose(shape)}><span class={`glass-shape-symbol ${shape}`} aria-hidden="true" />{label(shape)}</button>)}</div>
          <details class="glass-orbs" open>
            <summary>Orb material</summary>
            <label class="glass-field">Shader preset<select aria-label="Orb shader" value={controls.orb} onChange={e=>update({orb:e.currentTarget.value})}>
              <option value="none">Glass · no orb shader</option>
              {ORB_CATALOG.map(orb=><option key={orb.key} value={orb.key}>{orb.label} · {orb.note}</option>)}
            </select></label>
            <details class="orb-gallery" onToggle={e=>setGalleryOpen(e.currentTarget.open)}><summary>Browse all 33 orbs</summary><div class="orb-gallery-grid">{galleryOpen && ORB_CATALOG.map(orb=><button key={orb.key} type="button" title={orb.note} aria-label={`Apply ${orb.label}`} aria-pressed={controls.orb===orb.key} onClick={()=>update({orb:orb.key})}><img src={ORB_PREVIEWS[orb.key]} loading="lazy" decoding="async" width="192" height="192" alt=""/><span>{orb.label}</span></button>)}</div></details>
            {selectedOrb && <>
              <p class="glass-help">{selectedOrb.note}</p>
              <label class="glass-field">Apply as<select aria-label="Orb application" value={controls.orbMode} onChange={e=>update({orbMode:e.currentTarget.value as SculptureControls['orbMode']})}><option value="surface">Surface material</option><option value="emission">Emissive layer</option><option value="reflection">Reflected environment</option></select></label>
              <label class="glass-field">Mapping<select aria-label="Orb mapping" value={controls.orbMapping} disabled={controls.orbMode==='reflection'} onChange={e=>update({orbMapping:e.currentTarget.value as SculptureControls['orbMapping']})}><option value="triplanar">Object projection</option><option value="normal">Normal projection</option><option value="screen">Camera projection</option></select></label>
              <label class="glass-range"><span>Material strength<output>{controls.orbStrength.toFixed(2)}</output></span><input aria-label="Material strength" type="range" min="0" max="2" step="0.01" value={controls.orbStrength} onInput={e=>update({orbStrength:Number(e.currentTarget.value)})}/></label>
              <label class="glass-range"><span>Pattern scale<output>{controls.orbScale.toFixed(2)}</output></span><input aria-label="Pattern scale" disabled={controls.orbMode==='reflection'} type="range" min="0.25" max="3" step="0.01" value={controls.orbScale} onInput={e=>update({orbScale:Number(e.currentTarget.value)})}/></label>
              <label class="glass-finish-enable"><span>Animate material</span><input aria-label="Animate material" type="checkbox" checked={controls.orbAnimate} onChange={e=>update({orbAnimate:e.currentTarget.checked})}/></label>
              <label class="glass-field">Animation state<select aria-label="Orb animation state" value={controls.orbState} onChange={e=>update({orbState:e.currentTarget.value as SculptureControls['orbState']})}><option value="idle">Idle</option><option value="thinking">Thinking</option><option value="speaking">Speaking</option></select></label>
              <details class="orb-parameters"><summary>{selectedOrb.label} parameters</summary>
                {selectedOrb.params.map(parameter=>{
                  const value=controls.orbValues[controls.orb]?.params?.[parameter.key] ?? selectedOrb.statePresets?.[controls.orbState]?.[parameter.key] ?? parameter.default;
                  return <label class="glass-range" key={parameter.key}><span>{parameter.label}<output>{Number(value.toFixed(3))}</output></span><input aria-label={`Orb ${parameter.label}`} type="range" min={parameter.min} max={parameter.max} step={parameter.step} value={value} onInput={e=>setOrbValue(parameter.key,Number(e.currentTarget.value))}/></label>;
                })}
                {selectedOrb.colors.map(color=><label class="glass-orb-color" key={color.key}>{color.label}<input type="color" aria-label={`Orb ${color.label}`} value={controls.orbValues[controls.orb]?.colors?.[color.key] ?? selectedOrb.stateColors?.[controls.orbState]?.[color.key] ?? color.default} onInput={e=>setOrbValue(color.key,e.currentTarget.value)}/></label>)}
                <button class="text-button" onClick={()=>update({orbValues:{...controls.orbValues,[controls.orb]:{params:{},colors:{}}}})}>Reset orb parameters</button>
              </details>
              <p class="glass-help">Maps the original orb animation onto your sculpture. Each orb keeps its own parameter settings.</p>
              <a class="glass-orb-credit" href="https://www.shadercn.run/" target="_blank" rel="noreferrer">shadercn · XorDev · non-commercial ↗</a>
            </>}
          </details>
          <details class="glass-surface" open><summary>Surface &amp; quality</summary>
            <div class="glass-environment-presets">
              <button class="text-button" onClick={()=>update({metalness:0,roughness:0.08,dispersionAmount:0.002})}>Glass</button>
              <button class="text-button" onClick={()=>update({metalness:0.65,roughness:0.18,dispersionAmount:0.002})}>Polished</button>
              <button class="text-button" onClick={()=>update({metalness:1,roughness:0.28})}>Chrome</button>
            </div>
            <label class="glass-field">Spatial sampling<select aria-label="Spatial sampling" value={controls.samples} onChange={e=>update({samples:Number(e.currentTarget.value) as 1|4})}><option value="1">Interactive · 1 ray per pixel</option><option value="4">Refined · 4 rays per pixel</option></select></label>
            {([{key:'roughness',label:'Surface roughness',min:0,max:0.7,step:0.01},{key:'edgeSoftness',label:'Model edge softness',min:0.001,max:0.15,step:0.001},{key:'dispersionAmount',label:'Dispersion amount',min:0,max:0.02,step:0.0005}] as const).map(field=><label class="glass-range" key={field.key}><span>{field.label}<output>{controls[field.key].toFixed(3)}</output></span><input aria-label={field.label} type="range" min={field.min} max={field.max} step={field.step} value={controls[field.key]} disabled={(field.key==='edgeSoftness' && !['gyroid','schwarz','prism','helix','vesper'].includes(controls.shape)) || (field.key==='dispersionAmount' && !controls.dispersion)} onInput={e=>update({[field.key]:Number(e.currentTarget.value)})}/></label>)}
            <label class="glass-finish-enable"><span>Reflective floor</span><input aria-label="Reflective floor" type="checkbox" checked={controls.floor} onChange={e=>update({floor:e.currentTarget.checked})}/></label>
            <p class="glass-help">Refined sampling smooths silhouettes and small highlights. Edge softness rounds intersecting surfaces; it applies to Gyroid, Schwarz, Prism, Helix and Vesper.</p>
          </details>
          <label class="glass-field">Glass<select aria-label="Glass" value={controls.glass} onChange={e => update({ glass: e.currentTarget.value as SculptureControls['glass'] })}>{GLASS_TINTS.map(g => <option key={g} value={g}>{label(g)}</option>)}</select></label>
          <label class="glass-orb-color">Custom glass color<input aria-label="Custom glass color" type="color" value={controls.glassColor} onInput={e=>update({glass:'custom',glassColor:e.currentTarget.value})}/></label>
          <label class="glass-range"><span>Tint density<output>{controls.tintDensity.toFixed(2)}</output></span><input aria-label="Tint density" disabled={controls.glass==='clear'} type="range" min="0" max="4" step="0.01" value={controls.tintDensity} onInput={e=>update({tintDensity:Number(e.currentTarget.value)})}/></label>
          <label class="glass-field">Light rig<select aria-label="Light rig" value={controls.light} onChange={e => update({ light: e.currentTarget.value as SculptureControls['light'] })}>{LIGHT_RIG_NAMES.map(l => <option key={l} value={l}>{label(l)}</option>)}</select></label>
          <label class="glass-field">Light movement<select aria-label="Light movement" value={controls.lightMotion} onChange={e=>update({lightMotion:e.currentTarget.value as SculptureControls['lightMotion']})}><option value="fixed">Fixed studio lights</option><option value="pointer">Follow pointer</option><option value="drift">Slow drift</option></select></label>
          <details class="glass-custom-colors" open><summary>Environment colors</summary>
            <div class="glass-environment-presets">{[
              {name:'Neutral',color:'#ffffff',sky:'#242424',ground:'#050505'},
              {name:'Warm',color:'#ffb976',sky:'#332014',ground:'#090503'},
              {name:'Rose',color:'#ff92bd',sky:'#321a2c',ground:'#080408'},
              {name:'Emerald',color:'#89ffd1',sky:'#143229',ground:'#030906'},
              {name:'Blue',color:'#89c6ff',sky:'#182b45',ground:'#03060b'},
            ].map(preset=><button class="text-button" key={preset.name} onClick={()=>update({light:'custom',keyColor:preset.color,rimColor:preset.color,skyColor:preset.sky,groundColor:preset.ground,atmosphereColor:preset.color,reflectionColor:preset.color,gradeColor:preset.color,coolness:0})}>{preset.name}</button>)}</div>
            {([{key:'keyColor',label:'Key light'},{key:'rimColor',label:'Rim light'},{key:'skyColor',label:'Background top'},{key:'groundColor',label:'Background bottom'},{key:'atmosphereColor',label:'Atmosphere beam'},{key:'reflectionColor',label:'Reflection cards'},{key:'gradeColor',label:'Color grade'}] as const).map(field=><label class="glass-orb-color" key={field.key}>{field.label}<input aria-label={field.label+' color'} type="color" value={controls[field.key]} onInput={e=>update({light:'custom',[field.key]:e.currentTarget.value})}/></label>)}
            {(['keyPower','rimPower'] as const).map(key=><label class="glass-range" key={key}><span>{key==='keyPower'?'Key power':'Rim power'}<output>{controls[key].toFixed(1)}</output></span><input aria-label={key==='keyPower'?'Key power':'Rim power'} type="range" min="0" max="30" step="0.1" value={controls[key]} onInput={e=>update({light:'custom',[key]:Number(e.currentTarget.value)})}/></label>)}
            {([{key:'environmentPower',label:'Background brightness',max:4},{key:'reflectionPower',label:'Reflection cards strength',max:3},{key:'atmosphere',label:'Atmosphere beam strength',max:1}] as const).map(field=><label class="glass-range" key={field.key}><span>{field.label}<output>{controls[field.key].toFixed(2)}</output></span><input aria-label={field.label} type="range" min="0" max={field.max} step="0.01" value={controls[field.key]} onInput={e=>update({[field.key]:Number(e.currentTarget.value)})}/></label>)}
            <button class="text-button" onClick={()=>update({atmosphere:0,reflectionPower:0,coolness:0,visibleLights:false})}>Remove atmosphere &amp; accent cards</button>
            <p class="glass-help">Neutral removes the blue environment cast. Set beam or card strength to zero to remove it. Glass tint and orb colors are controlled separately.</p>
          </details>
          <div class="glass-switches"><label><span>Smooth edges</span><input aria-label="Smooth edges" type="checkbox" checked={controls.antialias} onChange={e => update({ antialias: e.currentTarget.checked })} /></label><label><span>Show light sources</span><input aria-label="Show light sources" type="checkbox" checked={controls.visibleLights} onChange={e => update({ visibleLights: e.currentTarget.checked })} /></label><label><span>Chromatic dispersion</span><input aria-label="Chromatic dispersion" disabled={controls.orb!=='none' && controls.orbMode==='surface' && controls.orbStrength>=1} type="checkbox" checked={controls.dispersion} onChange={e => update({ dispersion: e.currentTarget.checked })} /></label><label><span>Turntable</span><input aria-label="Turntable" type="checkbox" checked={controls.spin} onChange={e => update({ spin: e.currentTarget.checked })} /></label></div>
          <label class="glass-field">Render scale<select aria-label="Render scale" value={controls.renderScale} onChange={e => update({ renderScale: Number(e.currentTarget.value) as SculptureControls['renderScale'] })}>{RENDER_SCALES.map(s => <option key={s} value={s}>{s * 100}%</option>)}</select></label>
          <details class="glass-export" open>
            <summary>Export size</summary>
            <label class="glass-field">Preset<select aria-label="Export size" value={controls.exportWidth===3840 && controls.exportHeight===2160 ? '4k' : controls.exportWidth===1920 && controls.exportHeight===1080 ? '1080p' : 'custom'} onChange={e => {
              if(e.currentTarget.value==='4k') update({exportWidth:3840,exportHeight:2160});
              else if(e.currentTarget.value==='1080p') update({exportWidth:1920,exportHeight:1080});
            }}><option value="1080p">1080p · 1920 × 1080</option><option value="4k">4K · 3840 × 2160</option><option value="custom">Custom dimensions</option></select></label>
            <div class="glass-export-dimensions">{(['exportWidth','exportHeight'] as const).map(key => <label key={key}>{key==='exportWidth' ? 'Width' : 'Height'}<input aria-label={key==='exportWidth' ? 'Export width' : 'Export height'} type="number" min="64" max="8192" step="1" value={controls[key]} onChange={e => {
              const value=Number(e.currentTarget.value), other=key==='exportWidth' ? controls.exportHeight : controls.exportWidth;
              if(!Number.isInteger(value) || value<64 || value>8192 || value*other>33554432) { e.currentTarget.value=String(controls[key]); setNotice('Use 64–8192 pixels per side, up to 32 megapixels.'); return; }
              update({[key]:value});
            }} /></label>)}</div>
            <button class="text-button" onClick={() => update({exportWidth:controls.exportHeight,exportHeight:controls.exportWidth})}>Swap orientation</button>
            <p class="glass-help">Tiled export · full render scale · recipe embedded</p>
          </details>
          <details class="glass-finish" open>
            <summary>Finish</summary>
            <label class="glass-finish-enable"><span>Enable effects</span><input aria-label="Enable effects" type="checkbox" checked={controls.effects} onChange={e => update({ effects: e.currentTarget.checked })} /></label>
            {(Object.keys(FINISH_RANGES) as FinishControl[]).map(key => <label class="glass-range" key={key}>
              <span>{finishLabels[key]}<output>{controls[key].toFixed(key === 'grain' ? 3 : 2)}</output></span>
              <input aria-label={finishLabels[key]} type="range" min={FINISH_RANGES[key][0]} max={FINISH_RANGES[key][1]} step={FINISH_RANGES[key][2]} value={controls[key]} disabled={!controls.effects && key !== 'metalness' && key !== 'exposure'} onInput={e => update({ [key]: Number(e.currentTarget.value) })} />
            </label>)}
            {([{key:'bloomThreshold',label:'Bloom threshold',min:0,max:5,step:0.05},{key:'bloomKnee',label:'Bloom softness',min:0.01,max:1,step:0.01}] as const).map(field=><label class="glass-range" key={field.key}><span>{field.label}<output>{controls[field.key].toFixed(2)}</output></span><input aria-label={field.label} disabled={!controls.effects} type="range" min={field.min} max={field.max} step={field.step} value={controls[field.key]} onInput={e=>update({[field.key]:Number(e.currentTarget.value)})}/></label>)}
            <button class="text-button" onClick={() => update({...Object.fromEntries(Object.keys(FINISH_RANGES).map(key => [key, DEFAULT_CONTROLS[key as FinishControl]])),bloomThreshold:DEFAULT_CONTROLS.bloomThreshold,bloomKnee:DEFAULT_CONTROLS.bloomKnee})}>Reset finish</button>
          </details>
          <p class="glass-help">Every control updates the live render. Lower the render scale for faster interaction; PNG export uses the dimensions above at full render scale.</p>
        </fieldset>
        <div class="glass-credit"><a href="https://vgpu.sh/examples/glass-sculpture" target="_blank" rel="noreferrer">Glass Sculpture / vGPU ↗</a><p>Concept and visual design by Kazuyuki Chinda (@ckazu). Original optical pipeline, extended with twelve Hyalos shapes and adjustable finishing.</p></div>
      </aside>
    </main>
    <div class="glass-notice" role="status" hidden={!notice}>{notice}<button aria-label="Dismiss notice" onClick={() => setNotice('')}>×</button></div>
    <input type="file" ref={fileInput} hidden accept=".json,.png,application/json,image/png" onChange={async e => {
      const input = e.currentTarget, file = input.files?.[0]; if (!file) return;
      try {
        if (file.size > 64 * 1024 * 1024) throw new Error('File exceeds 64 MiB.');
        const text = file.name.toLowerCase().endsWith('.png') ? readPngProject(new Uint8Array(await file.arrayBuffer())) : await file.text();
        const next = parseSculpture(text); initial.current = next; renderer.current?.restore(next); setControls(next.controls); persist(next); setNotice('Sculpture restored.');
      } catch (error) { setNotice(error instanceof Error ? error.message : String(error)); }
      finally { input.value = ''; }
    }} />
  </div>;
}
