// Authoring colors arrive as gamut-mapped linear radiance from OKLCH.
// All fields are vec4f: identical 16-byte alignment on every backend.
struct Params {
  view: vec4f, tile: vec4f, shape: vec4f, style: vec4f,
  motion: vec4f, light: vec4f, medium: vec4f, material: vec4f,
  background: vec4f, metal: vec4f, energy: vec4f, finish: vec4f,
  emit: vec4f, camera: vec4f, nodes: vec4f, quality: vec4f,
};
@group(0) @binding(0) var<uniform> u: Params;
const PI: f32 = 3.141592653589793;
const TAU: f32 = 6.283185307179586;
fn rot(p: vec2f, a: f32) -> vec2f {
  let c = cos(a); let s = sin(a);
  return vec2f(c * p.x - s * p.y, s * p.x + c * p.y);
}
fn sq(x: f32) -> f32 { return x*x; }
fn pcg(n: u32) -> u32 {
  let state = n * 747796405u + 2891336453u;
  let word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
  return (word >> 22u) ^ word;
}
fn rand(n: u32) -> f32 { return f32(pcg(n) & 0x00ffffffu) / 16777216.0; }
fn seedPhase() -> f32 { return rand(u32(u.view.w)) * TAU; }
fn smoothUnion(a: f32, b: f32, k: f32) -> f32 {
  let h = clamp(0.5 + 0.5 * (b-a) / k, 0.0, 1.0);
  return mix(b, a, h) - k*h*(1.0-h);
}
fn ellipsoid(p: vec3f, r: vec3f) -> f32 {
  let k0 = length(p/r); let k1 = length(p/(r*r));
  if (k1 < 0.0001) { return -min(r.x,min(r.y,r.z)); }
  return k0*(k0-1.0)/k1;
}
fn srgb(linear: vec3f) -> vec3f {
  return select(1.055*pow(max(linear, vec3f(0.0)), vec3f(1.0/2.4))-0.055,
    12.92*linear, linear <= vec3f(0.0031308));
}
fn luminance(c: vec3f) -> f32 { return dot(c, vec3f(0.2126, 0.7152, 0.0722)); }
// Neutral, luminance-preserving Reinhard compression; exposure precedes this.
fn tone(c: vec3f) -> vec3f {
  let exposed = max(c * exp2(u.background.w), vec3f(0.0));
  return exposed / (1.0 + luminance(exposed));
}
