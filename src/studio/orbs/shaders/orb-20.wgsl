// Compiled from unchanged shadercn orb-20 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: f50ef0ed966209a00949457ef3a3ba55467bfdeb4aa31633c0467c049aa789c7
struct orb20Params {
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
  p_fill: f32,
  p_flow: f32,
  p_foam: f32,
  p_focal: f32,
  p_hueScale: f32,
  p_saturation: f32,
  p_scatter: f32,
  p_speed: f32,
  p_stepClamp: f32,
  p_stepScale: f32,
  p_stretch: f32,
  p_tilt: f32,
  p_wall: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb20Params;

fn rot2(angle: f32) -> mat2x2f {
  let c = cos(angle);
  let s = sin(angle);
  return mat2x2f(vec2f(c, -(s)), vec2f(s, c));
}

fn fallsRender(fragCoord: vec2f, fallsFoam: f32) -> vec3f {
  let u = (&params);
  let animTime = (*u).p_speed;
  let flow = (*u).p_flow;
  let uv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let ro = vec3f(0f, 0f, (*u).p_camDist);
  let rd = normalize(vec3f(uv.x, uv.y, -((*u).p_focal)));
  let rShell = ((*u).p_envRadius * 0.92f);
  var acc = vec3f();
  var T = 1f;
  var z = max(((*u).p_camDist - ((*u).p_envRadius * 1.3f)), 0f);
  let zEnd = ((*u).p_camDist + ((*u).p_envRadius * 1.3f));
  for (var i = 0u; i < 50u; i += 1u) {
    var c = (ro + (rd * z));
    let cTilt = (rot2((*u).p_tilt) * vec2f(c.y, c.z));
    c = vec3f(c.x, cTilt.x, cTilt.y);
    var p = vec3f(c.x, (c.y * (*u).p_stretch), c.z);
    for (var i_1 = 0u; i_1 < 5u; i_1 += 1u) {
      let fj = (f32(i_1) + 1.3f);
      p = (p + (cos(((((vec3f(p.y, p.z, p.x) * fj) + f32(i)) + z) + vec3f(flow, 0f, 0f))) / fj));
    }
    let pm = mix(c, p, fallsFoam);
    var dist = ((*u).p_stepScale * (((abs((length(pm) - rShell)) * (*u).p_wall) + sin(((pm.x - pm.z) + (animTime * 2f)))) + 1f));
    dist = max(dist, 1e-3f);
    z += dist;
    var w = (((cos((vec3f(((pm.x * (*u).p_hueScale) + dist)) + vec3f(6, 1, 2))) + 2f) / dist) / max(z, 1f));
    w = min(w, vec3f((*u).p_stepClamp));
    let env = smoothstep(((*u).p_envRadius * 1.12f), ((*u).p_envRadius * (*u).p_envCore), length((ro + (rd * z))));
    w = ((w + (*u).p_fill) * env);
    acc = (acc + (w * T));
    T *= exp((-(dot(w, vec3f(0.29899999499320984, 0.5870000123977661, 0.11400000005960464))) * (*u).p_scatter));
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

struct orb20Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb20Fragment(_arg_0: orb20Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let orbUv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let fallsFoam = ((*u).p_foam * (1f + (0.5f * (*u).inputVol)));
  let fallsExposure = ((*u).p_exposure * (1f - (0.35f * (*u).outputVol)));
  let acc = fallsRender(fragCoord, fallsFoam);
  var col = tanh3((acc / max(fallsExposure, 1f)));
  col = pow(clamp(col, vec3f(), vec3f(1)), vec3f((*u).p_contrast));
  let lum = dot(col, vec3f(0.29899999499320984, 0.5870000123977661, 0.11400000005960464));
  col = mix(vec3f(lum), col, (*u).p_saturation);
  col = (col * (*u).c_tint);
  let peak = max(col.x, max(col.y, col.z));
  var a = clamp((peak * (*u).p_alphaGain), 0f, 1f);
  let mrd = normalize(vec3f(orbUv.x, orbUv.y, -((*u).p_focal)));
  let closest = length(cross(vec3f(0f, 0f, (*u).p_camDist), mrd));
  let band = mix(0.35f, 0.012f, clamp((*u).p_edge, 0f, 1f));
  let mask = (1f - smoothstep(((*u).p_envRadius * (1f - band)), ((*u).p_envRadius * 1.005f), closest));
  col = (col * mask);
  a *= mask;
  let r2d = length(orbUv);
  let fade = (1f - smoothstep((*u).p_edgeFade, 1f, r2d));
  col = (col * fade);
  a *= fade;
  return vec4f(col, a);
}
