// Compiled from unchanged shadercn orb-01 using TypeGPU.
// Shader by XorDev (https://x.com/XorDev), ported with permission.
// Non-commercial use only, with attribution. Preserve this notice.
// Source SHA-256: 2aa0f11b1bdd54bbcfe687f2d167608575b393a3aec506d4e3c358c198f7061b
struct orb01Params {
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
  p_fill: f32,
  p_focal: f32,
  p_saturation: f32,
  p_scatter: f32,
  p_sheets: f32,
  p_speed: f32,
  p_spin: f32,
  p_stepClamp: f32,
  p_stria: f32,
  p_tilt: f32,
  p_turb: f32,
  res: vec2f,
  time: f32,
}

@group(0) @binding(0) var<uniform> params: orb01Params;

fn rot2(angle: f32) -> mat2x2f {
  let c = cos(angle);
  let s = sin(angle);
  return mat2x2f(vec2f(c, -(s)), vec2f(s, c));
}

fn dispersionRender(fragCoord: vec2f, turb: f32) -> vec3f {
  let u = (&params);
  let animTime = (*u).p_speed;
  let spinAng = (*u).p_spin;
  let uv = (((fragCoord * 2f) - (*u).res) / min((*u).res.x, (*u).res.y));
  let ro = vec3f(0f, 0f, (*u).p_camDist);
  let rd = normalize(vec3f(uv.x, uv.y, -((*u).p_focal)));
  var acc = vec3f();
  var T = 1f;
  var z = max(((*u).p_camDist - ((*u).p_envRadius * 1.3f)), 0f);
  let zEnd = ((*u).p_camDist + ((*u).p_envRadius * 1.3f));
  for (var i = 0u; i < 60u; i += 1u) {
    let p = (ro + (rd * z));
    var q = p;
    let spun = (rot2(spinAng) * vec2f(q.x, q.z));
    q = vec3f(spun.x, q.y, spun.y);
    let tilted = (rot2((*u).p_tilt) * vec2f(q.y, q.z));
    q = vec3f(q.x, tilted.x, tilted.y);
    var a = q;
    for (var i_1 = 0u; i_1 < 5u; i_1 += 1u) {
      let dj = (f32(i_1) + 3f);
      let wave = sin((((a * dj) + animTime) + f32(i)));
      a = (a - ((vec3f(wave.y, wave.z, wave.x) * turb) / dj));
    }
    let wall = abs((length(a) - (*u).p_envRadius));
    let s = ((a.z + a.y) - animTime);
    let dist = max((wall + (abs(cos(s)) / (*u).p_sheets)), 1e-4f);
    var w = ((cos(((vec3f(s, s, s) - (z * (*u).p_stria)) + (vec3f(0, 1, 8) * (*u).p_disperse))) + 1f) / dist);
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

struct orb01Fragment_Input {
  @location(0) uv: vec2f,
}

@fragment fn orb01Fragment(_arg_0: orb01Fragment_Input) -> @location(0) vec4f {
  let u = (&params);
  let fragCoord = (_arg_0.uv * (*u).res);
  let turb = ((*u).p_turb * (1f + (0.5f * (*u).inputVol)));
  let exposure = ((*u).p_exposure * (1f - (0.35f * (*u).outputVol)));
  var col = tanh3((dispersionRender(fragCoord, turb) / max(exposure, 1f)));
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
