import { gamutMap } from '../color.js';
import { loopPhase } from '../model.js';
export const QUALITY = { draft: [64, 12, 10, 0], balanced: [104, 24, 16, 0], final: [160, 48, 24, 0] };
/** Build one host-shareable, explicitly aligned WGSL uniform struct. */
export function uniforms(s, width, height, tile, quality = 'balanced') {
  const rad = Math.PI / 180;
  return {
    view: [width, height, s.time, s.seed],
    tile: [tile.left, tile.top, tile.width, tile.height],
    shape: [s.scene, s.twist, s.spread, s.thickness],
    style: [s.finish, s.spacing, s.dotSize, s.dither],
    motion: [s.rotation * rad, loopPhase(s.time, s.duration), s.zoom, s.panX],
    light: [s.power, s.radius, s.keyAngle * rad, s.fill],
    medium: [s.density, s.anisotropy, s.turbulence, 0],
    material: [s.roughness, s.metallic, 18, s.detail],
    background: [...gamutMap(s.palette.background), s.exposure],
    metal: [...gamutMap(s.palette.metal), s.contrast],
    energy: [...gamutMap(s.palette.energy), s.bloom],
    finish: [s.grain, s.vignette, s.bloomRadius, 0],
    emit: [s.radius, 0, s.nodes, 0],
    camera: [s.panY, s.yaw * rad, s.pitch * rad, 0],
    nodes: [0, 0, 0, 0], quality: QUALITY[quality],
  };
}
