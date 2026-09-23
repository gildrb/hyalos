// Compiled from unchanged shadercn orb-25 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: 4ac2faa532e60812af393a9aae560d0b26a27a0de9a719afe8a35507ef18d2ae
struct orb25Params {
  anim: f32,
  c_body: vec3f,
  c_sheen: vec3f,
  c_tint: vec3f,
  inputVol: f32,
  mouse: vec2f,
  outputVol: f32,
  p_blur: f32,
  p_bulge: f32,
  p_contrast: f32,
  p_drift: f32,
  p_edgeGain: f32,
  p_exposure: f32,
  p_floorLevel: f32,
  p_fringe: f32,
  p_light: f32,
  p_radius: f32,
  p_rim: f32,
  p_ripple: f32,
  p_saturation: f32,
  p_scale: f32,
  p_speed: f32,
  p_swirl: f32,
  p_warp: f32,
  p_zoom: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb25Params;

fn rot2(angle: f32) -> mat2x2f {
  let c = cos(angle);
  let s = sin(angle);
  return mat2x2f(vec2f(c, -(s)), vec2f(s, c));
}

fn creaseField(fragCoord: vec2f, t: f32, drift: f32, sw: f32, creaseWarp: f32) -> vec2f {
  let u = (&params);
  let uv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let pl = (uv / max((*u).p_radius, 1e-3f));
  let z = sqrt(max((1f - dot(pl, pl)), 0f));
  var p = ((pl / ((z + 1f) + (*u).p_bulge)) * (*u).p_scale);
  p = (rot2(sw) * p);
  p = (p + drift);
  let octaveRot = mat2x2f(0.6000000238418579, -0.800000011920929, 0.800000011920929, 0.6000000238418579);
  for (var i = 0u; i < 8u; i += 1u) {
    let fi = (f32(i) + 1f);
    p = (p + (sin(((p + t) + fi)) * creaseWarp));
    p = ((octaveRot * p) * (*u).p_zoom);
  }
  return p;
}

fn tanh1(xIn: f32) -> f32 {
  let x = clamp(xIn, -10f, 10f);
  let e = exp((2f * x));
  return ((e - 1f) / (e + 1f));
}

fn creaseRender(fragCoord: vec2f, creaseWarp: f32, creaseGain: f32) -> vec3f {
  let u = (&params);
  let t = (*u).p_speed;
  let drift = (*u).p_drift;
  let sw = (*u).p_swirl;
  let p0 = creaseField(fragCoord, t, drift, sw, creaseWarp);
  let px = creaseField((fragCoord + vec2f((*u).p_blur, 0f)), t, drift, sw, creaseWarp);
  let py = creaseField((fragCoord + vec2f(0f, (*u).p_blur)), t, drift, sw, creaseWarp);
  var e = vec3f();
  for (var i = 0u; i < 3u; i += 1u) {
    let ph = (f32(i) * (*u).p_fringe);
    let v0 = sin(((p0 * (*u).p_ripple) + ph));
    let delta = (abs((sin(((px * (*u).p_ripple) + ph)) - v0)) + abs((sin(((py * (*u).p_ripple) + ph)) - v0)));
    let m = tanh1(((length(delta) * creaseGain) / max((*u).p_exposure, 1e-3f)));
    if ((i == 0u)) {
      e = vec3f(m, e.y, e.z);
    }
    else {
      if ((i == 1u)) {
        e = vec3f(e.x, m, e.z);
      }
      else {
        e = vec3f(e.x, e.y, m);
      }
    }
  }
  e = pow(clamp(e, vec3f(), vec3f(1)), vec3f((*u).p_contrast));
  var col = ((*u).c_tint * e);
  col = (col + ((*u).c_body * (*u).p_floorLevel));
  let lum = dot(col, vec3f(0.29899999499320984, 0.5870000123977661, 0.11400000005960464));
  col = mix(vec3f(lum), col, (*u).p_saturation);
  let pl = ((((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y)) / max((*u).p_radius, 1e-3f));
  let z = sqrt(max((1f - dot(pl, pl)), 0f));
  let n = vec3f(pl.x, pl.y, z);
  let lambert = clamp(dot(n, vec3f(-0.4448256194591522, 0.5436757802963257, 0.7117210030555725)), 0f, 1f);
  col = (col * (0.62f + ((*u).p_light * lambert)));
  let fres = (1f - z);
  let fresCubed = ((fres * fres) * fres);
  col = (col + ((*u).c_sheen * ((*u).p_rim * fresCubed)));
  return col;
}

struct orb25Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb25Fragment(_arg_0: orb25Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let orbUv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let creaseWarp = ((*u).p_warp * (1f + (0.4f * (*u).inputVol)));
  let creaseGain = ((*u).p_edgeGain * (1f + (0.5f * (*u).outputVol)));
  let mask = smoothstep(0.012f, -0.012f, (length(orbUv) - max((*u).p_radius, 1e-3f)));
  if ((mask <= 0f)) {
    return vec4f();
  }
  let col = creaseRender(fragCoord, creaseWarp, creaseGain);
  let a = mask;
  return vec4f((max(col, vec3f()) * a), a);
}
