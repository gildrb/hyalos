// Compiled from unchanged shadercn orb-08 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: ec2d016f407ec1815471d72b50780195ab7da3ac9196e90a7e5d788cdbc3217d
struct orb08Params {
  anim: f32,
  c_crest: vec3f,
  c_deep: vec3f,
  c_low: vec3f,
  c_sheen: vec3f,
  inputVol: f32,
  mouse: vec2f,
  outputVol: f32,
  p_beat: f32,
  p_bulge: f32,
  p_contrast: f32,
  p_floor: f32,
  p_flow: f32,
  p_gain: f32,
  p_iris: f32,
  p_irisScale: f32,
  p_light: f32,
  p_radius: f32,
  p_rim: f32,
  p_scale: f32,
  p_speed: f32,
  p_split: f32,
  p_swirl: f32,
  p_thick: f32,
  p_view: f32,
  p_warp: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb08Params;

fn rot2(angle: f32) -> mat2x2f {
  let c = cos(angle);
  let s = sin(angle);
  return mat2x2f(vec2f(c, -(s)), vec2f(s, c));
}

fn tanh3(x: vec3f) -> vec3f {
  let clamped = clamp(x, vec3f(-10), vec3f(10));
  let e = exp((clamped * 2f));
  return ((e - 1f) / (e + 1f));
}

fn cotBands(x: vec3f, k: f32) -> vec3f {
  let b = tanh3(((cos(x) * k) / max(abs(sin(x)), vec3f(9.999999747378752e-5))));
  return (b * b);
}

fn nacreRender(fragCoord: vec2f, nacreWarp: f32, nacreThick: f32, nacreGain: f32) -> vec3f {
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
  p = vec2f(p.x, (p.y - (*u).p_flow));
  var q = p;
  for (var i = 0u; i < 10u; i += 1u) {
    let i_1 = (f32(i) + 1f);
    q = (q + ((sin((((q.yx * i_1) + ((i_1 * i_1) + (t * i_1))) + vec2f(4.699999809265137, 2.299999952316284))) * nacreWarp) / i_1));
  }
  let band = cotBands((vec3f(q.y) + (vec3f(0, 1, 3) * (*u).p_split)), nacreThick);
  let lev = dot(band, vec3f(0.3333333432674408));
  var col = ((*u).c_deep * (*u).p_floor);
  col = (col + ((band * mix((*u).c_low, (*u).c_crest, smoothstep(0.1f, 0.9f, lev))) * nacreGain));
  let irid = ((cos(((vec3f(0, 0.33000001311302185, 0.6700000166893005) + (((q.y * (*u).p_irisScale) + ((1f - z) * (*u).p_view)) + (t * 0.03f))) * 6.28318530718f)) * 0.5f) + 0.5f);
  col = mix(col, (col * ((irid * 1.9f) + 0.25f)), (*u).p_iris);
  col = pow(max(col, vec3f()), vec3f((*u).p_contrast));
  let lambert = clamp(dot(n, vec3f(-0.4448256194591522, 0.5436757802963257, 0.7117210030555725)), 0f, 1f);
  col = (col * (0.35f + ((*u).p_light * lambert)));
  let fres = (1f - z);
  let fresCubed = ((fres * fres) * fres);
  col = (col + ((*u).c_sheen * ((*u).p_rim * fresCubed)));
  return col;
}

struct orb08Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb08Fragment(_arg_0: orb08Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let orbUv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let beat = (0.5f - (0.5f * cos(((*u).anim * 5f))));
  let nacreWarp = mix(((*u).p_warp * (1f + (0.45f * (*u).inputVol))), mix(0.6f, 1.8f, beat), (*u).p_beat);
  let nacreThick = ((*u).p_thick * (1f + (0.6f * (*u).outputVol)));
  let nacreGain = ((*u).p_gain * (0.85f + (0.4f * (*u).outputVol)));
  let mask = smoothstep(0.012f, -0.012f, (length(orbUv) - max((*u).p_radius, 1e-3f)));
  if ((mask <= 0f)) {
    return vec4f();
  }
  let col = nacreRender(fragCoord, nacreWarp, nacreThick, nacreGain);
  return vec4f((max(col, vec3f()) * mask), mask);
}
