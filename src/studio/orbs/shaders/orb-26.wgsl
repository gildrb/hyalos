// Compiled from unchanged shadercn orb-26 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: 7b29837b768f354c1dafaee697c578911c2ebf64db437708dfb5d158427d0aac
struct orb26Params {
  anim: f32,
  c_deep: vec3f,
  c_hot: vec3f,
  c_line: vec3f,
  c_sheen: vec3f,
  inputVol: f32,
  mouse: vec2f,
  outputVol: f32,
  p_bulge: f32,
  p_contrast: f32,
  p_core: f32,
  p_drift: f32,
  p_floor: f32,
  p_gain: f32,
  p_light: f32,
  p_pole: f32,
  p_poleSoft: f32,
  p_pulse: f32,
  p_radius: f32,
  p_rim: f32,
  p_scale: f32,
  p_sharp: f32,
  p_speed: f32,
  p_split: f32,
  p_swirl: f32,
  p_warp: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb26Params;

fn rot2(angle: f32) -> mat2x2f {
  let c = cos(angle);
  let s = sin(angle);
  return mat2x2f(vec2f(c, -(s)), vec2f(s, c));
}

fn hash(p: vec2f) -> f32 {
  return fract((sin(dot(p, vec2f(127.0999984741211, 311.70001220703125))) * 43758.5453123f));
}

fn latticeRender(fragCoord: vec2f, latticePole: f32, latticeSharp: f32, latticeGain: f32) -> vec3f {
  let u = (&params);
  let uv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let R = max((*u).p_radius, 1e-3f);
  let pl = (uv / R);
  let z = sqrt(max((1f - dot(pl, pl)), 0f));
  let n = vec3f(pl.x, pl.y, z);
  let t = (*u).p_speed;
  var p = ((n.xy / ((n.z + 1f) + (*u).p_bulge)) * (*u).p_scale);
  let sw = (*u).p_swirl;
  p = (rot2(sw) * p);
  p = vec2f((p.x + (*u).p_drift), p.y);
  p = (p + vec2f(0.3700000047683716, 0.20999999344348907));
  let cell = floor(p);
  let breathe = (1f + ((*u).p_pulse * sin(((6.28318530718f * hash(cell)) + (t * 0.35f)))));
  var c = p;
  for (var i = 0u; i < 9u; i += 1u) {
    let i_1 = (f32(i) + 1f);
    let delta = (cell - c);
    let pole = ((delta / ((delta * delta) + vec2f((*u).p_poleSoft))) * (latticePole * breathe));
    c = (c + ((cos((((c.yx * i_1) + pole) + t)) * (*u).p_warp) / i_1));
  }
  let x = (vec3f(c.y) + (vec3f(0, 2, 1) * (*u).p_split));
  let thread = exp((abs(sin(x)) * -(latticeSharp)));
  let lev = dot(thread, vec3f(0.3333333432674408));
  var col = ((*u).c_deep * (*u).p_floor);
  col = (col + ((thread * mix((*u).c_line, (*u).c_hot, smoothstep(0.12f, 1f, lev))) * latticeGain));
  var core = (lev * lev);
  core *= core;
  col = (col + ((*u).c_hot * (core * (*u).p_core)));
  col = pow(max(col, vec3f()), vec3f((*u).p_contrast));
  let lambert = clamp(dot(n, vec3f(-0.4448256194591522, 0.5436757802963257, 0.7117210030555725)), 0f, 1f);
  col = (col * (0.35f + ((*u).p_light * lambert)));
  let fres = (1f - z);
  let fresCubed = ((fres * fres) * fres);
  col = (col + ((*u).c_sheen * ((*u).p_rim * fresCubed)));
  return col;
}

struct orb26Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb26Fragment(_arg_0: orb26Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let orbUv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let latticePole = ((*u).p_pole * (1f + (0.8f * (*u).inputVol)));
  let latticeSharp = ((*u).p_sharp * (1f - (0.25f * (*u).outputVol)));
  let latticeGain = ((*u).p_gain * (0.85f + (0.4f * (*u).outputVol)));
  let mask = smoothstep(0.012f, -0.012f, (length(orbUv) - max((*u).p_radius, 1e-3f)));
  if ((mask <= 0f)) {
    return vec4f();
  }
  let col = latticeRender(fragCoord, latticePole, latticeSharp, latticeGain);
  let a = mask;
  return vec4f((max(col, vec3f()) * a), a);
}
