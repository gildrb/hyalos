import type { Settings, TileRegion, Quality, Vec4 } from '../types.ts';
import { gamutMap } from '../color.ts';
import { loopPhase } from '../model.ts';
export const QUALITY: Record<Quality, [number, number, number]> = { draft: [64, 12, 10], balanced: [104, 24, 16], final: [160, 48, 24] };
/** Build one host-shareable, explicitly aligned WGSL uniform struct. */
export function uniforms(s: Settings, width: number, height: number, tile: TileRegion, quality: Quality = 'balanced'): Record<string, Vec4> {
  const rad = Math.PI / 180;
  const [raySteps, volumeSteps, shadowSteps] = QUALITY[quality];
  return {
    view: [width, height, s.perforation, s.seed], // Explicit time is encoded by motion.y; view.z was unused.
    tile: [tile.left, tile.top, tile.width, tile.height],
    shape: [s.scene, s.twist, s.spread, s.thickness],
    style: [s.finish, s.spacing, s.dotSize, s.dither],
    motion: [s.rotation * rad, loopPhase(s.time, s.duration), s.zoom, s.panX],
    light: [s.power, s.radius, s.keyAngle * rad, s.fill],
    medium: [s.density, s.anisotropy, s.turbulence, s.beam], // Beam: fraction of key power directed into the cone.
    material: [s.roughness, s.metallic, 18, s.detail],
    background: [...gamutMap(s.palette.background), s.exposure],
    metal: [...gamutMap(s.palette.metal), s.contrast],
    energy: [...gamutMap(s.palette.energy), s.bloom],
    finish: [s.grain, s.vignette, s.bloomRadius, s.holeSoftness],
    emit: [s.holeWarp, 0, s.nodes, s.holeFrequency], // y is the renderer-owned sample index; x was an unused radius copy.
    camera: [s.panY, s.yaw * rad, s.pitch * rad, s.beamAngle * rad], // Cone outer half-angle, radians.
    nodes: [s.transmission, s.ior, s.dispersion, s.absorption],
    quality: [raySteps, volumeSteps, shadowSteps, quality === 'draft' ? 1 : s.sampleGrid],
  };
}
