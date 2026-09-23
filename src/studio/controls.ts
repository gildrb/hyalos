import { ORB_CATALOG } from './orbs/catalog.ts';
export const SHAPES = ['knot', 'gyroid', 'droplets', 'vesper', 'reliquary', 'trefoil', 'mobius', 'schwarz', 'petal', 'torus', 'helix', 'ribbon', 'prism', 'pearl', 'wave'] as const;
export const GLASS_TINTS = ['clear', 'rose', 'cobalt', 'emerald', 'amber', 'violet', 'ice', 'smoke', 'custom'] as const;
export const LIGHT_RIG_NAMES = ['studio', 'noir', 'gel', 'golden', 'lunar', 'custom'] as const;
export const RENDER_SCALES = [0.5, 0.75, 1] as const;

export type Shape = (typeof SHAPES)[number];
export type GlassTint = (typeof GLASS_TINTS)[number];
export type LightRigName = (typeof LIGHT_RIG_NAMES)[number];
export type RenderScale = (typeof RENDER_SCALES)[number];

export interface SculptureControls {
  orb: string;
  orbMode: 'surface' | 'emission' | 'reflection';
  orbMapping: 'triplanar' | 'normal' | 'screen';
  orbStrength: number;
  orbScale: number;
  orbAnimate: boolean;
  orbState: 'idle' | 'thinking' | 'speaking';
  orbValues: Record<string,{params?:Record<string,number>;colors?:Record<string,string>}>;
  shape: Shape;
  glass: GlassTint;
  glassColor: string;
  tintDensity: number;
  keyColor: string;
  rimColor: string;
  skyColor: string;
  groundColor: string;
  atmosphereColor: string;
  reflectionColor: string;
  gradeColor: string;
  environmentPower: number;
  reflectionPower: number;
  keyPower: number;
  rimPower: number;
  light: LightRigName;
  dispersion: boolean;
  spin: boolean;
  renderScale: RenderScale;
  effects: boolean;
  visibleLights: boolean;
  antialias: boolean;
  exportWidth: number;
  exportHeight: number;
  bloom: number;
  glowRadius: number;
  grain: number;
  texture: number;
  coolness: number;
  atmosphere: number;
  metalness: number;
  exposure: number;

}

export const DEFAULT_CONTROLS: SculptureControls = {
  orb: 'none', orbMode: 'surface', orbMapping: 'triplanar', orbStrength: 1, orbScale: 1, orbAnimate: true, orbState: 'idle', orbValues: {},
  shape: 'gyroid',
  glass: 'clear', glassColor: '#82baff', tintDensity: 1.1, keyColor: '#ffffff', rimColor: '#ffffff', skyColor: '#242424', groundColor: '#050505', keyPower: 16, rimPower: 9,
  atmosphereColor: '#ffffff', reflectionColor: '#ffffff', gradeColor: '#ffffff', environmentPower: 1, reflectionPower: 1,
  light: 'custom',
  dispersion: true,
  spin: true,
  renderScale: 0.75,
  effects: true, visibleLights: false, antialias: true, exportWidth: 1920, exportHeight: 1080, bloom: 0.45, glowRadius: 1, grain: 0.012,
  texture: 0, coolness: 0, atmosphere: 0, metalness: 0, exposure: 1.05,
};

export const FINISH_RANGES = {
  bloom: [0, 1.5, 0.01], glowRadius: [0.5, 3, 0.05], grain: [0, 0.08, 0.001],
  texture: [0, 1, 0.01], coolness: [0, 1, 0.01],
  metalness: [0, 1, 0.01], exposure: [0.25, 2.5, 0.01],
} as const;
export type FinishControl = keyof typeof FINISH_RANGES;
const hex = (value: string, fallback: string) => typeof value==='string' && /^#[0-9a-fA-F]{6}$/.test(value) ? value : fallback;
const finite = (value: number, fallback: number, min: number, max: number) => Number.isFinite(value) ? Math.max(min, Math.min(max, value)) : fallback;

