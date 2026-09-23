// Compiled from unchanged shadercn orb-05 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: 0eeee4ce41f39de7b2fb15ef15a35b316952c801edf06b4470ad27c8ffd434b7
struct orb05Params {
  anim: f32,
  c_body: vec3f,
  c_sheen: vec3f,
  c_tint: vec3f,
  inputVol: f32,
  mouse: vec2f,
  outputVol: f32,
  p_bulge: f32,
  p_contrast: f32,
  p_floorLevel: f32,
  p_freq: f32,
  p_gain: f32,
  p_lens: f32,
  p_light: f32,
  p_poleSoft: f32,
  p_radius: f32,
  p_rim: f32,
  p_ring: f32,
  p_saturation: f32,
  p_scale: f32,
  p_slide: f32,
  p_spread: f32,
  p_swirl: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb05Params;

fn rot2(angle: f32) -> mat2x2f {
  let c = cos(angle);
  let s = sin(angle);
  return mat2x2f(vec2f(c, -(s)), vec2f(s, c));
}

fn tanSoft(x: vec2f, g: f32) -> vec2f {
  let s = sin(x);
  let c = cos(x);
  return ((s * c) / ((c * c) + g));
}

fn causticRender(fragCoord: vec2f, causticSoft: f32, causticGain: f32, causticSpread: f32) -> vec3f {
  let u = (&params);
  let uv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let R = max((*u).p_radius, 1e-3f);
  let pl = (uv / R);
  let z = sqrt(max((1f - dot(pl, pl)), 0f));
  let ring = (*u).p_ring;
  var p = ((pl / ((z + 1f) + (*u).p_bulge)) * (*u).p_scale);
  let sw = (*u).p_swirl;
  p = (rot2(sw) * p);
  p = (p + vec2f((*u).p_slide, ((*u).p_slide * 0.6f)));
  let L = length(((tanSoft(p, causticSoft) * (*u).p_lens) + p));
  var col = cos(((vec3f(0, 0.699999988079071, 1) * causticSpread) + ((L * (*u).p_freq) - ring)));
  col = (max(col, vec3f()) * causticGain);
  col = pow(col, vec3f((*u).p_contrast));
  let lum = dot(col, vec3f(0.29899999499320984, 0.5870000123977661, 0.11400000005960464));
  col = (mix(vec3f(lum), col, (*u).p_saturation) * (*u).c_tint);
  col = (col + ((*u).c_body * (*u).p_floorLevel));
  let n = vec3f(pl.x, pl.y, z);
  let lambert = clamp(dot(n, vec3f(-0.4448256194591522, 0.5436757802963257, 0.7117210030555725)), 0f, 1f);
  col = (col * (0.6f + ((*u).p_light * lambert)));
  let fres = (1f - z);
  let fresCubed = ((fres * fres) * fres);
  col = (col + ((*u).c_sheen * ((*u).p_rim * fresCubed)));
  return col;
}

struct orb05Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb05Fragment(_arg_0: orb05Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let orbUv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let causticSoft = max(((*u).p_poleSoft * (1f - (0.5f * (*u).inputVol))), 8e-4f);
  let causticGain = ((*u).p_gain * (0.85f + (0.45f * (*u).outputVol)));
  let causticSpread = ((*u).p_spread * (1f + (0.5f * (*u).outputVol)));
  let mask = smoothstep(0.012f, -0.012f, (length(orbUv) - max((*u).p_radius, 1e-3f)));
  if ((mask <= 0f)) {
    return vec4f();
  }
  let col = causticRender(fragCoord, causticSoft, causticGain, causticSpread);
  return vec4f((max(col, vec3f()) * mask), mask);
}
