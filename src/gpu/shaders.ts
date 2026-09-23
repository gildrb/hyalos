import common from '../shaders/common.wgsl?raw';
import simplex from '../shaders/vendor/simplex3.wgsl?raw';
import orb31 from '../shaders/vendor/orb31.wgsl?raw';
import scene from '../shaders/scene.wgsl?raw';
import dither from '../shaders/vendor/dither8.wgsl?raw';
import post from '../shaders/post.wgsl?raw';
export const SCENE_SHADER = `${common}\n${simplex}\n${orb31}\n${scene}`;
export const POST_SHADER = `${common}\n${dither}\n${post}`;
export async function shaderFingerprint() {
  const bytes = new TextEncoder().encode(SCENE_SHADER + '\n---\n' + POST_SHADER);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)].map((n) => n.toString(16).padStart(2, '0')).join('');
}
