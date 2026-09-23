export interface OrbDefinition {
  key: string;
  label: string;
  note: string;
  sourceHash: string;
  schema: Record<string, 'f32' | 'vec2f' | 'vec3f' | 'vec4f'>;
  params: Array<{key:string;label:string;min:number;max:number;step:number;default:number;integrate?:boolean}>;
  colors: Array<{key:string;label:string;default:string}>;
  statePresets?: Partial<Record<'idle'|'thinking'|'speaking',Record<string,number>>>;
  stateColors?: Partial<Record<'idle'|'thinking'|'speaking',Record<string,string>>>;
}
