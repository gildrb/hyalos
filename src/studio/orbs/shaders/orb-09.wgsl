// Compiled from unchanged shadercn orb-09 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: 5a4be4530c7bc64a238e7218f13bc76229103712354959bac4d42285273bc25f
struct orb09Params {
  anim: f32,
  c_sheen: vec3f,
  c_tint: vec3f,
  inputVol: f32,
  mouse: vec2f,
  outputVol: f32,
  p_contrast: f32,
  p_exposure: f32,
  p_fringe: f32,
  p_fringeSoft: f32,
  p_glow: f32,
  p_inner: f32,
  p_light: f32,
  p_lineSoft: f32,
  p_radius: f32,
  p_rim: f32,
  p_ringPhase: f32,
  p_saturation: f32,
  p_scale: f32,
  p_seed: f32,
  p_speed: f32,
  p_spin: f32,
  p_tilt: f32,
  p_warp: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb09Params;

fn tanh3(x: vec3f) -> vec3f {
  let clamped = clamp(x, vec3f(-10), vec3f(10));
  let e = exp((clamped * 2f));
  return ((e - 1f) / (e + 1f));
}

fn irisRender(fragCoord: vec2f, irisWarp: f32, irisGlow: f32, irisFringe: f32) -> vec3f {
  let u = (&params);
  let uv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let R = max((*u).p_radius, 1e-3f);
  let pl = (uv / R);
  let z = sqrt(max((1f - dot(pl, pl)), 0f));
  let n = vec3f(pl.x, pl.y, z);
  let t = (*u).p_speed;
  let ct = cos((*u).p_tilt);
  let st = sin((*u).p_tilt);
  var sp = vec3f(n.x, ((n.y * ct) - (n.z * st)), ((n.y * st) + (n.z * ct)));
  let cr = cos((*u).p_spin);
  let sr = sin((*u).p_spin);
  sp = vec3f(((sp.x * cr) - (sp.z * sr)), sp.y, ((sp.x * sr) + (sp.z * cr)));
  let pol = acos(clamp(sp.z, -1f, 1f));
  let dir = (sp.xy / max(length(sp.xy), 1e-4f));
  let p = (dir * (pol * (*u).p_scale));
  var acc = vec3f();
  for (var i = 0u; i < 10u; i += 1u) {
    let i_1 = (f32(i) + 1f);
    var v = p;
    for (var i_2 = 0u; i_2 < 9u; i_2 += 1u) {
      let f = (f32(i_2) + 1f);
      v = (v + ((sin((ceil(((v * f) + (i_1 * (*u).p_seed))) - (t * 0.5f))) * irisWarp) / f));
    }
    let l = (length(v) - i_1);
    let side = max(max(l, (-((*u).p_inner) * l)), (*u).p_lineSoft);
    let fr = ((irisFringe * l) / ((l * l) + (*u).p_fringeSoft));
    let hue = (cos((vec3f(0, 1, 2) + ((t - (i_1 * (*u).p_ringPhase)) + fr))) + 1.1f);
    acc = (acc + (hue * (irisGlow / side)));
  }
  var col = tanh3((acc / max((*u).p_exposure, 1e-3f)));
  col = pow(clamp(col, vec3f(), vec3f(1)), vec3f((*u).p_contrast));
  let lum = dot(col, vec3f(0.29899999499320984, 0.5870000123977661, 0.11400000005960464));
  col = (mix(vec3f(lum), col, (*u).p_saturation) * (*u).c_tint);
  let lambert = clamp(dot(n, vec3f(-0.4448256194591522, 0.5436757802963257, 0.7117210030555725)), 0f, 1f);
  col = (col * (0.55f + ((*u).p_light * lambert)));
  let fres = (1f - z);
  let fresCubed = ((fres * fres) * fres);
  col = (col + ((*u).c_sheen * ((*u).p_rim * fresCubed)));
  return col;
}

struct orb09Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb09Fragment(_arg_0: orb09Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let orbUv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let irisWarp = ((*u).p_warp * (1f + (0.5f * (*u).inputVol)));
  let irisGlow = ((*u).p_glow * (0.85f + (0.5f * (*u).outputVol)));
  let irisFringe = ((*u).p_fringe * (1f + (0.6f * (*u).outputVol)));
  let mask = smoothstep(0.012f, -0.012f, (length(orbUv) - max((*u).p_radius, 1e-3f)));
  if ((mask <= 0f)) {
    return vec4f();
  }
  let col = irisRender(fragCoord, irisWarp, irisGlow, irisFringe);
  return vec4f((max(col, vec3f()) * mask), mask);
}
