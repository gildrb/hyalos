// Compiled from unchanged shadercn orb-18 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: c2c73170b0a6d9cc553ee55afca2ea5f593dcf0d8a170a81d67d294615c2902e
struct orb18Params {
  anim: f32,
  c_tint: vec3f,
  inputVol: f32,
  mouse: vec2f,
  outputVol: f32,
  p_alphaGain: f32,
  p_camDist: f32,
  p_contrast: f32,
  p_crease: f32,
  p_edge: f32,
  p_edgeFade: f32,
  p_envCore: f32,
  p_envRadius: f32,
  p_exposure: f32,
  p_fill: f32,
  p_focal: f32,
  p_fold: f32,
  p_freq: f32,
  p_hue: f32,
  p_saturation: f32,
  p_scatter: f32,
  p_spread: f32,
  p_stepClamp: f32,
  p_stepScale: f32,
  p_wander: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb18Params;

fn octantRender(fragCoord: vec2f, octantFold: f32, octantFreq: f32) -> vec3f {
  let u = (&params);
  let uv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let ro = vec3f(0f, 0f, (*u).p_camDist);
  let rd = normalize(vec3f(uv.x, uv.y, -((*u).p_focal)));
  let wander = (*u).p_wander;
  let axis = normalize(cos((vec3f(0, 2, 4) + wander)));
  var acc = vec3f();
  var T = 1f;
  var z = max(((*u).p_camDist - ((*u).p_envRadius * 1.3f)), 0f);
  let zEnd = ((*u).p_camDist + ((*u).p_envRadius * 1.3f));
  for (var i = 0u; i < 50u; i += 1u) {
    let p = (ro + (rd * z));
    var a = ((axis * dot(axis, p)) - cross(axis, p));
    a = mix(a, abs(a), octantFold);
    a = mix(a, max(a, a.yzx), (*u).p_crease);
    var dist = ((*u).p_stepScale * length(cos((a * octantFreq))));
    dist = max(dist, ((*u).p_envRadius * 4e-3f));
    let zRel = (z - ((*u).p_camDist - (*u).p_envRadius));
    var w = (cos(((vec3f(0, 2, 3) * (*u).p_spread) + ((*u).p_hue * zRel))) + 1f);
    w = (w / (dist * max(z, 0.05f)));
    w = min(w, vec3f((*u).p_stepClamp));
    let env = smoothstep(((*u).p_envRadius * 1.12f), ((*u).p_envRadius * (*u).p_envCore), length(p));
    w = ((w + (*u).p_fill) * env);
    acc = (acc + (w * T));
    T *= exp((-(dot(w, vec3f(0.29899999499320984, 0.5870000123977661, 0.11400000005960464))) * (*u).p_scatter));
    z += dist;
    if (((T < 4e-3f) || (z > zEnd))) {
      break;
    }
  }
  return acc;
}

fn tanh3(x: vec3f) -> vec3f {
  let clamped = clamp(x, vec3f(-10), vec3f(10));
  let e = exp((clamped * 2f));
  return ((e - 1f) / (e + 1f));
}

struct orb18Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb18Fragment(_arg_0: orb18Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let orbUv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let octantFold = clamp(((*u).p_fold * (1f + (0.3f * (*u).inputVol))), 0f, 1f);
  let octantFreq = ((*u).p_freq * (1f + (0.25f * (*u).inputVol)));
  let octantExposure = ((*u).p_exposure * (1f - (0.35f * (*u).outputVol)));
  let acc = octantRender(fragCoord, octantFold, octantFreq);
  var col = tanh3((acc / max(octantExposure, 0.01f)));
  col = pow(clamp(col, vec3f(), vec3f(1)), vec3f((*u).p_contrast));
  let lum = dot(col, vec3f(0.29899999499320984, 0.5870000123977661, 0.11400000005960464));
  col = (mix(vec3f(lum), col, (*u).p_saturation) * (*u).c_tint);
  let peak = max(col.x, max(col.y, col.z));
  var alpha = clamp((peak * (*u).p_alphaGain), 0f, 1f);
  let mrd = normalize(vec3f(orbUv.x, orbUv.y, -((*u).p_focal)));
  let closest = length(cross(vec3f(0f, 0f, (*u).p_camDist), mrd));
  let band = mix(0.35f, 0.012f, clamp((*u).p_edge, 0f, 1f));
  let mask = (1f - smoothstep(((*u).p_envRadius * (1f - band)), ((*u).p_envRadius * 1.005f), closest));
  col = (col * mask);
  alpha *= mask;
  let fade = (1f - smoothstep((*u).p_edgeFade, 1f, length(orbUv)));
  col = (col * fade);
  alpha *= fade;
  return vec4f(col, alpha);
}
