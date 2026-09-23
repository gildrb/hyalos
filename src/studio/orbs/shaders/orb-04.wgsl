// Compiled from unchanged shadercn orb-04 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: 0a0849400d73ccbd88903b10903d38630bdc4d7aebf922df744a2bd0c9f67b2d
struct orb04Params {
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
  p_envScale: f32,
  p_exposure: f32,
  p_floorLevel: f32,
  p_focal: f32,
  p_hueGain: f32,
  p_pitch: f32,
  p_saturation: f32,
  p_shellR: f32,
  p_slack: f32,
  p_speed: f32,
  p_turb: f32,
  p_width: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb04Params;

fn roundv(x: vec3f) -> vec3f {
  return floor((x + 0.5f));
}

fn geodeRender(fragCoord: vec2f, geodeTurb: f32, geodeWidth: f32) -> vec3f {
  let u = (&params);
  let uv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let ro = vec3f(0f, 0f, (*u).p_camDist);
  let rd = normalize(vec3f(uv.x, uv.y, -((*u).p_focal)));
  let animTime = (*u).p_speed;
  let shellR = (*u).p_shellR;
  let pitch = max((*u).p_pitch, 2e-3f);
  let zEnd = ((*u).p_camDist + (shellR * 2.5f));
  var acc = vec3f();
  var z = 0f;
  for (var i = 0u; i < 50u; i += 1u) {
    var p = (ro + (rd * z));
    for (var i_1 = 0u; i_1 < 6u; i_1 += 1u) {
      let f = (f32(i_1) + 2f);
      p = (p + ((sin(((roundv((p.zxy / pitch)) * (pitch * f)) - animTime)) * geodeTurb) / f));
    }
    let dist = (geodeWidth + ((*u).p_slack * abs((length(p) - shellR))));
    z += dist;
    acc = (acc + ((((p * (*u).p_hueGain) / max(z, 1e-3f)) + (*u).p_floorLevel) / dist));
    if ((z > zEnd)) {
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

struct orb04Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb04Fragment(_arg_0: orb04Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let geodeTurb = ((*u).p_turb * (1f + (0.5f * (*u).inputVol)));
  let geodeWidth = max(((*u).p_width * (1f - (0.4f * (*u).outputVol))), 2e-4f);
  let geodeExposure = ((*u).p_exposure * (1f - (0.3f * (*u).outputVol)));
  let acc = geodeRender(fragCoord, geodeTurb, geodeWidth);
  var col = tanh3((acc / max(geodeExposure, 1f)));
  col = pow(clamp(col, vec3f(), vec3f(1)), vec3f((*u).p_contrast));
  let lum = dot(col, vec3f(0.29899999499320984, 0.5870000123977661, 0.11400000005960464));
  col = (mix(vec3f(lum), col, (*u).p_saturation) * (*u).c_tint);
  let peak = max(col.x, max(col.y, col.z));
  var alpha = clamp((peak * (*u).p_alphaGain), 0f, 1f);
  let orbUv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let mrd = normalize(vec3f(orbUv.x, orbUv.y, -((*u).p_focal)));
  let closest = length(cross(vec3f(0f, 0f, (*u).p_camDist), mrd));
  let sil = ((*u).p_shellR * (*u).p_envScale);
  let band = mix(0.35f, 0.012f, clamp((*u).p_edge, 0f, 1f));
  let mask = (1f - smoothstep((sil * (1f - band)), (sil * 1.005f), closest));
  col = (col * mask);
  alpha *= mask;
  let fade = (1f - smoothstep((*u).p_edgeFade, 1f, length(orbUv)));
  col = (col * fade);
  alpha *= fade;
  return vec4f(col, alpha);
}
