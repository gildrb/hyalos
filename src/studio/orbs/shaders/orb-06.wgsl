// Compiled from unchanged shadercn orb-06 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: ca1f60b1a393b76e277fea3f69b013508ca4ea12e32b0a15321a62cc7cb65ab5
struct orb06Params {
  anim: f32,
  c_sheen: vec3f,
  c_tint: vec3f,
  inputVol: f32,
  mouse: vec2f,
  outputVol: f32,
  p_bulge: f32,
  p_contrast: f32,
  p_depth: f32,
  p_drift: f32,
  p_exposure: f32,
  p_freq: f32,
  p_glowSize: f32,
  p_hueRate: f32,
  p_light: f32,
  p_radius: f32,
  p_rim: f32,
  p_saturation: f32,
  p_scale: f32,
  p_speed: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb06Params;

fn tanh3(x: vec3f) -> vec3f {
  let clamped = clamp(x, vec3f(-10), vec3f(10));
  let e = exp((clamped * 2f));
  return ((e - 1f) / (e + 1f));
}

fn moireRender(fragCoord: vec2f, moireDrift: f32, moireGlow: f32, moireHue: f32) -> vec3f {
  let u = (&params);
  let uv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let R = max((*u).p_radius, 1e-3f);
  let pl = (uv / R);
  let z = sqrt(max((1f - dot(pl, pl)), 0f));
  let t = (*u).p_speed;
  let bulge = (1f + (*u).p_bulge);
  let den0 = (z + bulge);
  var w = ((pl / den0) * (*u).p_scale);
  var acc = vec3f();
  for (var i = 0u; i < 100u; i += 1u) {
    let f = (f32(i) + 1f);
    let layerT = (f / 100f);
    let depth = (layerT * (*u).p_depth);
    let denu = ((z - depth) + (bulge * sqrt(max(((1f - ((2f * depth) * z)) + (depth * depth)), 0f))));
    let q = (w * (den0 / max(denu, 0.05f)));
    let k = (sin((vec2f(11.300000190734863, 12.869999885559082) + f)) / max((*u).p_freq, 1e-3f));
    let g = max(length(sin((q * k))), moireGlow);
    let hue = (cos((vec3f(0, 1, 3) + (f * moireHue))) + 1.1f);
    acc = (acc + (hue / g));
    w = (w + (sin((w.yx + t)) * moireDrift));
  }
  let v = (acc / 100f);
  var col = tanh3(((v * v) / max((*u).p_exposure, 1e-4f)));
  col = pow(clamp(col, vec3f(), vec3f(1)), vec3f((*u).p_contrast));
  let lum = dot(col, vec3f(0.29899999499320984, 0.5870000123977661, 0.11400000005960464));
  col = (mix(vec3f(lum), col, (*u).p_saturation) * (*u).c_tint);
  let n = vec3f(pl.x, pl.y, z);
  let lambert = clamp(dot(n, vec3f(-0.4448256194591522, 0.5436757802963257, 0.7117210030555725)), 0f, 1f);
  col = (col * (0.6f + ((*u).p_light * lambert)));
  let fres = (1f - z);
  let fresCubed = ((fres * fres) * fres);
  col = (col + ((*u).c_sheen * ((*u).p_rim * fresCubed)));
  return col;
}

struct orb06Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb06Fragment(_arg_0: orb06Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let orbUv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let moireDrift = ((*u).p_drift * (1f + (0.6f * (*u).inputVol)));
  let moireGlow = max(((*u).p_glowSize * (1f - (0.3f * (*u).outputVol))), 2e-3f);
  let moireHue = ((*u).p_hueRate * (1f + (0.35f * (*u).outputVol)));
  let mask = smoothstep(0.012f, -0.012f, (length(orbUv) - max((*u).p_radius, 1e-3f)));
  if ((mask <= 0f)) {
    return vec4f();
  }
  let col = moireRender(fragCoord, moireDrift, moireGlow, moireHue);
  return vec4f((max(col, vec3f()) * mask), mask);
}
