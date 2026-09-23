// Compiled from unchanged shadercn orb-10 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: 7374a7c1150b8568c992b2eb727f266b5379f3d607a1c638026997b67f25bca0
struct orb10Params {
  anim: f32,
  c_tint: vec3f,
  inputVol: f32,
  mouse: vec2f,
  outputVol: f32,
  p_alphaGain: f32,
  p_camDist: f32,
  p_cell: f32,
  p_climb: f32,
  p_contrast: f32,
  p_edge: f32,
  p_edgeFade: f32,
  p_envCore: f32,
  p_envRadius: f32,
  p_exposure: f32,
  p_fill: f32,
  p_focal: f32,
  p_hueStep: f32,
  p_layer: f32,
  p_saturation: f32,
  p_scatter: f32,
  p_scroll: f32,
  p_shellR: f32,
  p_speed: f32,
  p_spread: f32,
  p_stepClamp: f32,
  p_stepScale: f32,
  p_turb: f32,
  p_wrap: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb10Params;

fn weaveRender(fragCoord: vec2f, weaveTurb: f32, weaveCell: f32) -> vec3f {
  let u = (&params);
  let uv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let ro = vec3f(0f, 0f, (*u).p_camDist);
  let rd = normalize(vec3f(uv.x, uv.y, -((*u).p_focal)));
  let animTime = (*u).p_speed;
  let scroll = (*u).p_scroll;
  var acc = vec3f();
  var T = 1f;
  var z = max(((*u).p_camDist - ((*u).p_envRadius * 1.3f)), 0f);
  let zEnd = ((*u).p_camDist + ((*u).p_envRadius * 1.3f));
  for (var i = 0u; i < 40u; i += 1u) {
    let fi = (f32(i) + 1f);
    let world = (ro + (rd * z));
    let rl = length(world);
    var p = vec3f((atan2(world.z, world.x) * (*u).p_wrap), ((world.y * (*u).p_climb) + scroll), (rl - (*u).p_shellR));
    for (var i_1 = 0u; i_1 < 6u; i_1 += 1u) {
      let dj = (f32(i_1) + 1f);
      p = (p + ((sin(((p.yzx * dj) + (animTime + ((*u).p_layer * fi)))) * weaveTurb) / dj));
    }
    var dist = ((*u).p_stepScale * length(vec4f(((cos(p) * weaveCell) - weaveCell), p.z)));
    dist = max(dist, ((*u).p_envRadius * 4e-3f));
    var w = (cos(((vec3f(6, 1, 2) * (*u).p_spread) + (p.y + (fi * (*u).p_hueStep)))) + 1f);
    w = (w / dist);
    w = min(w, vec3f((*u).p_stepClamp));
    let env = smoothstep(((*u).p_envRadius * 1.12f), ((*u).p_envRadius * (*u).p_envCore), rl);
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

struct orb10Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb10Fragment(_arg_0: orb10Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let weaveTurb = ((*u).p_turb * (1f + (0.4f * (*u).inputVol)));
  let weaveCell = ((*u).p_cell * (1f + (0.3f * (*u).inputVol)));
  let weaveExposure = ((*u).p_exposure * (1f - (0.3f * (*u).outputVol)));
  let acc = weaveRender(fragCoord, weaveTurb, weaveCell);
  let v = (acc / 40f);
  var col = tanh3(((v * v) / max(weaveExposure, 1e-4f)));
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
