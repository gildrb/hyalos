// Compiled from unchanged shadercn orb-17 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: c9b8c84dcdf9e342f77b644e35a078f67305e41c9b22fd61b65c84a819fd9f1a
struct orb17Params {
  anim: f32,
  c_deep: vec3f,
  c_flash: vec3f,
  c_hot: vec3f,
  c_low: vec3f,
  c_mid: vec3f,
  inputVol: f32,
  mouse: vec2f,
  outputVol: f32,
  p_bands: f32,
  p_churn: f32,
  p_contrast: f32,
  p_filmGrain: f32,
  p_flash: f32,
  p_flashRate: f32,
  p_gain: f32,
  p_grain: f32,
  p_grainSize: f32,
  p_light: f32,
  p_radius: f32,
  p_rainbow: f32,
  p_rim: f32,
  p_scale: f32,
  p_shear: f32,
  p_speed: f32,
  p_spin: f32,
  p_warp: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb17Params;

fn hash(p: vec2f) -> f32 {
  return fract((sin(dot(p, vec2f(127.0999984741211, 311.70001220703125))) * 43758.5453123f));
}

fn noise(p: vec2f) -> f32 {
  let i = floor(p);
  let f = fract(p);
  let ff = ((f * f) * (vec2f(3) - (f * 2f)));
  return mix(mix(hash(i), hash((i + vec2f(1, 0))), ff.x), mix(hash((i + vec2f(0, 1))), hash((i + vec2f(1))), ff.x), ff.y);
}

fn fbm(pIn: vec2f) -> f32 {
  var p = pIn;
  var v = 0f;
  var a = 0.5f;
  for (var i = 0u; i < 5u; i += 1u) {
    v += (a * noise(p));
    p = ((p * 2.03f) + vec2f(11.699999809265137, 7.300000190734863));
    a *= 0.5f;
  }
  return v;
}

fn grainNoise(gpix: vec2f, frame: f32, seed: f32) -> f32 {
  return hash((gpix + vec2f(((frame * 13.71f) + seed), ((frame * 7.37f) - seed))));
}

struct orb17Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb17Fragment(_arg_0: orb17Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let uv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let warpNow = ((*u).p_warp * (1f + (0.55f * (*u).inputVol)));
  let gainNow = ((*u).p_gain * (0.85f + (0.45f * (*u).outputVol)));
  let rd = length(uv);
  let R = (*u).p_radius;
  let mask = smoothstep(0.012f, -0.012f, (rd - R));
  if ((mask <= 0f)) {
    return vec4f();
  }
  let pl = (uv / R);
  let r2 = dot(pl, pl);
  let z = sqrt(max((1f - r2), 0f));
  let n = vec3f(pl.x, pl.y, z);
  let cr = cos((*u).p_spin);
  let sr = sin((*u).p_spin);
  let sp = vec3f(((n.x * cr) - (n.z * sr)), n.y, ((n.x * sr) + (n.z * cr)));
  let t = (*u).p_speed;
  var st = ((sp.xy / (1.3f + sp.z)) * (*u).p_scale);
  st = vec2f((st.x - (t * 0.3f)), st.y);
  st = vec2f((st.x + ((*u).p_shear * sin(((sp.y * (*u).p_bands) - (t * 0.45f))))), st.y);
  let q = vec2f(fbm((st + vec2f(0f, (t * 0.35f)))), fbm(((st + vec2f(5.199999809265137, 1.2999999523162842)) - vec2f((t * 0.28f), 0f))));
  let w = vec2f(fbm((((st + (q * warpNow)) + vec2f(1.7000000476837158, 9.199999809265137)) + vec2f((t * 0.12f), 0f))), fbm((((st + (q * warpNow)) + vec2f(8.300000190734863, 2.799999952316284)) - vec2f(0f, (t * 0.1f)))));
  var f = fbm((st + (w * (*u).p_churn)));
  let gpix = floor((fragCoord / max((*u).p_grainSize, 1f)));
  let frame = floor(((*u).time * 48f));
  let g1 = grainNoise(gpix, frame, 3.1f);
  f += ((g1 - 0.5f) * (*u).p_grain);
  f = pow(clamp((f * gainNow), 0f, 1f), (*u).p_contrast);
  var col = mix((*u).c_deep, (*u).c_low, smoothstep(0.05f, 0.35f, f));
  col = mix(col, (*u).c_mid, smoothstep(0.35f, 0.62f, f));
  col = mix(col, (*u).c_hot, smoothstep(0.62f, 0.88f, f));
  let shimmer = (vec3f(0.5) + (cos(((vec3f(0, 0.33000001311302185, 0.6700000166893005) + (((f * 0.9f) + (q.x * 1.1f)) + (t * 0.06f))) * 6.283185307179586f)) * 0.5f));
  col = mix(col, (col * ((shimmer * 1.9f) + 0.35f)), (*u).p_rainbow);
  let ft = (t * (*u).p_flashRate);
  let gate = step((1f - (0.1f + (0.5f * (*u).outputVol))), hash(vec2f(floor(ft), 7.7f)));
  let flashEnv = (gate * exp((-(fract(ft)) * 6f)));
  let high = smoothstep(0.55f, 0.95f, f);
  col = (col + (((*u).c_flash * (flashEnv * (*u).p_flash)) * (0.06f + ((0.94f * high) * high))));
  let lambert = clamp(dot(n, vec3f(-0.4511292278766632, 0.5513802170753479, 0.7017565965652466)), 0f, 1f);
  col = (col * (0.35f + ((*u).p_light * lambert)));
  let fres = pow((1f - z), 2.5f);
  col = (col + ((*u).c_flash * (((*u).p_rim * fres) * (0.4f + (0.35f * flashEnv)))));
  let g2 = grainNoise(gpix, frame, 27.9f);
  col = (col * (1f + ((g2 - 0.5f) * (*u).p_filmGrain)));
  let alpha = mask;
  return vec4f((max(col, vec3f()) * alpha), alpha);
}
