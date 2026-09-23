// Compiled from unchanged shadercn orb-30 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: 4ac859de8e95a38677e6e43902dd959bbb0569d7f9072fcc852c10b2a0455305
struct orb30Params {
  anim: f32,
  c_bloom: vec3f,
  c_canopy: vec3f,
  c_cloud: vec3f,
  c_meadow: vec3f,
  c_sheen: vec3f,
  c_sky: vec3f,
  c_water: vec3f,
  inputVol: f32,
  mouse: vec2f,
  outputVol: f32,
  p_bulge: f32,
  p_cloudCover: f32,
  p_cloudScale: f32,
  p_contrast: f32,
  p_drift: f32,
  p_fall: f32,
  p_flowerDensity: f32,
  p_flowerScale: f32,
  p_flowerSize: f32,
  p_frameShade: f32,
  p_gain: f32,
  p_haze: f32,
  p_hazeRange: f32,
  p_horizon: f32,
  p_light: f32,
  p_radius: f32,
  p_ratio: f32,
  p_rim: f32,
  p_saturation: f32,
  p_scale: f32,
  p_streakFreq: f32,
  p_streakRad: f32,
  p_tilt: f32,
  p_water: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb30Params;

fn rot2(angle: f32) -> mat2x2f {
  let c = cos(angle);
  let s = sin(angle);
  return mat2x2f(vec2f(c, -(s)), vec2f(s, c));
}

fn squareArc(q: vec2f) -> f32 {
  if ((abs(q.x) >= abs(q.y))) {
    if ((q.x > 0f)) {
      return (q.y + 1f);
    }
    return (5f - q.y);
  }
  if ((q.y > 0f)) {
    return (3f - q.x);
  }
  return (7f + q.x);
}

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

fn drosteFlower(h: f32) -> vec3f {
  let u = (&params);
  var c = (*u).c_cloud;
  c = mix(c, (*u).c_bloom, step(0.52f, h));
  c = mix(c, (*u).c_sky, step(0.86f, h));
  return c;
}

fn drosteRender(fragCoord: vec2f, drosteCloud: f32, drosteHaze: f32, drosteBloom: f32) -> vec3f {
  let u = (&params);
  let uv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let R = max((*u).p_radius, 1e-3f);
  let pl = (uv / R);
  let z = sqrt(max((1f - dot(pl, pl)), 0f));
  let fall = (*u).p_fall;
  let drift = (*u).p_drift;
  let sw = (*u).p_tilt;
  var p = ((pl / ((z + 1f) + (*u).p_bulge)) * (*u).p_scale);
  p = (rot2(sw) * p);
  let m = max(max(abs(p.x), abs(p.y)), 2e-3f);
  let K = max((*u).p_ratio, 1.05f);
  let L = ((log2(m) / log2(K)) + fall);
  let q = (p / m);
  let sm = pow(K, fract(L));
  let P = (q * sm);
  let Yn = (P.y / K);
  let arc = squareArc(q);
  var col = mix(((*u).c_sky * 0.72f), (*u).c_sky, clamp((Yn * 1.3f), 0f, 1f));
  let skyMask = smoothstep(((*u).p_horizon - 0.3f), ((*u).p_horizon + 0.2f), Yn);
  var cl = fbm(((P * (*u).p_cloudScale) + vec2f(drift, (drift * 0.3f))));
  cl = smoothstep(drosteCloud, (drosteCloud + 0.16f), cl);
  col = mix(col, (*u).c_cloud, (cl * (0.2f + (0.8f * skyMask))));
  let streak = fbm(vec2f((arc * (*u).p_streakFreq), (L * (*u).p_streakRad)));
  var land = mix((*u).c_canopy, (*u).c_meadow, smoothstep(0.02f, -0.62f, Yn));
  land = (land * (0.42f + (1.25f * streak)));
  let water = (smoothstep(0.42f, 0.16f, streak) * smoothstep(0.05f, -0.3f, Yn));
  land = mix(land, (*u).c_water, (water * (*u).p_water));
  let fg = vec2f((arc * (*u).p_flowerScale), ((L * (*u).p_flowerScale) * 0.3f));
  let fc = floor(fg);
  let ff = (fract(fg) - 0.5f);
  let dcv = (ff - ((vec2f(hash((fc + 3.7f)), hash((fc + 19.1f))) - 0.5f) * 0.6f));
  let petal = smoothstep((*u).p_flowerSize, ((*u).p_flowerSize * 0.35f), length(dcv));
  let present = step((1f - drosteBloom), hash((fc + 51.3f)));
  let meadow = smoothstep(0.13f, -0.38f, Yn);
  land = mix(land, drosteFlower(hash((fc + 7.9f))), ((petal * present) * meadow));
  let landMask = (1f - smoothstep(((*u).p_horizon - 0.12f), ((*u).p_horizon + 0.16f), Yn));
  col = mix(col, land, landMask);
  col = (col * mix(1f, (*u).p_frameShade, fract(L)));
  let deep = (1f - smoothstep(0f, (*u).p_hazeRange, m));
  col = mix(col, (*u).c_sky, (deep * drosteHaze));
  col = (pow(max(col, vec3f()), vec3f((*u).p_contrast)) * (*u).p_gain);
  let lum = dot(col, vec3f(0.29899999499320984, 0.5870000123977661, 0.11400000005960464));
  col = mix(vec3f(lum), col, (*u).p_saturation);
  let n = vec3f(pl, z);
  let lambert = clamp(dot(n, vec3f(-0.4448256194591522, 0.5436757802963257, 0.7117210030555725)), 0f, 1f);
  col = (col * (0.72f + ((*u).p_light * lambert)));
  let fres = (1f - z);
  let fresCubed = ((fres * fres) * fres);
  col = (col + ((*u).c_sheen * ((*u).p_rim * fresCubed)));
  return col;
}

struct orb30Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb30Fragment(_arg_0: orb30Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let orbUv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let drosteCloud = clamp(((*u).p_cloudCover - (0.12f * (*u).inputVol)), 0.02f, 0.98f);
  let drosteHaze = ((*u).p_haze * (1f - (0.25f * (*u).outputVol)));
  let drosteBloom = clamp(((*u).p_flowerDensity * (1f + (0.5f * (*u).outputVol))), 0f, 1f);
  let mask = smoothstep(0.012f, -0.012f, (length(orbUv) - max((*u).p_radius, 1e-3f)));
  if ((mask <= 0f)) {
    return vec4f();
  }
  let col = drosteRender(fragCoord, drosteCloud, drosteHaze, drosteBloom);
  let a = mask;
  return vec4f((max(col, vec3f()) * a), a);
}
