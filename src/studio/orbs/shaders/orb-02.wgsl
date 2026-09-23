// Compiled from unchanged shadercn orb-02 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: f71aba860d86a5e07a24350396672bddecae32e2716788ba991899b9cf5ecbfc
struct orb02Params {
  anim: f32,
  inputVol: f32,
  mouse: vec2f,
  outputVol: f32,
  p_alphaGain: f32,
  p_baseVis: f32,
  p_bulge: f32,
  p_coreClamp: f32,
  p_falloff: f32,
  p_gain: f32,
  p_hueShift: f32,
  p_radius: f32,
  p_rim: f32,
  p_rimPow: f32,
  p_speed: f32,
  p_swell: f32,
  p_swirl: f32,
  p_warpFreq: f32,
  p_zoom: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb02Params;

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

struct orb02Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb02Fragment(_arg_0: orb02Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let orbUv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let R = ((*u).p_radius + ((*u).p_swell * (*u).inputVol));
  let r2d = length(orbUv);
  let mask = smoothstep(0.012f, -0.012f, (r2d - R));
  let nr = clamp((r2d / max(R, 1e-3f)), 0f, 1f);
  let z = sqrt(max((1f - (nr * nr)), 0f));
  let animTime = (*u).p_speed;
  let sp = vec3f((orbUv / max(R, 1e-3f)), z);
  var p = ((sp.xy / ((sp.z + 1f) + (*u).p_bulge)) * (*u).p_zoom);
  let sw = (animTime * (*u).p_swirl);
  p = (rot2(sw) * p);
  let warpFreq = ((*u).p_warpFreq * (1f + (0.35f * (*u).inputVol)));
  let gain = ((*u).p_gain * (0.75f + (0.7f * (*u).outputVol)));
  var acc = vec4f();
  for (var i = 0u; i < 10u; i += 1u) {
    let fi = (f32(i) + 1f);
    var v = p;
    for (var i_1 = 0u; i_1 < 9u; i_1 += 1u) {
      let f = (f32(i_1) + 1f);
      v = (v + (sin((((v.yx * (f * warpFreq)) + fi) + animTime)) / f));
    }
    let rad = pow(max(length(v), (*u).p_coreClamp), (*u).p_falloff);
    acc = (acc + (((cos(((vec4f(0, 1, 2, 3) + fi) + (*u).p_hueShift)) + 1f) / 6f) / rad));
  }
  var col = tanh3(((acc.xyz * acc.xyz) * gain));
  let fresnel = pow((1f - z), (*u).p_rimPow);
  col = (col + (vec3f(fresnel) * (*u).p_rim));
  let lum = dot(col, vec3f(0.2125999927520752, 0.7152000069618225, 0.0722000002861023));
  let visibility = clamp((((lum * (*u).p_alphaGain) + (*u).p_baseVis) + (fresnel * 0.25f)), 0f, 1f);
  let a = (mask * visibility);
  return vec4f((col * a), a);
}