export function normalizeControls(controls: Readonly<SculptureControls>): SculptureControls {
  const orbValues: SculptureControls['orbValues'] = {};
  for(const item of ORB_CATALOG) {
    const stored=controls.orbValues?.[item.key]; if(!stored) continue;
    const params: Record<string,number> = {}, colors: Record<string,string> = {};
    for(const def of item.params) if(stored.params?.[def.key]!==undefined) params[def.key]=finite(stored.params[def.key],def.default,def.min,def.max);
    for(const def of item.colors) if(typeof stored.colors?.[def.key]==='string' && /^#[0-9a-fA-F]{6}$/.test(stored.colors[def.key])) colors[def.key]=stored.colors[def.key];
    orbValues[item.key]={params,colors};
  }
  return {
    orb: controls.orb === 'none' || ORB_CATALOG.some(item=>item.key===controls.orb) ? controls.orb : 'none',
    orbMode: ['surface','emission','reflection'].includes(controls.orbMode) ? controls.orbMode : 'surface',
    orbMapping: ['triplanar','normal','screen'].includes(controls.orbMapping) ? controls.orbMapping : 'triplanar',
    orbStrength: finite(controls.orbStrength,1,0,2), orbScale: finite(controls.orbScale,1,0.25,3),
    orbAnimate: controls.orbAnimate !== false,
    orbState: ['idle','thinking','speaking'].includes(controls.orbState) ? controls.orbState : 'idle',
    orbValues,
    ...Object.fromEntries(Object.entries(FINISH_RANGES).map(([key, [min, max]]) => [key, finite(controls[key as FinishControl], DEFAULT_CONTROLS[key as FinishControl], min, max)])) as Pick<SculptureControls, FinishControl>,
    atmosphere: finite(controls.atmosphere,0,0,1),
    effects: controls.effects !== false,
    visibleLights: controls.visibleLights === true,
    antialias: controls.antialias !== false,
    exportWidth: Math.round(finite(controls.exportWidth,1920,64,8192)),
    exportHeight: Math.round(finite(controls.exportHeight,1080,64,8192)),
    shape: SHAPES.includes(controls.shape) ? controls.shape : DEFAULT_CONTROLS.shape,
    glassColor: hex(controls.glassColor,DEFAULT_CONTROLS.glassColor),
    tintDensity: finite(controls.tintDensity,1.1,0,4),
    keyColor: hex(controls.keyColor,DEFAULT_CONTROLS.keyColor), rimColor: hex(controls.rimColor,DEFAULT_CONTROLS.rimColor),
    skyColor: hex(controls.skyColor,DEFAULT_CONTROLS.skyColor), groundColor: hex(controls.groundColor,DEFAULT_CONTROLS.groundColor),
    atmosphereColor: hex(controls.atmosphereColor,DEFAULT_CONTROLS.atmosphereColor),
    reflectionColor: hex(controls.reflectionColor,DEFAULT_CONTROLS.reflectionColor),
    gradeColor: hex(controls.gradeColor,DEFAULT_CONTROLS.gradeColor),
    environmentPower: finite(controls.environmentPower,1,0,4),
    reflectionPower: finite(controls.reflectionPower,1,0,3),
    keyPower: finite(controls.keyPower,16,0,30), rimPower: finite(controls.rimPower,9,0,30),
    glass: GLASS_TINTS.includes(controls.glass) ? controls.glass : DEFAULT_CONTROLS.glass,
    light: LIGHT_RIG_NAMES.includes(controls.light) ? controls.light : DEFAULT_CONTROLS.light,
    dispersion: controls.dispersion === true,
    spin: controls.spin !== false,
    renderScale: RENDER_SCALES.includes(controls.renderScale)
      ? controls.renderScale
      : DEFAULT_CONTROLS.renderScale,
  };
}
