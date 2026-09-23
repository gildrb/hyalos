import { useLayoutEffect, useRef, useState } from 'preact/hooks';
import type { ComponentChildren } from 'preact';
import { Editor, messageOf } from '../editor.ts';
import { FINISHES, PALETTES, RANGES, SCENES, nextSeed, preset } from '../model.ts';
import { cssOklch } from '../color.ts';
import type { ColorRole, NumericKey, Oklch, Quality, Tab } from '../types.ts';
import { Icon } from './Icon.tsx';

type Props = { editor: Editor; notify: (text: string) => void };
function Section({ title, children }: { title: string; children: ComponentChildren }) {
  return <section class="control-section"><h2>{title}</h2>{children}</section>;
}
function NumberControl({ editor, param, label, notify }: Props & { param: NumericKey; label: string }) {
  const value = editor.settings[param], [min, max, step] = RANGES[param];
  const [draft, setDraft] = useState(String(value));
  const observed = useRef(value), staged = useRef(false);
  useLayoutEffect(() => {
    if (value !== observed.current) {
      observed.current = value;
      staged.current = false;
      setDraft(String(value));
    }
  }, [value]);
  const stage = (number: number): void => {
    if (number === editor.settings[param]) return;
    editor.update({ [param]: number }, false);
    observed.current = number;
    staged.current = true;
  };
  const accept = (): void => {
    try {
      if (draft.trim()) stage(Number(draft));
    } catch (error) { notify(messageOf(error)); }
    setDraft(String(editor.settings[param]));
    if (staged.current) {
      staged.current = false;
      editor.commit();
    }
  };
  const type = (text: string): void => {
    setDraft(text);
    const number = Number(text);
    if (!text.trim() || !Number.isFinite(number) || number < min || number > max || (step === 1 && !Number.isInteger(number))) return;
    try { stage(number); }
    catch (error) { notify(messageOf(error)); }
  };
  return <div class="control">
    <div class="control-head"><label for={`range-${param}`}>{label}</label><input class="value-input" data-value={param} aria-label={`${label} value`} type="number" min={min} max={max} step={step} value={draft} onInput={e => type(e.currentTarget.value)} onBlur={accept} onKeyDown={e => { if (e.key === 'Enter') { e.preventDefault(); e.currentTarget.blur(); } }} /></div>
    <input id={`range-${param}`} data-param={param} type="range" min={min} max={max} step={step} value={value} onInput={e => editor.update({ [param]: Number(e.currentTarget.value) }, false)} onChange={() => editor.commit()} onDblClick={() => editor.update({ [param]: preset(editor.selected)[param] })} title="Double-click to reset" />
  </div>;
}
function ColorControl({ editor, role, label }: { editor: Editor; role: ColorRole; label: string }) {
  const values = editor.settings.palette[role];
  const change = (index: number, number: number): void => {
    const color = [...values] as Oklch; color[index] = number;
    editor.update({ palette: { ...editor.settings.palette, [role]: color } }, false);
  };
  return <details class="color-details"><summary><span class="color-dot" style={{ background: cssOklch(values) }} />{label}</summary>
    {(['Lightness', 'Chroma', 'Hue'] as const).map((name, index) => <div class="control" key={name}>
      <div class="control-head"><label for={`color-${role}-${index}`}>{name}</label><output>{values[index].toFixed(index === 2 ? 0 : 3)}</output></div>
      <input id={`color-${role}-${index}`} aria-label={`${label} ${name}`} type="range" min={0} max={[1, .4, 360][index]} step={[.005, .002, 1][index]} value={values[index]} onInput={e => change(index, Number(e.currentTarget.value))} onChange={() => editor.commit()} />
    </div>)}
  </details>;
}
export function Inspector({ editor, notify, onAbout }: Props & { onAbout: () => void }) {
  const [tab, setTab] = useState<Tab>('form');
  const control = (param: NumericKey, label: string) => <NumberControl key={param} editor={editor} notify={notify} param={param} label={label} />;
  return <aside class="inspector" id="inspector" aria-label="Scene parameters">
    <div class="panel-header"><span>Edit</span><button class="icon-button" aria-label="Rendering information" title="Rendering information" onClick={onAbout}><Icon name="info" /></button></div>
    <div class="inspector-tabs" role="tablist" aria-label="Parameter group" onKeyDown={e => {
      const tabs: Tab[] = ['form', 'light', 'finish'];
      if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(e.key)) return;
      e.preventDefault();
      const i = e.key === 'Home' ? 0 : e.key === 'End' ? 2 : (tabs.indexOf(tab) + (e.key === 'ArrowRight' ? 1 : 2)) % 3;
      setTab(tabs[i]); e.currentTarget.querySelectorAll<HTMLButtonElement>('button')[i].focus();
    }}>{(['form', 'light', 'finish'] as const).map(name => <button key={name} role="tab" id={`tab-${name}`} data-tab={name} aria-controls={`panel-${name}`} aria-selected={tab === name} tabIndex={tab === name ? 0 : -1} onClick={() => setTab(name)}>{name[0].toUpperCase() + name.slice(1)}</button>)}</div>
    <fieldset class="controls" id="controls" disabled={editor.busy}>
      <div id="panel-form" role="tabpanel" aria-labelledby="tab-form" hidden={tab !== 'form'}>
        <Section title="Structure">
          <div class="select-control"><label for="select-scene">Form family</label><select id="select-scene" data-select="scene" value={editor.settings.scene} onChange={e => editor.update({ scene: Number(e.currentTarget.value) })}>{SCENES.map((name, i) => <option key={name} value={i}>{name}</option>)}</select></div>
          {control('seed', 'Seed')}<button id="new-seed" class="outline-button" onClick={() => editor.update({ seed: nextSeed(editor.settings.seed) })}>Next variation <Icon name="arrow" /></button>
          {control('twist', 'Torsion')}{control('spread', 'Openness')}{control('thickness', 'Shell thickness')}{control('nodes', 'Light sources')}
        </Section>
        <Section title="Perforation · ORB-31">
          {control('holeWarp', 'Warp divisor')}{control('holeFrequency', 'Hole frequency')}{control('holeSoftness', 'Edge softness')}
          <div hidden={editor.settings.scene === 9}>{control('perforation', 'Perforation')}</div>
          <p class="control-help">ORB-31 by XorDev · non-commercial; form/light edits apply on Render.</p>
        </Section>
        <Section title="Composition">{control('rotation', 'Rotation')}{control('zoom', 'Scale')}{control('panX', 'Position X')}{control('panY', 'Position Y')}{control('yaw', 'Orbit Y')}{control('pitch', 'Orbit X')}</Section>
        <p class="control-help">Double-click a slider to reset it.</p>
      </div>
      <div id="panel-light" role="tabpanel" aria-labelledby="tab-light" hidden={tab !== 'light'}>
        <Section title="Material">{control('roughness', 'Roughness')}{control('metallic', 'Metallicity')}{control('detail', 'Surface relief')}</Section>
        <Section title="Glass">
          {control('transmission', 'Transmission')}{control('ior', 'Refractive index')}{control('dispersion', 'Color dispersion')}{control('absorption', 'Absorption')}
          <p class="control-help">Lower metallicity to reveal glass. Absorption uses the material color.</p>
        </Section>
        <Section title="Lighting">
          {control('power', 'Light power')}{control('radius', 'Source size')}{control('keyAngle', 'Light angle (°)')}{control('fill', 'Fill light')}
          {control('beam', 'Spotlight mix')}{control('beamAngle', 'Beam half-angle (°)')}
          <p class="control-help">A narrower beam concentrates the light. Haze makes it visible.</p>
        </Section>
        <Section title="Haze">{control('density', 'Density')}{control('anisotropy', 'Forward scattering')}{control('turbulence', 'Texture')}</Section>
      </div>
      <div id="panel-finish" role="tabpanel" aria-labelledby="tab-finish" hidden={tab !== 'finish'}>
        <Section title="Treatment"><div class="finish-modes">{FINISHES.map((name, i) => <button key={name} data-finish={i} aria-pressed={editor.settings.finish === i} onClick={() => editor.update({ finish: i })}>{name}</button>)}</div>
          <div hidden={editor.settings.finish === 0}>{control('spacing', 'Grid spacing')}{control('dotSize', 'Dot radius')}{control('dither', 'Dither mix')}</div>
        </Section>
        <Section title="Palette">
          <div class="palette-buttons">{Object.entries(PALETTES).map(([name, palette]) => <button key={name} class="palette-button" aria-label={`${name} palette`} title={name} style={{ background: cssOklch(palette.energy) }} onClick={() => editor.update({ palette: structuredClone(palette) })} />)}</div>
          <ColorControl editor={editor} role="background" label="Background" /><ColorControl editor={editor} role="metal" label="Material" /><ColorControl editor={editor} role="energy" label="Light" />
        </Section>
        <Section title="Optics">{control('exposure', 'Exposure')}{control('contrast', 'Contrast')}{control('bloom', 'Lens scattering')}{control('bloomRadius', 'Scattering radius')}{control('grain', 'Film grain')}{control('vignette', 'Vignette')}</Section>
        <Section title="Rendering">
          <div class="select-control"><label for="quality">Preview quality</label><select id="quality" aria-describedby="preview-quality-help" value={editor.quality} onChange={e => editor.setQuality(e.currentTarget.value as Quality)}><option value="draft">Draft</option><option value="balanced">Balanced</option><option value="final">Final</option></select></div>
          <p class="control-help" id="preview-quality-help">Applied when you choose Render. Export resolution is separate.</p>
          <div class="select-control"><label for="select-sample-grid">Edge sampling</label><select id="select-sample-grid" data-select="sampleGrid" aria-describedby="sample-grid-help" value={editor.settings.sampleGrid} onChange={e => editor.update({ sampleGrid: Number(e.currentTarget.value) })}><option value={1}>1 sample</option><option value={2}>4 samples</option><option value={3}>9 samples</option></select></div>
          <p class="control-help" id="sample-grid-help">More samples smooth edges and take longer. Applies to exports and Balanced or Final previews when you choose Render.</p>
        </Section>
      </div>
    </fieldset>
  </aside>;
}
