// Compiled from unchanged shadercn orb-15 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: e26a9683f21a09345ed9971651689e8f9e39c11a1c3180a8e22aa0e40793fca1
struct orb15Params {
  anim: f32,
  c_tint: vec3f,
  inputVol: f32,
  mouse: vec2f,
  outputVol: f32,
  p_alphaGain: f32,
  p_camDist: f32,
  p_contrast: f32,
  p_disperse: f32,
  p_edge: f32,
  p_edgeFade: f32,
  p_envCore: f32,
  p_envRadius: f32,
  p_exposure: f32,
  p_fieldScale: f32,
  p_fill: f32,
  p_focal: f32,
  p_saturation: f32,
  p_scatter: f32,
  p_speed: f32,
  p_stepClamp: f32,
  p_stepScale: f32,
  p_turb: f32,
  p_wander: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb15Params;

fn muonsRender(fragCoord: vec2f, muonsTurb: f32) -> vec3f {
  let u = (&params);
  let animTime = (*u).p_speed;
  let wander = (*u).p_wander;
  let uv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let ro = vec3f(0f, 0f, (*u).p_camDist);
  let rd = normalize(vec3f(uv.x, uv.y, -((*u).p_focal)));
  let proj = dot((ro * -1f), rd);
  let b2 = (dot(ro, ro) - (proj * proj));
  let R = ((*u).p_envRadius * 0.96f);
  let entry = (proj - sqrt(max(((R * R) - b2), 0f)));
  var acc = vec3f();
  var T = 1f;
  var z = entry;
  var s = 0f;
  for (var i = 0u; i < 10u; i += 1u) {
    let p = (ro + (rd * z));
    let q = (p * (*u).p_fieldScale);
    let axis = normalize(cos(((vec3f(7, 1, 0) + wander) - s)));
    var a = ((axis * dot(axis, q)) - cross(axis, q));
    for (var i_1 = 0u; i_1 < 8u; i_1 += 1u) {
      let dj = (f32(i_1) + 2f);
      let wave = sin(((a * dj) + animTime));
      a = (a + ((wave.yzx * muonsTurb) / dj));
    }
    s = length(a);
    var dist = ((*u).p_stepScale * abs(sin(s)));
    dist = max(dist, 1e-5f);
    z += dist;
    var w = (((cos(((vec3f(0, 2, 3) * (*u).p_disperse) + (((z - entry) / max((*u).p_stepScale, 1e-3f)) + animTime))) + 1f) / dist) / max(s, 0.5f));
    w = min(w, vec3f((*u).p_stepClamp));
    w = (w * (20f / max((*u).p_stepClamp, 1f)));
    let env = smoothstep(((*u).p_envRadius * 1.12f), ((*u).p_envRadius * (*u).p_envCore), length(p));
    w = ((w + (*u).p_fill) * env);
    acc = (acc + (w * T));
    T *= exp((-(dot(w, vec3f(0.29899999499320984, 0.5870000123977661, 0.11400000005960464))) * (*u).p_scatter));
    if ((T < 4e-3f)) {
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

struct orb15Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb15Fragment(_arg_0: orb15Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let orbUv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let muonsTurb = ((*u).p_turb * (1f + (0.5f * (*u).inputVol)));
  let muonsExposure = ((*u).p_exposure * (1f - (0.35f * (*u).outputVol)));
  let acc = muonsRender(fragCoord, muonsTurb);
  var col = tanh3((acc / max(muonsExposure, 1f)));
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
