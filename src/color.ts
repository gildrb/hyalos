import type { Oklch } from './types.ts';
/** Convert authored OKLCH to linear-sRGB radiance. Never perform lighting in OKLCH. */
export function oklchToLinear([L, C, h]: Oklch): [number, number, number] {
  const a = C * Math.cos(h * Math.PI / 180), b = C * Math.sin(h * Math.PI / 180);
  const l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3;
  const m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3;
  const s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3;
  return [4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s];
}
export function inGamut(rgb: readonly number[]) { return rgb.every((v) => v >= -1e-7 && v <= 1 + 1e-7); }
export function gamutMap(color: Oklch): [number, number, number] {
  let rgb = oklchToLinear(color);
  if (!inGamut(rgb)) {
    let lo = 0, hi = color[1];
    for (let i = 0; i < 20; i++) {
      const c = (lo + hi) / 2;
      if (inGamut(oklchToLinear([color[0], c, color[2]]))) lo = c; else hi = c;
    }
    rgb = oklchToLinear([color[0], lo, color[2]]);
  }
  return rgb.map((v) => Math.min(1, Math.max(0, v))) as [number, number, number];
}
export function cssOklch([l, c, h]: Oklch): string { return `oklch(${l} ${c} ${h})`; }
export function linearToSrgb(v: number): number { return v <= 0.0031308 ? 12.92 * v : 1.055 * v ** (1 / 2.4) - 0.055; }
