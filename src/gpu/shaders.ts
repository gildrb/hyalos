import common from '../shaders/common.wgsl?raw';
import simplex from '../shaders/vendor/simplex3.wgsl?raw';
import orb31 from '../shaders/vendor/orb31.wgsl?raw';
import glass from '../shaders/glass.wgsl?raw';
import opaque from '../shaders/opaque.wgsl?raw';
import scene from '../shaders/scene.wgsl?raw';
import dither from '../shaders/vendor/dither8.wgsl?raw';
import post from '../shaders/post.wgsl?raw';
export const SCENE_SHADER = `${common}\n${simplex}\n${orb31}\n${scene}\n${glass}\n${opaque}`;
export function sceneShader(form: number, transmissive: boolean): string {
  if (!Number.isInteger(form) || form < 0 || form > 9) throw new Error('Unknown shader form.');
  return `const FORM_KIND: f32 = ${form}.0;\n${common}\n${simplex}\n${orb31}\n${scene}\n${transmissive ? glass : opaque}`;
}
export const POST_SHADER = `${common}\n${dither}\n${post}`;
export async function shaderFingerprint() {
  const bytes = new TextEncoder().encode(SCENE_SHADER + '\n---\n' + POST_SHADER);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)].map((n) => n.toString(16).padStart(2, '0')).join('');
}
