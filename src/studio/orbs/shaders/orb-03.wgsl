// Compiled from unchanged shadercn orb-03 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: 478783b419c75b4909ce130cd7985eb815375fccb21c9302e2badda23f39b1cd
struct orb03Params {
  anim: f32,
  c_tint: vec3f,
  inputVol: f32,
  mouse: vec2f,
  outputVol: f32,
  p_alphaGain: f32,
  p_camDist: f32,
  p_contrast: f32,
  p_edge: f32,
  p_edgeFade: f32,
  p_envCore: f32,
  p_envRadius: f32,
  p_exposure: f32,
  p_feedback: f32,
  p_fill: f32,
  p_focal: f32,
  p_hue: f32,
  p_plane: f32,
  p_pulse: f32,
  p_saturation: f32,
  p_scatter: f32,
  p_shellR: f32,
  p_shellW: f32,
  p_speed: f32,
  p_spread: f32,
  p_stepClamp: f32,
  p_surge: f32,
  p_turb: f32,
  p_wander: f32,
  p_width: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb03Params;

fn eclipticRender(fragCoord: vec2f, eclipticTurb: f32, eclipticPlane: f32, eclipticWidth: f32) -> vec3f {
  let u = (&params);
  let uv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let ro = vec3f(0f, 0f, (*u).p_camDist);
  let rd = normalize(vec3f(uv.x, uv.y, -((*u).p_focal)));
  let animTime = (*u).p_speed;
  let wander = (*u).p_wander;
  var acc = vec3f();
  var T = 1f;
  var z = max(((*u).p_camDist - ((*u).p_envRadius * 1.3f)), 0f);
  let zEnd = ((*u).p_camDist + ((*u).p_envRadius * 1.3f));
  var dist = 0f;
  for (var i = 0u; i < 80u; i += 1u) {
    let p = (ro + (rd * z));
    let axis = normalize(cos(((vec3f(4, 2, 0) - (dist * (*u).p_feedback)) + wander)));
    var a = ((axis * dot(axis, p)) - cross(axis, p));
    for (var i_1 = 0u; i_1 < 8u; i_1 += 1u) {
      let f = (f32(i_1) + 2f);
      a = (a + ((sin(((a * f) + animTime)).yzx * eclipticTurb) / f));
    }
    dist = (((*u).p_shellW * abs((length(p) - (*u).p_shellR))) + (eclipticPlane * abs(a.y)));
    dist = max(dist, eclipticWidth);
    var w = (cos(((vec3f(0, 2, 4) * (*u).p_spread) + (dist * (*u).p_hue))) + 1f);
    w = (w * (z / dist));
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

struct orb03Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb03Fragment(_arg_0: orb03Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let surge = (0.5f - (0.5f * cos(((*u).anim * 4f))));
  let eclipticTurb = mix(((*u).p_turb * (1f + (0.4f * (*u).inputVol))), mix(0.5f, 1.6f, surge), (*u).p_surge);
  let eclipticPlane = mix(((*u).p_plane * (1f - (0.35f * (*u).outputVol))), mix(0.1f, 0.3f, surge), (*u).p_surge);
  let eclipticExposure = ((*u).p_exposure * (1f - (0.3f * (*u).outputVol)));
  let eclipticWidth = max(((*u).p_width * (1f - ((*u).p_pulse * (0.5f + (0.5f * cos(((*u).anim * 3f))))))), 5e-4f);
  let acc = eclipticRender(fragCoord, eclipticTurb, eclipticPlane, eclipticWidth);
  var col = tanh3((acc / max(eclipticExposure, 1f)));
  col = pow(clamp(col, vec3f(), vec3f(1)), vec3f((*u).p_contrast));
  let lum = dot(col, vec3f(0.29899999499320984, 0.5870000123977661, 0.11400000005960464));
  col = (mix(vec3f(lum), col, (*u).p_saturation) * (*u).c_tint);
  let peak = max(col.x, max(col.y, col.z));
  var alpha = clamp((peak * (*u).p_alphaGain), 0f, 1f);
  let orbUv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
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
