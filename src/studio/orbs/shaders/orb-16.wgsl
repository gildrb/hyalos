// Compiled from unchanged shadercn orb-16 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: 2a9f4ccb6cff4af4919b272f0747fd2085b5a7f09ef8915311515d806cc4ab27
struct orb16Params {
  anim: f32,
  c_deep: vec3f,
  c_sheen: vec3f,
  c_sun: vec3f,
  inputVol: f32,
  mouse: vec2f,
  outputVol: f32,
  p_contrast: f32,
  p_edge: f32,
  p_flow: f32,
  p_gain: f32,
  p_light: f32,
  p_radius: f32,
  p_rim: f32,
  p_scale: f32,
  p_spin: f32,
  p_split: f32,
  p_swell: f32,
  p_swellRate: f32,
  p_warp: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb16Params;

fn fold(p: vec2f, t: f32, warp: f32) -> vec2f {
  var q = p;
  q = (q + (sin(((q.yx * 1.31f) + vec2f((t * 0.9f), (-(t) * 0.7f)))) * warp));
  q = (q + (sin(((q.yx * 2.17f) + vec2f((-(t) * 1.3f), (t * 1.1f)))) * (warp * 0.6f)));
  q = (q + (sin(((q.yx * 3.73f) + vec2f((t * 1.9f), (t * 1.6f)))) * (warp * 0.35f)));
  return q;
}

fn net(p: vec2f, t: f32, warp: f32) -> f32 {
  let u = (&params);
  let q = fold(p, t, warp);
  let s = (vec2f(1) - abs(sin(q)));
  let l = pow(s, vec2f((*u).p_edge));
  return (((l.x + l.y) + ((2f * l.x) * l.y)) * 0.25f);
}

fn netOn(sp: vec3f, t: f32, warp: f32) -> f32 {
  let u = (&params);
  var w = (sp * sp);
  w = (w * w);
  w = (w / ((w.x + w.y) + w.z));
  let k = (*u).p_scale;
  return (((w.x * net((sp.yz * k), t, warp)) + (w.y * net((sp.zx * k), t, warp))) + (w.z * net((sp.xy * k), t, warp)));
}

fn tanh3(x: vec3f) -> vec3f {
  let clamped = clamp(x, vec3f(-10), vec3f(10));
  let e = exp((clamped * 2f));
  return ((e - 1f) / (e + 1f));
}

struct orb16Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb16Fragment(_arg_0: orb16Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let uv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let rd = length(uv);
  let R = (*u).p_radius;
  let mask = smoothstep(0.012f, -0.012f, (rd - R));
  if ((mask <= 0f)) {
    return vec4f();
  }
  let pl = (uv / R);
  let z = sqrt(max((1f - dot(pl, pl)), 0f));
  let n = vec3f(pl.x, pl.y, z);
  let cr = cos((*u).p_spin);
  let sr = sin((*u).p_spin);
  let sp = vec3f(((n.x * cr) - (n.z * sr)), n.y, ((n.x * sr) + (n.z * cr)));
  let t = (*u).p_flow;
  let surge = (0.5f - (0.5f * cos((*u).p_swellRate)));
  let gainNow = (((*u).p_gain * mix(1f, (0.55f + (0.9f * surge)), (*u).p_swell)) * (0.8f + (0.5f * (*u).outputVol)));
  let causticWarp = (((*u).p_warp * mix(1f, (0.8f + (0.4f * surge)), (*u).p_swell)) * (1f + (0.35f * (*u).inputVol)));
  const ds = 0.09000000357627869f;
  let c = vec3f(netOn(sp, (t + ds), causticWarp), netOn(sp, t, causticWarp), netOn(sp, (t - ds), causticWarp));
  let cLum = dot(c, vec3f(0.3333333432674408));
  let fringe = ((c - cLum) * (*u).p_split);
  let lambert = clamp(dot(n, vec3f(-0.4511292278766632, 0.5513802170753479, 0.7017565965652466)), 0f, 1f);
  let fres = pow((1f - z), 2.5f);
  var col = ((*u).c_deep * (0.35f + ((0.65f * (*u).p_light) * lambert)));
  col = (col + ((((*u).c_sun * cLum) + fringe) * (gainNow * (0.55f + (0.45f * lambert)))));
  col = (col + ((*u).c_sheen * ((*u).p_rim * fres)));
  col = pow(max(col, vec3f()), vec3f((*u).p_contrast));
  col = tanh3(col);
  let alpha = mask;
  return vec4f((max(col, vec3f()) * alpha), alpha);
}
