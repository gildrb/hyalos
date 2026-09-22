import { useEffect, useState } from 'preact/hooks';
import type { ComponentChildren } from 'preact';
import { Editor, messageOf } from '../editor.ts';
import { FINISHES, PALETTES, RANGES, SCENES, nextSeed, preset } from '../model.ts';
import { cssOklch } from '../color.ts';
import type { ColorRole, NumericKey, Oklch, Tab } from '../types.ts';
import { Icon } from './Icon.tsx';

type Props = { editor: Editor; notify: (text: string) => void };
function Section({ title, suffix, children }: { title: string; suffix?: string; children: ComponentChildren }) {
  return <section class="control-section"><h2>{title}<small>{suffix}</small></h2>{children}</section>;
}
function NumberControl({ editor, param, label, notify }: Props & { param: NumericKey; label: string }) {
  const value = editor.settings[param], [min, max, step] = RANGES[param];
  const [draft, setDraft] = useState(String(value));
  useEffect(() => { setDraft(String(value)); }, [value]);
  const accept = (): void => {
    const number = Number(draft);
    if (!draft.trim()) { setDraft(String(value)); return; }
    try { editor.update({ [param]: number }); }
    catch (error) { setDraft(String(value)); notify(messageOf(error)); }
  };
  return <div class="control">
    <div class="control-head"><label for={`range-${param}`}>{label}</label><input class="value-input" data-value={param} aria-label={`${label} value`} type="number" min={min} max={max} step={step} value={draft} onInput={e => setDraft(e.currentTarget.value)} onBlur={accept} onKeyDown={e => { if (e.key === 'Enter') { e.preventDefault(); e.currentTarget.blur(); } }} /></div>
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
  return <aside class="inspector" aria-label="Shader parameters">
    <div class="panel-header"><span>Parameters</span><span class="local-tag">{editor.status === 'ready' ? 'LIVE' : 'LOCAL'}</span></div>
    <div class="inspector-tabs" role="tablist" aria-label="Parameter group" onKeyDown={e => {
      const tabs: Tab[] = ['form', 'light', 'finish'];
      if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(e.key)) return;
      e.preventDefault();
      const i = e.key === 'Home' ? 0 : e.key === 'End' ? 2 : (tabs.indexOf(tab) + (e.key === 'ArrowRight' ? 1 : 2)) % 3;
      setTab(tabs[i]); e.currentTarget.querySelectorAll<HTMLButtonElement>('button')[i].focus();
    }}>{(['form', 'light', 'finish'] as const).map(name => <button key={name} role="tab" id={`tab-${name}`} data-tab={name} aria-controls={`panel-${name}`} aria-selected={tab === name} tabIndex={tab === name ? 0 : -1} onClick={() => setTab(name)}>{name[0].toUpperCase() + name.slice(1)}</button>)}</div>
    <fieldset class="controls" id="controls" disabled={editor.busy}>
      <div id="panel-form" role="tabpanel" aria-labelledby="tab-form" hidden={tab !== 'form'}>
        <Section title="Structure" suffix="01">
          <div class="select-control"><label for="select-scene">Form family</label><select id="select-scene" data-select="scene" value={editor.settings.scene} onChange={e => editor.update({ scene: Number(e.currentTarget.value) })}>{SCENES.map((name, i) => <option key={name} value={i}>{name}</option>)}</select></div>
          {control('seed', 'Seed')}<button id="new-seed" class="outline-button" onClick={() => editor.update({ seed: nextSeed(editor.settings.seed) })}>Next variation <Icon name="arrow" /></button>
          {control('twist', 'Torsion')}{control('spread', 'Openness')}{control('thickness', 'Shell thickness')}{control('nodes', 'Local sources')}
        </Section>
        <Section title="Composition" suffix="02">{control('rotation', 'Rotation')}{control('zoom', 'Scale')}{control('panX', 'Position X')}{control('panY', 'Position Y')}{control('yaw', 'Orbit Y')}{control('pitch', 'Orbit X')}</Section>
        <p class="control-help">A seed changes the form, not its visual language. Double-click a slider to reset it.</p>
      </div>
      <div id="panel-light" role="tabpanel" aria-labelledby="tab-light" hidden={tab !== 'light'}>
        <Section title="Material" suffix="GGX">{control('roughness', 'Roughness')}{control('metallic', 'Metallicity')}{control('detail', 'Surface relief')}</Section>
        <Section title="Sources" suffix="1 / r2">{control('power', 'Radiant power')}{control('radius', 'Core radius')}{control('keyAngle', 'Key-light angle')}{control('fill', 'Fill ratio')}</Section>
        <Section title="Participating medium" suffix="HG">{control('density', 'Extinction density')}{control('anisotropy', 'Scattering direction')}{control('turbulence', 'Density detail')}</Section>
        <p class="control-help">Physically based approximations in linear light. The form is procedural, not a combustion simulation.</p>
      </div>
      <div id="panel-finish" role="tabpanel" aria-labelledby="tab-finish" hidden={tab !== 'finish'}>
        <Section title="Treatment" suffix="03"><div class="finish-modes">{FINISHES.map((name, i) => <button key={name} data-finish={i} aria-pressed={editor.settings.finish === i} onClick={() => editor.update({ finish: i })}>{name}</button>)}</div>
          <div hidden={editor.settings.finish === 0}>{control('spacing', 'Grid spacing')}{control('dotSize', 'Dot radius')}{control('dither', 'Dither mix')}</div>
        </Section>
        <Section title="Palette" suffix="OKLCH">
          <div class="palette-buttons">{Object.entries(PALETTES).map(([name, palette]) => <button key={name} class="palette-button" aria-label={`${name} palette`} title={name} style={{ background: cssOklch(palette.energy) }} onClick={() => editor.update({ palette: structuredClone(palette) })} />)}</div>
          <ColorControl editor={editor} role="background" label="Void" /><ColorControl editor={editor} role="metal" label="Matter" /><ColorControl editor={editor} role="energy" label="Fire" />
        </Section>
        <Section title="Optics" suffix="LINEAR">{control('exposure', 'Exposure')}{control('contrast', 'Contrast')}{control('bloom', 'Lens scattering')}{control('bloomRadius', 'Scattering radius')}{control('grain', 'Film grain')}{control('vignette', 'Vignette')}</Section>
      </div>
    </fieldset>
    <div class="inspector-footer"><span class="small-dot" /><span>OKLCH IN / LINEAR LIGHT OUT</span><button aria-label="Rendering information" onClick={onAbout}><Icon name="info" /></button></div>
  </aside>;
}
