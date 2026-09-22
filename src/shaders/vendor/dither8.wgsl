// WGSL port of hughsk/glsl-dither/8x8.glsl (MIT),
// blob 8c795e52124a93c7307df16523cd9a266941408b. See LICENSES/glsl-dither.txt.
// Upstream thresholds retained. Branch chain replaced with indexed constants.
const BAYER: array<f32, 64> = array<f32, 64>(
  1,33,9,41,3,35,11,43, 49,17,57,25,51,19,59,27,
  13,45,5,37,15,47,7,39, 61,29,53,21,63,31,55,23,
  4,36,12,44,2,34,10,42, 52,20,60,28,50,18,58,26,
  16,48,8,40,14,46,6,38, 64,32,56,24,62,30,54,22
);
fn dither8(position: vec2u, brightness: f32) -> f32 {
  let index = (position.x % 8u) + (position.y % 8u)*8u;
  return step(BAYER[index]/64.0, brightness);
}
